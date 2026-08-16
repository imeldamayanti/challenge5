// b2 §8.1–§8.6 — the ingest Edge Function.
// docs/backend-supabase.md §6.2, §2.4, NFR-SEC-03, NFR-OBS-01.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { API_URL, fn, SERVICE_KEY, sql } from "../_helpers.ts";

function batch(overrides: Record<string, unknown> = {}) {
  return {
    schema_version: 1,
    events: [{
      id: crypto.randomUUID(),
      name: "checkpoint_arrived",
      params: { questID: "badung-empat-wajah", accuracyBucket: "lt20" },
      run_key: crypto.randomUUID(),
      occurred_at: new Date().toISOString(),
    }],
    ...overrides,
  };
}

// Each test uses its own client IP so the fixed-window counter in one does not spill into the next.
function post(body: unknown, ip: string, headers: Record<string, string> = {}) {
  return fn("ingest", {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-forwarded-for": ip, ...headers },
    body: JSON.stringify(body),
  });
}

Deno.test("8.1 a valid batch with no JWT is accepted", async () => {
  // verify_jwt = false is deliberate: NFR-SEC-03 prefers accepting junk to shipping a credential
  // in every copy of the app.
  const res = await post(batch(), "10.0.0.1");
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.accepted_events, 1);
});

Deno.test("8.2 an unknown schema_version is rejected, not stored", async () => {
  const id = crypto.randomUUID();
  const res = await post(
    { schema_version: 99, events: [{ id, name: "x", params: {}, occurred_at: new Date().toISOString() }] },
    "10.0.0.2",
  );
  assertEquals(res.status, 400);
  const body = await res.json();
  assertEquals(body.error, "unsupported schema_version");

  // "Rejected, not stored" is the half that matters, so it is checked directly: the row is absent
  // from ops.events. This inspection runs as `postgres` deliberately — it is asking what a table
  // contains, which is the one thing an elevated connection is good for (b0 D9).
  assertEquals(await sql(`select count(*) from ops.events where id = '${id}'`), "0");
});

Deno.test("8.2b the SQL function rejects it too, so the cap is not one layer deep", async () => {
  const res = await fetch(`${API_URL}/rest/v1/rpc/ingest_batch`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      "Content-Profile": "app",
    },
    body: JSON.stringify({ payload: { schema_version: 99, events: [] } }),
  });
  assertEquals(res.status, 400);
});

Deno.test("8.3 a batch over the cap is rejected", async () => {
  const events = Array.from({ length: 201 }, () => ({
    id: crypto.randomUUID(),
    name: "checkpoint_arrived",
    params: {},
    occurred_at: new Date().toISOString(),
  }));
  const res = await post({ schema_version: 1, events }, "10.0.0.3");
  assertEquals(res.status, 400);
  assertEquals((await res.json()).error, "batch too large");
});

Deno.test("8.4 repeated calls from one IP are rate limited", async () => {
  const ip = "10.0.0.4";
  let limited = 0;
  for (let i = 0; i < 75; i++) {
    const res = await post(batch(), ip);
    await res.body?.cancel();
    if (res.status === 429) limited += 1;
  }
  assert(limited > 0, "expected at least one 429 within 75 requests");
});

Deno.test("8.5 there is no read path: every other method is refused", async () => {
  const get = await fn("ingest", { method: "GET" });
  assertEquals(get.status, 405);
  await get.body?.cancel();

  // The success response carries counts, never rows.
  const res = await post(batch(), "10.0.0.5");
  const body = await res.json();
  assertEquals(Object.keys(body).sort(), ["accepted_events", "accepted_survey"]);
});

Deno.test("8.6 a user_id in the payload is ignored", async () => {
  // ops.events has no user_id column and must never acquire one (§2.4). The insert names its
  // columns, so an extra field is dropped rather than stored — and if the column were ever added,
  // this test would still pass, which is why 01_structure.test.sql asserts the column's ABSENCE.
  const res = await post(
    {
      schema_version: 1,
      events: [{
        id: crypto.randomUUID(),
        name: "checkpoint_arrived",
        params: {},
        user_id: "11111111-1111-4111-8111-111111111111",
        occurred_at: new Date().toISOString(),
      }],
    },
    "10.0.0.6",
  );
  assertEquals(res.status, 200);
  assertEquals((await res.json()).accepted_events, 1);
});

Deno.test("survey rows travel the same path (FR-ERR-10)", async () => {
  const res = await post(
    {
      schema_version: 1,
      survey_responses: [{
        id: crypto.randomUUID(),
        run_key: crypto.randomUUID(),
        quest_id: "badung-empat-wajah",
        question_id: "q1",
        response: "ya",
        occurred_at: new Date().toISOString(),
      }],
    },
    "10.0.0.7",
  );
  assertEquals(res.status, 200);
  assertEquals((await res.json()).accepted_survey, 1);
});

Deno.test("a malformed body is a 400 rather than a 500", async () => {
  const res = await fn("ingest", {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-forwarded-for": "10.0.0.8" },
    body: "{not json",
  });
  assertEquals(res.status, 400);
  assertEquals((await res.json()).error, "malformed json");
});

Deno.test("2.9 an oversized body is refused before it is parsed", async () => {
  // MAX_BATCH_ROWS protects the DATABASE and is checked AFTER the body has been materialised, so
  // before 0016 a multi-megabyte payload was fully parsed into worker memory before anything asked
  // how many rows it claimed — on the only deliberately unauthenticated endpoint in the system.
  const fat = {
    schema_version: 1,
    events: [{
      id: crypto.randomUUID(),
      name: "x".repeat(2 * 1024 * 1024),
      params: {},
      occurred_at: new Date().toISOString(),
    }],
  };
  const res = await fn("ingest", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(fat),
  });
  assertEquals(res.status, 413);
  await res.body?.cancel();
});

Deno.test("2.10 a JSON array body is refused rather than treated as an object", async () => {
  // `payload["schema_version"]` on an array is undefined, so this already ended in a 400 — but by
  // way of an indexing expression on the wrong type rather than a shape check. Pinned explicitly.
  const res = await fn("ingest", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify([{ schema_version: 1 }]),
  });
  assertEquals(res.status, 400);
  await res.body?.cancel();
});
