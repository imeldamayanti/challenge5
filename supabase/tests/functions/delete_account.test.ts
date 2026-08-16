// b2 §8.7–§8.10 and §6.7 — FR-SET-02, "delete all my data".
// docs/backend-supabase.md §8, §4.7, §15.2, §15.3.

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  ANON_KEY,
  API_URL,
  createUser,
  fn,
  newRun,
  rest,
  sql,
  TestUser,
  upload,
} from "../_helpers.ts";

const bytes = (n: number) => new Uint8Array(n).fill(3);

async function giveAWalk(user: TestUser): Promise<{ runId: string; paths: string[] }> {
  const run = newRun(user.id);
  const created = await rest("runs", user.token, {
    method: "POST",
    body: JSON.stringify(run.body),
  });
  assertEquals(created.status, 201, await created.text());

  const photoId = crypto.randomUUID();
  const full = `${user.id}/${run.id}/${photoId}.heic`;
  const thumb = `${user.id}/${run.id}/${photoId}_t.heic`;

  // §4.7's ordering: ROW FIRST. The reverse — upload, then insert — leaves an object nobody can
  // find, nobody can delete, and which still counts toward both the bill and the FR-SET-02
  // obligations if the insert fails or the app is killed between the two.
  const row = await rest("photos", user.token, {
    method: "POST",
    body: JSON.stringify({
      id: photoId,
      user_id: user.id,
      run_id: run.id,
      storage_path: full,
      thumb_path: thumb,
      content_type: "image/heic",
      captured_at: new Date().toISOString(),
      device_id: crypto.randomUUID(),
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }),
  });
  assertEquals(row.status, 201, await row.text());

  await (await upload("trip-photos", thumb, user.token, bytes(32))).body?.cancel();
  await (await upload("trip-photos", full, user.token, bytes(256))).body?.cancel();

  return { runId: run.id, paths: [full, thumb] };
}

function callDelete(token: string, body: unknown = {}) {
  return fn("delete-account", {
    method: "POST",
    headers: {
      apikey: ANON_KEY,
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

async function objectExists(path: string, token: string): Promise<boolean> {
  const res = await fetch(`${API_URL}/storage/v1/object/trip-photos/${path}`, {
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${token}` },
  });
  const ok = res.status === 200;
  await res.body?.cancel();
  return ok;
}

Deno.test("8.10 a caller cannot delete somebody else's account", async () => {
  const a = await createUser();
  const b = await createUser();
  await giveAWalk(a);

  const res = await callDelete(b.token, { user_id: a.id });
  assertEquals(res.status, 403);
  await res.body?.cancel();

  assertEquals(await sql(`select count(*) from app.runs where user_id = '${a.id}'`), "1");
});

Deno.test("8.7 delete-account removes A's rows and BOTH derivatives, and leaves B untouched", async () => {
  const a = await createUser();
  const b = await createUser();
  const aWalk = await giveAWalk(a);
  const bWalk = await giveAWalk(b);

  const res = await callDelete(a.token);
  const text = await res.text();
  assertEquals(res.status, 200, text);
  assertEquals(JSON.parse(text).deleted, true);

  assertEquals(await sql(`select count(*) from app.runs where user_id = '${a.id}'`), "0");
  assertEquals(await sql(`select count(*) from app.photos where user_id = '${a.id}'`), "0");
  assertEquals(await sql(`select count(*) from auth.users where id = '${a.id}'`), "0");

  // Both derivatives, not just the full one. §4.7: deleting an object that was never written is
  // free; leaving one behind is a privacy failure that passes every database test.
  for (const p of aWalk.paths) {
    assertEquals(
      await sql(
        `select count(*) from storage.objects where bucket_id = 'trip-photos' and name = '${p}'`,
      ),
      "0",
      `${p} should be gone`,
    );
  }

  assertEquals(await sql(`select count(*) from app.runs where id = '${bWalk.runId}'`), "1");
  assert(await objectExists(bWalk.paths[0], b.token), "B's object must survive A's deletion");
});

Deno.test("8.8 an interruption after objects and before rows leaves the survivable half-state", async () => {
  // "Objects first" is not a preference. A crash after step 2 leaves rows pointing at bytes that
  // are gone, which reads as a broken thumbnail and is recoverable. The reverse order leaves bytes
  // with no row — unreachable, undeletable, and still personal data.
  const a = await createUser();
  const walk = await giveAWalk(a);

  // Deleted through the Storage API, not with SQL: storage.protect_delete() refuses direct
  // deletion from storage.objects precisely to stop the orphan this test is simulating.
  for (const p of walk.paths) {
    const gone = await fetch(`${API_URL}/storage/v1/object/trip-photos/${p}`, {
      method: "DELETE",
      headers: { apikey: ANON_KEY, Authorization: `Bearer ${a.token}` },
    });
    await gone.body?.cancel();
  }

  assertEquals(await sql(`select count(*) from app.photos where user_id = '${a.id}'`), "1");
  assert(!await objectExists(walk.paths[0], a.token), "the bytes are gone");

  // And the function still finishes from that state rather than failing on the missing objects.
  const res = await callDelete(a.token);
  assertEquals(res.status, 200, await res.text());
  assertEquals(await sql(`select count(*) from app.photos where user_id = '${a.id}'`), "0");
});

Deno.test("8.9 re-running the deletion is idempotent", async () => {
  const a = await createUser();
  await giveAWalk(a);

  const first = await callDelete(a.token);
  assertEquals(first.status, 200, await first.text());

  // The second call is what a retried request after a dropped response looks like. The identity is
  // already gone, so GoTrue no longer resolves the token — a 401 here means "there is nothing left
  // to delete", which is the same outcome as a 200 and is NOT an error state to recover from.
  const second = await callDelete(a.token);
  assert([200, 401].includes(second.status), `unexpected ${second.status}`);
  await second.body?.cancel();
  assertEquals(await sql(`select count(*) from app.runs where user_id = '${a.id}'`), "0");

  // Step 3 on its own is idempotent too, which is the part a retry actually re-enters.
  const again = await sql(`select app.delete_account_batch('${a.id}', 500)`);
  assertEquals(again, "0");
});

Deno.test("6.7 deletion of a heavy account completes in bounded time, in batches", async () => {
  const a = await createUser();
  const run = newRun(a.id);
  await (await rest("runs", a.token, { method: "POST", body: JSON.stringify(run.body) }))
    .body?.cancel();

  // 500 checkpoint results, as b2 §6.7 specifies.
  await sql(`
    insert into app.checkpoint_results
      (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
       snapshot_place_name, snapshot_lore, snapshot_sources, snapshot_content_version,
       device_id, created_at, updated_at)
    select gen_random_uuid(), '${run.id}', '${a.id}', 'cp-' || g, g, now(), 'gps', 'P',
           '[]', '[]', '1', gen_random_uuid(), now(), now()
      from generate_series(1, 500) g
  `);
  assertEquals(
    await sql(`select count(*) from app.checkpoint_results where user_id = '${a.id}'`),
    "500",
  );

  const started = performance.now();
  const res = await callDelete(a.token);
  const elapsed = performance.now() - started;
  assertEquals(res.status, 200, await res.text());
  assertEquals(
    await sql(`select count(*) from app.checkpoint_results where user_id = '${a.id}'`),
    "0",
  );
  assert(elapsed < 30_000, `deletion took ${Math.round(elapsed)}ms`);
});

Deno.test("6.7b the batch function is bounded rather than one giant statement", async () => {
  // §15.2: `delete from auth.users` cascades through every table in a single statement, taking
  // every lock at once. For a heavy user that is a long transaction blocking their own sync.
  const a = await createUser();
  const run = newRun(a.id);
  await (await rest("runs", a.token, { method: "POST", body: JSON.stringify(run.body) }))
    .body?.cancel();
  await sql(`
    insert into app.checkpoint_results
      (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
       snapshot_place_name, snapshot_lore, snapshot_sources, snapshot_content_version,
       device_id, created_at, updated_at)
    select gen_random_uuid(), '${run.id}', '${a.id}', 'cp-' || g, g, now(), 'gps', 'P',
           '[]', '[]', '1', gen_random_uuid(), now(), now()
      from generate_series(1, 250) g
  `);

  const first = Number(await sql(`select app.delete_account_batch('${a.id}', 100)`));
  assert(first <= 200, `one call removed ${first} rows — the batch size is not being honoured`);
  assert(
    Number(await sql(`select count(*) from app.checkpoint_results where user_id = '${a.id}'`)) > 0,
    "a single bounded call should not have finished the job",
  );

  let guard = 0;
  while (Number(await sql(`select app.delete_account_batch('${a.id}', 100)`)) > 0 && guard < 20) {
    guard += 1;
  }
  assertEquals(
    await sql(`select count(*) from app.checkpoint_results where user_id = '${a.id}'`),
    "0",
  );
});

Deno.test("6.9 erasure finds objects past the 1000-entry page — FR-SET-02", async () => {
  // THE DEFECT: `listAll` sent {limit:1000, offset:0} ONCE per folder level and took what came
  // back, and the `photos` read was capped by `max_rows = 1000` on the PostgREST side. Both
  // truncated silently, so a heavy user's objects past the first page survived "delete all my
  // data" — §4.7's "privacy failure that passes every database test", in the one endpoint where
  // that is least acceptable.
  //
  // 1005 objects under one run prefix: five past the page boundary, which is what a truncating
  // implementation leaves behind and a paging one does not.
  const user = await createUser();
  const runId = crypto.randomUUID();
  const total = 1005;

  const uploads: Promise<unknown>[] = [];
  for (let i = 0; i < total; i++) {
    const path = `${user.id}/${runId}/obj-${String(i).padStart(4, "0")}.heic`;
    uploads.push(
      upload("trip-photos", path, user.token, new Uint8Array(8)).then((r) => r.body?.cancel()),
    );
    if (uploads.length >= 50) {
      await Promise.all(uploads.splice(0));
    }
  }
  await Promise.all(uploads);

  const before = Number(
    await sql(
      `select count(*) from storage.objects where bucket_id='trip-photos' and name like '${user.id}/%'`,
    ),
  );
  assertEquals(before, total, "fixture did not upload the expected object count");

  const res = await callDelete(user.token);
  assertEquals(res.status, 200, await res.clone().text());
  await res.body?.cancel();

  const after = await sql(
    `select count(*) from storage.objects where bucket_id='trip-photos' and name like '${user.id}/%'`,
  );
  // Against the unpaged version this is 5, not 0.
  assertEquals(after, "0", "objects past the first 1000-entry page survived deletion");
});
