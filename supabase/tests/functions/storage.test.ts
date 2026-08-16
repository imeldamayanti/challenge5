// b2 §8.11–§8.15 — Storage is a SECOND authorization system.
// docs/backend-supabase.md §8.3, §4.7, §14 defect 13, §15.3.
//
// Bucket policies are separate objects from table policies and are frequently written for `select`
// only, leaving insert, update and delete open on a private bucket. Every verb is exercised here.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { ANON_KEY, API_URL, createUser, sleep, sql, upload } from "../_helpers.ts";

const bytes = (n: number) => new Uint8Array(n).fill(7);

Deno.test("8.11 a user can upload under their own prefix", async () => {
  const a = await createUser();
  // The object name carries NO bucket prefix (§14 defect 13): Supabase keeps the bucket in
  // storage.objects.bucket_id, so 'trip-photos/{uid}/…' would make the policy compare the string
  // 'trip-photos' against a uid and match nothing.
  const res = await upload("trip-photos", `${a.id}/run-1/photo.heic`, a.token, bytes(64));
  assertEquals(res.status, 200);
  await res.body?.cancel();
});

Deno.test("8.12 B cannot upload into A's prefix", async () => {
  const a = await createUser();
  const b = await createUser();
  const res = await upload("trip-photos", `${a.id}/run-1/stolen.heic`, b.token, bytes(64));
  assert(res.status === 400 || res.status === 403, `expected refusal, got ${res.status}`);
  await res.body?.cancel();
});

Deno.test("8.12b B cannot read A's object", async () => {
  const a = await createUser();
  const b = await createUser();
  const path = `${a.id}/run-1/private.heic`;
  await (await upload("trip-photos", path, a.token, bytes(64))).body?.cancel();

  const res = await fetch(`${API_URL}/storage/v1/object/trip-photos/${path}`, {
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${b.token}` },
  });
  assert(res.status === 400 || res.status === 403 || res.status === 404,
    `expected refusal, got ${res.status}`);
  await res.body?.cancel();

  // …and A can.
  const mine = await fetch(`${API_URL}/storage/v1/object/trip-photos/${path}`, {
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${a.token}` },
  });
  assertEquals(mine.status, 200);
  await mine.body?.cancel();
});

Deno.test("8.13 update and delete on A's object as B are both refused", async () => {
  const a = await createUser();
  const b = await createUser();
  const path = `${a.id}/run-1/verbs.heic`;
  await (await upload("trip-photos", path, a.token, bytes(64))).body?.cancel();

  // These are the two verbs commonly left unpoliced.
  const update = await fetch(`${API_URL}/storage/v1/object/trip-photos/${path}`, {
    method: "PUT",
    headers: {
      apikey: ANON_KEY,
      Authorization: `Bearer ${b.token}`,
      "Content-Type": "image/heic",
    },
    body: bytes(32),
  });
  assert(update.status >= 400, `expected refusal on update, got ${update.status}`);
  await update.body?.cancel();

  const del = await fetch(`${API_URL}/storage/v1/object/trip-photos/${path}`, {
    method: "DELETE",
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${b.token}` },
  });
  assert(del.status >= 400, `expected refusal on delete, got ${del.status}`);
  await del.body?.cancel();

  // The object is still there afterwards, which is the assertion that matters.
  const still = await fetch(`${API_URL}/storage/v1/object/trip-photos/${path}`, {
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${a.token}` },
  });
  assertEquals(still.status, 200);
  await still.body?.cancel();
});

Deno.test("8.14 a file above the size limit is refused", async () => {
  const a = await createUser();
  // config.toml caps at 10 MiB (§4.7): generous for an already-downscaled 1600 px derivative, and
  // low enough that an un-downscaled original is rejected rather than silently accepted.
  const res = await upload("trip-photos", `${a.id}/run-1/original.heic`, a.token,
    bytes(11 * 1024 * 1024));
  // Storage answers 400 with `Payload too large` rather than 413; the assertion is on the refusal
  // and on the reason, not on a status code the service chooses.
  assert(res.status >= 400, `expected a refusal, got ${res.status}`);
  const body = await res.text();
  assert(/too large|exceeded|maximum/i.test(body), `unexpected refusal reason: ${body}`);
});

Deno.test("8.15 a signed URL stops working after it expires", async () => {
  const a = await createUser();
  const path = `${a.id}/run-1/shared.heic`;
  await (await upload("trip-photos", path, a.token, bytes(64))).body?.cancel();

  const signed = await fetch(`${API_URL}/storage/v1/object/sign/trip-photos/${path}`, {
    method: "POST",
    headers: {
      apikey: ANON_KEY,
      Authorization: `Bearer ${a.token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ expiresIn: 1 }),
  });
  assertEquals(signed.status, 200);
  const url = `${API_URL}/storage/v1${(await signed.json()).signedURL}`;

  const fresh = await fetch(url);
  assertEquals(fresh.status, 200);
  await fresh.body?.cancel();

  await sleep(1600);
  const stale = await fetch(url);
  assert(stale.status >= 400, `expected an expired signed URL to be refused, got ${stale.status}`);
  await stale.body?.cancel();

  // §14 defect 14, OPEN: until it expires, a signed URL in someone's hands ignores revoked_at
  // entirely. That is why share-card lifetimes want to be minutes rather than days.
});

Deno.test("6.4 the deleting flag stops an upload that is still in flight", async () => {
  // §15.3: the user taps "delete all my data" while a photograph is uploading. The Edge Function
  // removes the row and the objects; the in-flight PUT lands afterwards and recreates one — an
  // object with no row, unreachable and undeletable, on the one code path where that is least
  // acceptable.
  const a = await createUser();
  const ok = await upload("trip-photos", `${a.id}/run-1/before.heic`, a.token, bytes(64));
  assertEquals(ok.status, 200);
  await ok.body?.cancel();

  await sql(
    `insert into app.profiles (user_id, deleting_at) values ('${a.id}', now())
     on conflict (user_id) do update set deleting_at = now()`,
  );

  const blocked = await upload("trip-photos", `${a.id}/run-1/after.heic`, a.token, bytes(64));
  assert(blocked.status >= 400, `expected the flag to refuse the upload, got ${blocked.status}`);
  await blocked.body?.cancel();
});

Deno.test("the content bucket is public-read and not client-writable", async () => {
  const a = await createUser();
  // §5: the published bundle is meant to be world-readable. Its integrity rests on the checksum
  // and, per §14 defect 16, ought to rest on a detached signature as well.
  const res = await upload("content", "2026.08.1.zip", a.token, bytes(64), "application/zip");
  assert(res.status >= 400, `a client must not be able to publish content, got ${res.status}`);
  await res.body?.cancel();
});
