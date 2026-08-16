// POST /functions/v1/publish-suppressions — publish the kill-switch document to Storage.
// docs/backend-supabase.md §6.1, §5. AD-5, FR-ERR-09, NFR-SEC-02. c1 §4a.
//
// THE HALF OF MIGRATION 0004 THAT WAS NEVER WRITTEN.
// 0004's trigger derives ops.suppressions_document transactionally on every change to
// ops.suppressions, and states in its own header that publication is "a read of one row by a
// privileged caller (an Edge Function or a scheduled job)". This is that caller. Until it existed,
// AD-5's kill-switch could withdraw a place in the database and no installed app would ever hear
// about it — a release gate with no release.
//
// OPERATOR TOOL, NOT A CLIENT ENDPOINT. `verify_jwt = true` in config.toml, and the only caller
// that can do anything useful holds the service role. Nothing a walker's device runs calls this.

import { corsHeaders, json, preflight, rpc, serviceKey, supabaseUrl } from "../_shared/http.ts";

const BUCKET = "content";
const OBJECT = "suppressions.json";

/**
 * How long a cached copy may be served.
 *
 * AD-5's floor is "applies on next launch". Five minutes at the CDN is well inside that and keeps a
 * withdrawal from waiting on a release cycle. It is deliberately not `no-cache`: a kill-switch
 * document that cannot be cached is one that fails whenever the origin is slow, and FR-ERR-09
 * requires the client to survive exactly that — but making the client carry the whole burden when a
 * short cache costs nothing would be the wrong half to lean on.
 */
const CACHE_CONTROL = "300";

/**
 * Whether the caller is the service role.
 *
 * **Not a string comparison against `SUPABASE_SERVICE_ROLE_KEY`, and that was the first version's
 * bug.** A project carries two generations of credential at once — the legacy `service_role` JWT
 * and an opaque `sb_secret_…` — and the one injected into the function's environment need not be
 * the one an operator holds. Locally both are the same well-known development string, so equality
 * passed every test and then refused the real service role on the first prod call.
 *
 * `verify_jwt = true` has already verified the signature before this function runs, so reading the
 * `role` claim off the token is sound: an unsigned or wrongly signed token never gets here. The
 * equality branch stays for the opaque form, which carries no claims to read.
 */
function isServiceRole(token: string): boolean {
  if (token === serviceKey()) return true;

  const parts = token.split(".");
  if (parts.length !== 3) return false;
  try {
    const payload = JSON.parse(
      atob(parts[1].replace(/-/g, "+").replace(/_/g, "/")),
    );
    return payload?.role === "service_role";
  } catch {
    return false;
  }
}

/** Rejects anything that is not the schema-2 document 0004 builds (schema.md §A.8). */
function isPublishable(doc: unknown): doc is Record<string, unknown> {
  if (typeof doc !== "object" || doc === null) return false;
  const d = doc as Record<string, unknown>;
  if (typeof d["schemaVersion"] !== "number") return false;
  if (typeof d["updatedAt"] !== "string") return false;
  // All three arrays, always — an absent array and an empty one mean different things to a
  // consumer, and D2 forbids publishing a document that is plausible but incomplete.
  for (const key of ["suppressedPlaceIds", "suppressedQuestIds", "suppressedSideQuestIds"]) {
    const value = d[key];
    if (!Array.isArray(value)) return false;
    if (!value.every((v) => typeof v === "string" && v.length > 0)) return false;
  }
  return true;
}

Deno.serve(async (req: Request) => {
  const pre = preflight(req);
  if (pre) return pre;

  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  // The service role is not merely sufficient here, it is required: app.published_suppressions()
  // is granted to service_role alone (migration 0014), so a caller holding any other token gets a
  // permission error from Postgres rather than a document. Checked here as well so the refusal is a
  // 403 with a reason rather than a 502 with a stack trace.
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.toLowerCase().startsWith("bearer ") || !isServiceRole(auth.slice(7).trim())) {
    return json({ error: "service role required" }, 403);
  }

  const read = await rpc("published_suppressions", {});
  if (!read.ok) {
    console.error("published_suppressions failed", read.status, await read.text());
    return json({ error: "could not read the suppressions document" }, 502);
  }

  const document = await read.json();
  if (!isPublishable(document)) {
    // Refusing to publish is the safe failure. A malformed document sent to the bucket would be
    // discarded by every client in favour of its last good copy, which is a withdrawal that
    // silently stops applying — the exact failure AD-5 exists to prevent.
    console.error("refusing to publish a malformed document", JSON.stringify(document));
    return json({ error: "the stored document is not schema-valid" }, 500);
  }

  // Written whole, never patched (c1 D2). `x-upsert` makes republishing idempotent, which matters
  // because the only sane retry for a failed publish is the same publish again.
  const body = JSON.stringify(document);
  const put = await fetch(`${supabaseUrl()}/storage/v1/object/${BUCKET}/${OBJECT}`, {
    method: "POST",
    headers: {
      apikey: serviceKey(),
      Authorization: `Bearer ${serviceKey()}`,
      "Content-Type": "application/json",
      "Cache-Control": CACHE_CONTROL,
      "x-upsert": "true",
    },
    body,
  });

  if (!put.ok) {
    const detail = await put.text();
    console.error("storage write failed", put.status, detail);
    return json({ error: "could not publish" }, 502);
  }

  // The document comes back so an operator can verify what was published without a second request
  // against a bucket that may still be serving a cached copy.
  return new Response(
    JSON.stringify({ published: true, bucket: BUCKET, object: OBJECT, document }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
