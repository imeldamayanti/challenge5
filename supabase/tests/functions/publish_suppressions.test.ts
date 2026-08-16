// c1 §4a — the kill-switch publisher.
// docs/backend-supabase.md §6.1, §5. AD-5, FR-ERR-09, NFR-SEC-02.
//
// Proved over HTTP with real tokens (b3 §4), not by querying the table: the whole point of the
// publisher is what a client can FETCH from the bucket, and a psql query proves nothing about that.
// `sql` appears below only to seed and clean ops.suppressions, which is not reachable over the API
// by design — never to assert.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { ANON_KEY, API_URL, SERVICE_KEY, createUser, fn, sql } from "../_helpers.ts";

const OBJECT_URL = `${API_URL}/storage/v1/object/content/suppressions.json`;

function publish(token: string): Promise<Response> {
  return fn("publish-suppressions", {
    method: "POST",
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${token}` },
  });
}

async function fetchPublished(): Promise<Record<string, unknown>> {
  // Anonymous, with no Authorization header at all: `content` is public-read (migration 0009), and
  // the app fetches this file before it has any notion of a user.
  const res = await fetch(OBJECT_URL, { headers: { apikey: ANON_KEY } });
  assertEquals(res.status, 200, `the published document was not publicly readable`);
  return await res.json();
}

Deno.test("c1.1 the publisher writes a schema-2 document carrying all three arrays", async () => {
  await sql("delete from ops.suppressions");
  await sql(
    `insert into ops.suppressions (entity_type, entity_id, reason) values
       ('place','fixture-place-1','test'),
       ('quest','fixture-quest-1','test'),
       ('sidequest','fixture-sidequest-1','test')`,
  );

  const res = await publish(SERVICE_KEY);
  assertEquals(res.status, 200);
  await res.body?.cancel();

  const doc = await fetchPublished();
  assertEquals(doc["schemaVersion"], 2);
  assertEquals(doc["suppressedPlaceIds"], ["fixture-place-1"]);
  assertEquals(doc["suppressedQuestIds"], ["fixture-quest-1"]);
  assertEquals(doc["suppressedSideQuestIds"], ["fixture-sidequest-1"]);
  assert(typeof doc["updatedAt"] === "string" && (doc["updatedAt"] as string).endsWith("Z"));
});

Deno.test("c1.2 a released suppression leaves the document", async () => {
  // The kill-switch has to be reversible or it is a delete. `released_at` is what makes a
  // withdrawal a withdrawal rather than a tombstone.
  await sql("delete from ops.suppressions");
  await sql(
    `insert into ops.suppressions (entity_type, entity_id, reason) values ('place','fixture-p','x')`,
  );
  await (await publish(SERVICE_KEY)).body?.cancel();
  assertEquals((await fetchPublished())["suppressedPlaceIds"], ["fixture-p"]);

  await sql("update ops.suppressions set released_at = now() where entity_id = 'fixture-p'");
  await (await publish(SERVICE_KEY)).body?.cancel();
  assertEquals((await fetchPublished())["suppressedPlaceIds"], []);
});

Deno.test("c1.3 a schema-1 consumer still validates the schema-2 document", async () => {
  // c1 D3, and the reason `GovernanceKit` decodes the third array as `decodeIfPresent ?? []`.
  //
  // The direction that matters is the one a rollback produces: a schema-1 DOCUMENT reaching a
  // schema-2 client. Modelled here as the decode a schema-1 consumer performs — the two arrays it
  // knows about, both present and both well-formed — against the document actually published. If a
  // schema bump ever renamed or retyped them, this fails, and the failure mode it prevents is a
  // withdrawal that silently stops applying.
  await sql("delete from ops.suppressions");
  await sql(
    `insert into ops.suppressions (entity_type, entity_id, reason) values
       ('place','fixture-place-2','test'), ('quest','fixture-quest-2','test')`,
  );
  await (await publish(SERVICE_KEY)).body?.cancel();

  const doc = await fetchPublished();
  const schemaOneView = {
    schemaVersion: doc["schemaVersion"],
    updatedAt: doc["updatedAt"],
    suppressedPlaceIds: doc["suppressedPlaceIds"],
    suppressedQuestIds: doc["suppressedQuestIds"],
  };
  assert(typeof schemaOneView.schemaVersion === "number");
  assert(typeof schemaOneView.updatedAt === "string");
  assertEquals(schemaOneView.suppressedPlaceIds, ["fixture-place-2"]);
  assertEquals(schemaOneView.suppressedQuestIds, ["fixture-quest-2"]);
  // …and the unknown key is additive rather than replacing anything the older consumer reads.
  assert(Array.isArray(doc["suppressedSideQuestIds"]));
});

Deno.test("c1.4 a user token cannot publish", async () => {
  // The outer gate is `verify_jwt = true`; this is the inner one. A signed-in walker holds a valid
  // JWT, so without the service-role check the request would reach Postgres and fail there — a 502
  // with a permission error instead of a refusal with a reason.
  const user = await createUser();
  const res = await publish(user.token);
  assertEquals(res.status, 403);
  await res.body?.cancel();
});

Deno.test("c1.5 the anon key cannot publish", async () => {
  const res = await publish(ANON_KEY);
  assert(res.status === 401 || res.status === 403, `expected refusal, got ${res.status}`);
  await res.body?.cancel();
});

Deno.test("c1.6 GET is refused", async () => {
  // Publishing is a side effect. A GET that publishes is one a crawler, a prefetch or a browser
  // address bar can trigger.
  const res = await fetch(`${API_URL}/functions/v1/publish-suppressions`, {
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
  });
  assert(res.status === 405 || res.status === 401, `expected refusal, got ${res.status}`);
  await res.body?.cancel();
});

Deno.test("c1.7 republishing is idempotent", async () => {
  // The only sane retry for a failed publish is the same publish again, so the second one must not
  // fail on an existing object (`x-upsert`).
  await sql("delete from ops.suppressions");
  await sql(
    `insert into ops.suppressions (entity_type, entity_id, reason) values ('quest','fixture-q','x')`,
  );
  for (let i = 0; i < 2; i++) {
    const res = await publish(SERVICE_KEY);
    assertEquals(res.status, 200, `publish ${i + 1} failed`);
    await res.body?.cancel();
  }
  assertEquals((await fetchPublished())["suppressedQuestIds"], ["fixture-q"]);

  await sql("delete from ops.suppressions");
  await (await publish(SERVICE_KEY)).body?.cancel();
});

Deno.test("c1.8 a legacy service_role JWT is authorised by its claim, not by string equality", async () => {
  // The prod regression, pinned. The first version compared the bearer to
  // SUPABASE_SERVICE_ROLE_KEY, which passes locally — both sides are the same well-known
  // development string — and refused the real service role on the first hosted call, because a
  // project carries two credential generations at once (a legacy `service_role` JWT and an opaque
  // `sb_secret_…`) and the one injected into the function environment need not be the one an
  // operator holds.
  //
  // Signed with the local JWT secret and deliberately NOT the value of SUPABASE_SERVICE_ROLE_KEY:
  // a different `iat`/`exp` makes it a distinct string carrying the same claim, which is precisely
  // the case equality gets wrong.
  const secret = "super-secret-jwt-token-with-at-least-32-characters-long";
  const b64 = (o: unknown) =>
    btoa(JSON.stringify(o)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const head = b64({ alg: "HS256", typ: "JWT" });
  const body = b64({
    iss: "supabase-demo",
    role: "service_role",
    iat: 1700000001,
    exp: 1983812997,
  });
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${head}.${body}`));
  const b64sig = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const token = `${head}.${body}.${b64sig}`;

  assert(token !== SERVICE_KEY, "the fixture token must differ from the env key, or it proves nothing");

  await sql("delete from ops.suppressions");
  const res = await publish(token);
  assertEquals(res.status, 200, `a service_role JWT was refused: ${await res.clone().text()}`);
  await res.body?.cancel();
});

Deno.test("c1.9 an authenticated token whose claim is not service_role is still refused", async () => {
  // The other half of c1.8: reading a claim must not become "any well-formed JWT gets in".
  const user = await createUser();
  const res = await publish(user.token);
  assertEquals(res.status, 403);
  await res.body?.cancel();
});
