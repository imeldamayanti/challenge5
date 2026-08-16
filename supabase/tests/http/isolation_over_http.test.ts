// b3 §4 — isolation proved over HTTP, not only inside the database.
//
// pgTAP runs inside the database as a role the harness chooses. That proves the POLICIES are
// correct. It does not prove the STACK denies a real request, because three things sit between
// them that pgTAP never touches: PostgREST's exposed-schema configuration, the grants attached to
// `anon` and `authenticated`, and the Storage service's own policy evaluation.
//
// The same file runs against localhost:54321 on every pull request and against a deployed URL
// after a push (b3 §3 steps 3 and 9). Set SUPABASE_URL / SUPABASE_ANON_KEY /
// SUPABASE_SERVICE_ROLE_KEY to point it elsewhere.

import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { ANON_KEY, API_URL, SERVICE_KEY, createUser, newRun, rest, upload } from "../_helpers.ts";

async function seededWalk() {
  const a = await createUser();
  const b = await createUser();
  const run = newRun(a.id);
  const res = await rest("runs", a.token, { method: "POST", body: JSON.stringify(run.body) });
  assertEquals(res.status, 201, await res.text());
  return { a, b, runId: run.id };
}

Deno.test("GET /rest/v1/runs as B, with A's rows present, returns []", async () => {
  const { b } = await seededWalk();
  const res = await rest("runs", b.token);
  assertEquals(res.status, 200);
  assertEquals(await res.json(), []);
});

Deno.test("GET /rest/v1/runs?id=eq.<A's run> as B returns []", async () => {
  const { b, runId } = await seededWalk();
  const res = await rest(`runs?id=eq.${runId}`, b.token);
  assertEquals(res.status, 200);
  assertEquals(await res.json(), []);
});

Deno.test("PATCH A's run as B affects nothing, and A re-reads it unchanged", async () => {
  const { a, b, runId } = await seededWalk();
  const patch = await rest(`runs?id=eq.${runId}`, b.token, {
    method: "PATCH",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({ current_checkpoint_index: 99 }),
  });
  assertEquals(patch.status, 200);
  assertEquals(await patch.json(), []);

  const reread = await rest(`runs?id=eq.${runId}&select=current_checkpoint_index`, a.token);
  assertEquals((await reread.json())[0].current_checkpoint_index, 0);
});

Deno.test("DELETE is refused for everyone, on every table in app", async () => {
  const { a, b, runId } = await seededWalk();
  for (const [who, token] of [["the owner", a.token], ["another user", b.token]] as const) {
    const res = await rest(`runs?id=eq.${runId}`, token, { method: "DELETE" });
    assert(res.status >= 400, `DELETE by ${who} returned ${res.status}`);
    await res.body?.cancel();
  }
  // Tombstones are the only deletion path (schema.md §C.3 rule 3); FR-SET-02 is a service-role
  // Edge Function, not something a client can reach.
  const still = await rest(`runs?id=eq.${runId}&select=id`, a.token);
  assertEquals((await still.json()).length, 1);
});

Deno.test("ops is NOT EXPOSED — not an empty array", async () => {
  const { a } = await seededWalk();
  // The row that catches a config.toml mistake. Because `supabase start` applies config.toml, it
  // catches it locally, on the pull request, rather than after a deploy (b3 §0).
  const res = await fetch(`${API_URL}/rest/v1/events`, {
    headers: {
      apikey: ANON_KEY,
      Authorization: `Bearer ${a.token}`,
      "Accept-Profile": "ops",
    },
  });
  assert(res.status >= 400, `ops answered ${res.status} — it must not be reachable at all`);
  const body = await res.text();
  assert(!body.startsWith("["), `ops returned a result set: ${body}`);
});

Deno.test("catalog is NOT EXPOSED either", async () => {
  const { a } = await seededWalk();
  const res = await fetch(`${API_URL}/rest/v1/bundles`, {
    headers: {
      apikey: ANON_KEY,
      Authorization: `Bearer ${a.token}`,
      "Accept-Profile": "catalog",
    },
  });
  assert(res.status >= 400, `catalog answered ${res.status}`);
  await res.body?.cancel();
});

Deno.test("the publishable key with no session leaks nothing", async () => {
  await seededWalk();
  const res = await rest("runs", ANON_KEY);

  // b3 §4 predicts `[]` here. What the stack actually does is REFUSE, because design §8's grants
  // layer revokes everything on `app` from `anon` — a strictly stronger answer than an empty list,
  // and the reason both are accepted below. What is asserted either way is that no row escapes.
  if (res.status === 200) {
    assertEquals(await res.json(), []);
  } else {
    assert(res.status === 401 || res.status === 403 || res.status === 404,
      `unexpected status ${res.status}`);
    const body = await res.text();
    assert(!body.includes("quest_id"), `a refusal must not carry rows: ${body}`);
  }
});

Deno.test("storage: A's object is unreadable and A's prefix unwritable by B", async () => {
  const { a, b, runId } = await seededWalk();
  const path = `${a.id}/${runId}/photo.heic`;
  await (await upload("trip-photos", path, a.token, new Uint8Array(64))).body?.cancel();

  const read = await fetch(`${API_URL}/storage/v1/object/trip-photos/${path}`, {
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${b.token}` },
  });
  assert(read.status >= 400, `B read A's object: ${read.status}`);
  await read.body?.cancel();

  const write = await upload("trip-photos", `${a.id}/${runId}/theirs.heic`, b.token,
    new Uint8Array(64));
  assert(write.status >= 400, `B wrote into A's prefix: ${write.status}`);
  await write.body?.cancel();
});

Deno.test("POST /functions/v1/ingest with no JWT is accepted", async () => {
  const res = await fetch(`${API_URL}/functions/v1/ingest`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-forwarded-for": "10.9.0.1" },
    body: JSON.stringify({
      schema_version: 1,
      events: [{
        id: crypto.randomUUID(),
        name: "app_opened",
        params: {},
        occurred_at: new Date().toISOString(),
      }],
    }),
  });
  assertEquals(res.status, 200, await res.text());
});

Deno.test("POST /functions/v1/delete-account with no JWT is rejected", async () => {
  const res = await fetch(`${API_URL}/functions/v1/delete-account`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "{}",
  });
  assert(res.status === 401 || res.status === 403, `expected a rejection, got ${res.status}`);
  await res.body?.cancel();
});

Deno.test("POST /functions/v1/merge-anonymous with no JWT is rejected", async () => {
  const res = await fetch(`${API_URL}/functions/v1/merge-anonymous`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "{}",
  });
  assert(res.status === 401 || res.status === 403, `expected a rejection, got ${res.status}`);
  await res.body?.cancel();
});

Deno.test("cron is NOT EXPOSED either — pg_cron ships its own permissive policies", async () => {
  // Migration 0017 installed pg_cron to run the ops.events retention horizon. pg_cron creates
  // `cron.job` and `cron.job_run_details` with policies of its own, and the Supabase advisor
  // duly flags them as reachable by anonymous users.
  //
  // They are not reachable, for the same reason `ops` is not: `[api] schemas = ["app"]` is
  // evaluated BEFORE any policy, so a schema absent from that list has no HTTP surface at all.
  // This asserts the property rather than trusting the advisor's read of the policies — and it is
  // here because installing an extension is exactly the kind of change that widens an API surface
  // without anyone noticing.
  const res = await fetch(`${API_URL}/rest/v1/job?select=jobname`, {
    headers: { apikey: ANON_KEY, "Accept-Profile": "cron" },
  });
  const body = await res.text();
  assertEquals(res.status, 406, `cron reachable over HTTP: ${body}`);
  assertStringIncludes(body, "PGRST106");
});

Deno.test("zz cleanup: the suite removes the users it created", async () => {
  // This suite is the one `b3` §4 says to run against PROD, because PostgREST's exposed-schema
  // config, the grants on anon/authenticated, and Storage's own policy evaluation are only real
  // over HTTP. Every run calls `createUser`, so every run LEFT ACCOUNTS BEHIND — 64 of them had
  // accumulated before anyone counted, which quietly falsified `b3` §1.1's "prod holds no real
  // users yet". A test that dirties the environment it validates is a test people stop running.
  //
  // Named `zz` so it sorts last: Deno runs tests in file order, and cleanup that runs first is
  // just a slower way to delete nothing.
  //
  // Scoped to @example.test — the domain `_helpers.uniqueEmail` mints — and nothing else. A
  // cleanup that could touch a real account is worse than residue.
  const admin = (path: string, method = "GET") =>
    fetch(`${API_URL}/auth/v1/admin/${path}`, {
      method,
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    });

  let removed = 0;
  let skipped = 0;
  for (let page = 1; page <= 20; page++) {
    const res = await admin(`users?page=${page}&per_page=200`);
    if (!res.ok) {
      await res.body?.cancel();
      break;
    }
    const users = (await res.json()).users ?? [];
    if (users.length === 0) break;
    for (const u of users) {
      if (typeof u.email === "string" && u.email.endsWith("@example.test")) {
        const del = await admin(`users/${u.id}`, "DELETE");
        await del.body?.cancel();
        if (del.ok) removed++;
      } else {
        skipped++;
      }
    }
    if (users.length < 200) break;
  }

  // Not an assertion on `removed`: a suite run that happened to create none is fine. What must be
  // true is that nothing outside the test domain was touched, which the loop enforces by shape.
  console.log(`  cleanup: removed ${removed} @example.test users, left ${skipped} others alone`);
  assert(removed >= 0);
});
