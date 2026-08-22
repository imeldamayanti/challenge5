// b2 §5.1–§5.11 — anonymous identities, linking, and the merge.
// docs/backend-supabase.md §7, §7.3, §15.3, §14 defect 20.

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  ANON_KEY,
  API_URL,
  createUser,
  fn,
  newRun,
  rest,
  signInAnonymously,
  sql,
  upload,
} from "../_helpers.ts";

function callMerge(token: string, body: unknown) {
  return fn("merge-anonymous", {
    method: "POST",
    headers: {
      apikey: ANON_KEY,
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

async function walkAnonymously() {
  const anon = await signInAnonymously();
  const run = newRun(anon.id);
  const res = await rest("runs", anon.token, { method: "POST", body: JSON.stringify(run.body) });
  assertEquals(res.status, 201, await res.text());
  return { anon, runId: run.id, questId: run.body.quest_id };
}

Deno.test("5.1 anonymous sign-in produces a real auth.users row", async () => {
  const { id, token } = await signInAnonymously();
  assert(token.length > 0);
  assertEquals(await sql(`select is_anonymous from auth.users where id = '${id}'`), "t");

  // And the walk can start immediately: nothing is gated on a credential or a radio (§7.1).
  const run = newRun(id);
  const res = await rest("runs", token, { method: "POST", body: JSON.stringify(run.body) });
  assertEquals(res.status, 201, await res.text());
});

Deno.test("5.2 linking an unused email keeps the same user_id and every row", async () => {
  const { anon, runId } = await walkAnonymously();

  const res = await fetch(`${API_URL}/auth/v1/user`, {
    method: "PUT",
    headers: {
      apikey: ANON_KEY,
      Authorization: `Bearer ${anon.token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ email: `linked-${crypto.randomUUID()}@example.test`, password: "Pw-12345678" }),
  });
  assertEquals(res.status, 200, await res.text());

  // The whole point of §7's design: the row is the same row, so nothing has to be migrated.
  assertEquals(await sql(`select count(*) from app.runs where id = '${runId}'`), "1");
  assertEquals(await sql(`select user_id from app.runs where id = '${runId}'`), anon.id);
});

Deno.test("5.3 linking an email that already exists is rejected", async () => {
  const existing = await createUser();
  const { anon } = await walkAnonymously();

  const res = await fetch(`${API_URL}/auth/v1/user`, {
    method: "PUT",
    headers: {
      apikey: ANON_KEY,
      Authorization: `Bearer ${anon.token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ email: existing.email, password: "Pw-12345678" }),
  });
  assert(res.status >= 400, `expected a rejection, got ${res.status}`);
  await res.body?.cancel();

  // This is the case §7.3 exists for, and until merge-anonymous is wired into the app the client
  // must detect it UP FRONT rather than failing after the walker has agreed to anything.
});

Deno.test("5.4 a valid merge moves the rows and deletes the anonymous identity last", async () => {
  const target = await createUser();
  const { anon, runId } = await walkAnonymously();

  const res = await callMerge(target.token, {
    anon_access_token: anon.token,
    anon_queue_empty: true,
  });
  const text = await res.text();
  assertEquals(res.status, 200, text);
  assertEquals(JSON.parse(text).merged, true);

  assertEquals(await sql(`select user_id from app.runs where id = '${runId}'`), target.id);
  assertEquals(await sql(`select count(*) from auth.users where id = '${anon.id}'`), "0");
});

Deno.test("5.5 a second merge moves nothing and does not fail catastrophically", async () => {
  const target = await createUser();
  const { anon, runId } = await walkAnonymously();

  const first = await callMerge(target.token, {
    anon_access_token: anon.token,
    anon_queue_empty: true,
  });
  assertEquals(first.status, 200, await first.text());

  // The anonymous identity no longer exists, so its token no longer resolves — which is the same
  // outcome as "nothing left to move" and must not be a 500.
  const second = await callMerge(target.token, {
    anon_access_token: anon.token,
    anon_queue_empty: true,
  });
  assert([200, 401].includes(second.status), `unexpected ${second.status}`);
  await second.body?.cancel();
  assertEquals(await sql(`select user_id from app.runs where id = '${runId}'`), target.id);
});

Deno.test("5.8 a forged or expired anonymous token is rejected", async () => {
  // THE SINGLE MOST IMPORTANT NEGATIVE TEST IN THIS FILE: a merge that trusts its input is account
  // takeover. Neither uid is ever read from a request body — both come from tokens the caller had
  // to actually hold.
  const target = await createUser();
  const victim = await createUser();
  const victimRun = newRun(victim.id);
  await (await rest("runs", victim.token, { method: "POST", body: JSON.stringify(victimRun.body) }))
    .body?.cancel();

  const forged = target.token.slice(0, -4) + "AAAA";
  const res = await callMerge(target.token, {
    anon_access_token: forged,
    anon_queue_empty: true,
  });
  assertEquals(res.status, 401);
  await res.body?.cancel();

  // A well-formed token belonging to a REAL non-anonymous account is refused too — otherwise the
  // function would be a way to harvest another signed-in user's rows.
  const stealing = await callMerge(target.token, {
    anon_access_token: victim.token,
    anon_queue_empty: true,
  });
  assertEquals(stealing.status, 400);
  await stealing.body?.cancel();
  assertEquals(await sql(`select user_id from app.runs where id = '${victimRun.id}'`), victim.id);
});

Deno.test("5.9 a merge of an identity into itself is rejected", async () => {
  const { anon } = await walkAnonymously();
  const res = await callMerge(anon.token, {
    anon_access_token: anon.token,
    anon_queue_empty: true,
  });
  // The caller is anonymous, which fails before the self-merge check even applies: the TARGET of a
  // merge must be a linked account.
  assertEquals(res.status, 400);
  await res.body?.cancel();
});

Deno.test("5.10 a merge is refused while the anonymous device still has rows in flight", async () => {
  // §15.3: rejecting is simpler than reconciling mid-move, and the client retries once its queue
  // drains. The server cannot see the client's sync_state, so the client asserts it — and the
  // assertion has to be EXPLICIT, because a default of "probably fine" is how this becomes a
  // silent half-merge.
  const target = await createUser();
  const { anon, runId } = await walkAnonymously();

  const res = await callMerge(target.token, { anon_access_token: anon.token });
  assertEquals(res.status, 409);
  await res.body?.cancel();
  assertEquals(await sql(`select user_id from app.runs where id = '${runId}'`), anon.id);
});

Deno.test("5.11 storage objects move with the rows, copy before delete", async () => {
  const target = await createUser();
  const { anon, runId } = await walkAnonymously();

  const photoId = crypto.randomUUID();
  const full = `${anon.id}/${runId}/${photoId}.heic`;
  // Both derivatives. thumb_path became NOT NULL in migration 0015: this fixture used to write a
  // row carrying only the full-size path, which is a row FR-SET-02 can only half-delete — the
  // thumb survives erasure with nothing pointing at it. The constraint is what caught it.
  const thumb = `${anon.id}/${runId}/${photoId}_t.heic`;
  await (await rest("photos", anon.token, {
    method: "POST",
    body: JSON.stringify({
      id: photoId,
      user_id: anon.id,
      run_id: runId,
      storage_path: full,
      thumb_path: thumb,
      content_type: "image/heic",
      captured_at: new Date().toISOString(),
      device_id: crypto.randomUUID(),
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }),
  })).body?.cancel();
  await (await upload("trip-photos", full, anon.token, new Uint8Array(64))).body?.cancel();
  await (await upload("trip-photos", thumb, anon.token, new Uint8Array(16))).body?.cancel();

  const res = await callMerge(target.token, {
    anon_access_token: anon.token,
    anon_queue_empty: true,
  });
  assertEquals(res.status, 200, await res.text());

  const moved = `${target.id}/${runId}/${photoId}.heic`;
  const movedThumb = `${target.id}/${runId}/${photoId}_t.heic`;
  assertEquals(await sql(`select storage_path from app.photos where id = '${photoId}'`), moved);
  // Both paths are rewritten, or FR-SET-02 later deletes under the new owner's prefix and misses
  // an object still sitting under the old one.
  assertEquals(await sql(`select thumb_path from app.photos where id = '${photoId}'`), movedThumb);
  assertEquals(
    await sql(
      `select count(*) from storage.objects where bucket_id='trip-photos' and name='${moved}'`,
    ),
    "1",
  );
  // The original is gone only after the row moved — an interruption at any point would have left
  // it readable (§7.3 rule 4).
  assertEquals(
    await sql(
      `select count(*) from storage.objects where bucket_id='trip-photos' and name='${full}'`,
    ),
    "0",
  );

  // And the target can actually read it, which is the reason the paths had to move at all: §8.3's
  // policy keys on the first segment of the object name being the caller's uid.
  const read = await fetch(`${API_URL}/storage/v1/object/trip-photos/${moved}`, {
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${target.token}` },
  });
  assertEquals(read.status, 200);
  await read.body?.cancel();
});

Deno.test("5.6 a colliding active quest is resolved rather than lost", async () => {
  const target = await createUser();
  const { anon, runId, questId } = await walkAnonymously();

  // The target is walking the same quest, further along.
  const targetRun = newRun(target.id);
  targetRun.body.quest_id = questId;
  await (await rest("runs", target.token, { method: "POST", body: JSON.stringify(targetRun.body) }))
    .body?.cancel();
  await sql(`
    insert into app.checkpoint_results
      (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
       snapshot_place_name, snapshot_lore, snapshot_sources, snapshot_content_version,
       device_id, created_at, updated_at)
    values (gen_random_uuid(), '${targetRun.id}', '${target.id}', 'cp-1', 0, now(), 'gps', 'P',
            '[]', '[]', '1', gen_random_uuid(), now(), now())
  `);

  const res = await callMerge(target.token, {
    anon_access_token: anon.token,
    anon_queue_empty: true,
  });
  assertEquals(res.status, 200, await res.text());

  assertEquals(await sql(`select count(*) from app.runs where user_id = '${target.id}'`), "2");
  assertEquals(
    await sql(`select count(*) from app.runs where user_id = '${target.id}' and state = 'active'`),
    "1",
  );
  assertEquals(await sql(`select state from app.runs where id = '${runId}'`), "abandoned");
});
