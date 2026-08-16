// POST /functions/v1/ingest — anonymous telemetry and survey ingest.
// docs/backend-supabase.md §6.2, §2.4, §12 phase 0. b0 D7. NFR-SEC-03, NFR-OBS-01, FR-ERR-10.
//
// DELIBERATELY UNAUTHENTICATED (`verify_jwt = false` in config.toml). Insert-only RLS for `anon`
// would be simpler and is rejected: it hands every installed copy of the app a token that writes
// directly to the database. This function is where batching limits, schema-version rejection and
// rate limits live, and it is write-only BY CONSTRUCTION rather than by policy — there is no read
// path in this file, and `app.ingest_batch` (migration 0003) returns counts, never rows.
//
// It also never learns who the caller is. `ops.events` has no user_id column and must never
// acquire one (§2.4); a `user_id` field in the payload is ignored because the insert names its
// columns.

import { json, preflight, rpc } from "../_shared/http.ts";
import { clientIp, rateLimited } from "../_shared/ratelimit.ts";

const SUPPORTED_SCHEMA_VERSION = 1;
const MAX_BATCH_ROWS = 200;

/**
 * A byte ceiling on the request body, checked BEFORE parsing.
 *
 * `MAX_BATCH_ROWS` protects the DATABASE and is enforced after `req.json()` has already
 * materialised the whole body — so a multi-megabyte payload was fully parsed into worker memory
 * before anything looked at how many rows it claimed. On the one deliberately unauthenticated
 * endpoint in the system, that is a cheap denial of service that the row cap does nothing about.
 *
 * 200 rows of the shapes §2.4 allows — a uuid, a short name, a small params object, two
 * timestamps — is comfortably under 256 KB. 512 KB leaves room without leaving a hole.
 */
const MAX_BODY_BYTES = 512 * 1024;

Deno.serve(async (req: Request) => {
  const pre = preflight(req);
  if (pre) return pre;

  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  if (rateLimited(clientIp(req))) {
    return json({ error: "rate limited" }, 429);
  }

  // The body is read as a BOUNDED STREAM rather than with `req.json()`.
  //
  // `MAX_BATCH_ROWS` protects the DATABASE and is checked only after the whole body exists, so a
  // multi-megabyte payload used to be materialised in worker memory before anything asked how many
  // rows it claimed — on the one deliberately unauthenticated endpoint in the system.
  //
  // Two things this shape gets right that the obvious versions do not:
  //   * memory is capped at roughly MAX_BODY_BYTES plus one chunk, no matter what is sent; and
  //   * the stream is DRAINED TO THE END even when it is already over the limit. Returning early
  //     without draining leaves the sender mid-upload and the connection hangs instead of
  //     receiving the 413 — found the hard way: 400 KB answered instantly, and 520 KB, the first
  //     size over the cap, timed out. A refusal nobody receives is worse than no check, because
  //     the caller retries forever.
  let payload: Record<string, unknown>;
  try {
    const reader = req.body?.getReader();
    const chunks: Uint8Array[] = [];
    let total = 0;
    let overflowed = false;

    if (reader) {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        total += value.byteLength;
        if (total > MAX_BODY_BYTES) {
          // Stop keeping bytes, keep consuming them.
          overflowed = true;
          chunks.length = 0;
        } else {
          chunks.push(value);
        }
      }
    }

    if (overflowed) {
      return json({ error: "payload too large", maxBytes: MAX_BODY_BYTES }, 413);
    }

    const body = new Uint8Array(total);
    let offset = 0;
    for (const c of chunks) {
      body.set(c, offset);
      offset += c.byteLength;
    }
    payload = JSON.parse(new TextDecoder().decode(body));
  } catch {
    return json({ error: "malformed json" }, 400);
  }

  if (typeof payload !== "object" || payload === null || Array.isArray(payload)) {
    return json({ error: "malformed json" }, 400);
  }

  const version = payload["schema_version"];
  if (version !== SUPPORTED_SCHEMA_VERSION) {
    // Rejected, NOT stored. §9.1's reasoning applied to telemetry: a row that arrives in an
    // unknown shape is noise in a chart nobody can later identify.
    return json({ error: "unsupported schema_version", supported: SUPPORTED_SCHEMA_VERSION }, 400);
  }

  const events = Array.isArray(payload["events"]) ? payload["events"] : [];
  const survey = Array.isArray(payload["survey_responses"]) ? payload["survey_responses"] : [];
  if (events.length + survey.length === 0) return json({ error: "empty batch" }, 400);
  if (events.length + survey.length > MAX_BATCH_ROWS) {
    return json({ error: "batch too large", max: MAX_BATCH_ROWS }, 400);
  }

  const res = await rpc("ingest_batch", {
    payload: { schema_version: version, events, survey_responses: survey },
  });

  if (!res.ok) {
    const detail = await res.text();
    console.error("ingest_batch failed", res.status, detail);
    return json({ error: "ingest failed" }, res.status === 400 ? 400 : 502);
  }

  // The client marks its queue sent on a 200 and leaves it queued on anything else
  // (system-design.md §10). Survey rows are never pruned locally (FR-ERR-10).
  return json(await res.json(), 200);
});
