// `c2` phase 5 — the share card's public reader.
//
// **The function is written and NOT deployed** (publishing is blocked on the consent position,
// `c2-wiring/03-security-privacy.md` §4). These run against the local stack, which is the only way
// the engineering can be checked at all without publishing anything — and they are what makes
// "built and switched off" mean the engineering was finished rather than sketched.
//
// Every assertion is over HTTP with no user token, because that is the whole point of the endpoint:
// a link somebody without the app can open.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { ANON_KEY, API_URL, SERVICE_KEY, createUser, fn, sql } from "../_helpers.ts";

const BUCKET = "share-cards";
const PNG = new Uint8Array([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, // signature
  0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
]);

/// Anonymous, deliberately: no `apikey`, no bearer. A reader of a shared card has neither.
function open(slug: string): Promise<Response> {
  return fetch(`${API_URL}/functions/v1/share/${slug}`);
}

async function seedCard(options: {
  slug: string;
  revokedAt?: string | null;
  expiresAt?: string | null;
  deletedAt?: string | null;
}): Promise<{ userId: string; runId: string }> {
  const user = await createUser();
  const runId = crypto.randomUUID();
  const cardId = crypto.randomUUID();
  const path = `${user.id}/${cardId}.png`;

  await sql(
    `insert into app.runs (id,user_id,quest_id,content_version,language,state,started_at,completed_at,device_id,created_at,updated_at)
     values ('${runId}','${user.id}','q','v','en','completed',now(),now(),gen_random_uuid(),now(),now())`,
  );

  const upload = await fetch(`${API_URL}/storage/v1/object/${BUCKET}/${path}`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "image/png",
    },
    body: PNG,
  });
  assertEquals(upload.status, 200, "seeding the object failed");
  await upload.body?.cancel();

  const nullable = (value: string | null | undefined) =>
    value === undefined || value === null ? "null" : `'${value}'`;

  await sql(
    `insert into app.share_cards (id,user_id,run_id,template,storage_path,public_slug,expires_at,revoked_at,deleted_at,device_id)
     values ('${cardId}','${user.id}','${runId}','recap-v1','${path}','${options.slug}',
             ${nullable(options.expiresAt)}, ${nullable(options.revokedAt)}, ${nullable(options.deletedAt)},
             gen_random_uuid())`,
  );
  return { userId: user.id, runId };
}

Deno.test("c2.5.1 a live slug serves the bytes to a caller with no token at all", async () => {
  const slug = `live${crypto.randomUUID().replaceAll("-", "")}`.slice(0, 32);
  await seedCard({ slug });

  const res = await open(slug);
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("content-type"), "image/png");
  // A revoked card must stop being served on the NEXT request, which a cached response prevents.
  assertEquals(res.headers.get("cache-control"), "no-store");
  const body = new Uint8Array(await res.arrayBuffer());
  assertEquals(body.slice(0, 4), PNG.slice(0, 4), "the PNG signature did not come back");
});

Deno.test("c2.5.2 the response is never a signed URL, only bytes", async () => {
  const slug = `bytes${crypto.randomUUID().replaceAll("-", "")}`.slice(0, 32);
  await seedCard({ slug });

  const res = await open(slug);
  assertEquals(res.status, 200);
  const text = new TextDecoder().decode(await res.arrayBuffer());
  // Handing back a signed URL gives the caller a credential that outlives the revocation.
  assert(!text.includes("token="), "a signed URL leaked into the response body");
  assert(!text.includes("/object/sign/"), "a signed URL leaked into the response body");
  assertEquals(res.headers.get("location"), null, "the reader was redirected to storage");
});

Deno.test("c2.5.3 revoked, expired, deleted and unknown are indistinguishable", async () => {
  const cases: Array<[string, Record<string, string | null>]> = [
    ["revoked", { revokedAt: new Date().toISOString() }],
    ["expired", { expiresAt: new Date(Date.now() - 60_000).toISOString() }],
    ["deleted", { deletedAt: new Date().toISOString() }],
  ];

  const bodies: string[] = [];
  for (const [name, options] of cases) {
    const slug = `${name}${crypto.randomUUID().replaceAll("-", "")}`.slice(0, 32);
    await seedCard({ slug, ...options });
    const res = await open(slug);
    assertEquals(res.status, 404, `${name} should not be served`);
    bodies.push(await res.text());
  }

  // A slug that was never minted.
  const unknown = await open(`never${crypto.randomUUID().replaceAll("-", "")}`.slice(0, 32));
  assertEquals(unknown.status, 404);
  bodies.push(await unknown.text());

  // One shape for all four: telling them apart tells a stranger which slugs exist.
  assertEquals(new Set(bodies).size, 1, `refusals differ: ${JSON.stringify(bodies)}`);
});

Deno.test("c2.5.4 a malformed slug is refused before anything is looked up", async () => {
  for (const slug of ["short", "../../etc/passwd", "a".repeat(200), "has space", "eq.anything"]) {
    const res = await open(encodeURIComponent(slug));
    assertEquals(res.status, 404, `"${slug}" was not refused`);
    await res.body?.cancel();
  }
});

Deno.test("c2.5.5 revoking stops the card, and a revoke without a revision bump does NOT", async () => {
  // **This test found a live defect and is written to keep finding it.**
  //
  // `app.share_cards` carries `resolve_sync_conflict` as a `before update` trigger, and its second
  // branch returns null — discarding the write — when `revision` and `device_id` both match the
  // stored row. That is right for a device re-pushing an unchanged row and wrong for a *partial*
  // update from the same device, which is what a revoke is: PostgREST leaves untouched columns
  // alone, so both match, the row is not modified, and the caller gets a 200.
  //
  // The visible consequence is the worst kind: a walker presses "turn the link off", is told it
  // worked, and the link keeps serving. The same trap silently stopped `uploaded_at` being stamped
  // on photographs, which made every restored walk skip its pictures.
  const slug = `revoke${crypto.randomUUID().replaceAll("-", "")}`.slice(0, 32);
  const { runId } = await seedCard({ slug });

  const before = await open(slug);
  assertEquals(before.status, 200);
  await before.body?.cancel();

  // The naive revoke, exactly as it was first written.
  await sql(`update app.share_cards set revoked_at = now() where run_id = '${runId}'`);
  const stillLive = await open(slug);
  assertEquals(
    stillLive.status,
    200,
    "the trigger no longer discards a bare update — if this is now 404, the schema changed and " +
      "`SyncConflictTrigger` in the app can be simplified",
  );
  await stillLive.body?.cancel();

  // The same revoke, with the bump `SyncConflictTrigger` exists to supply.
  await sql(
    `update app.share_cards set revoked_at = now(), revision = revision + 1 where run_id = '${runId}'`,
  );
  const after = await open(slug);
  assertEquals(after.status, 404, "a revoked card was still served");
  await after.body?.cancel();
});

Deno.test("c2.5.6 only GET is served", async () => {
  const slug = `method${crypto.randomUUID().replaceAll("-", "")}`.slice(0, 32);
  await seedCard({ slug });
  for (const method of ["POST", "DELETE", "PUT"]) {
    const res = await fetch(`${API_URL}/functions/v1/share/${slug}`, { method });
    assertEquals(res.status, 405, `${method} was accepted`);
    await res.body?.cancel();
  }
});
