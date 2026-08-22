// GET /functions/v1/share/{slug} — serve one shared recap card. `c2` phase 5.
//
// **NOT DEPLOYED.** Phase 5 is blocked on the consent position in
// `.claude/plans/supabase/c2-wiring/03-security-privacy.md` §4, and this file exists so the
// engineering is done rather than pending. Deploying it publishes walks through five sites whose
// consent records are a self-grant (`docs/consent-log.md`); that is a decision with an owner.
//
// `verify_jwt = false`, because the whole point is a link a person without the app can open. That
// makes this the only public surface the project has, so three things about it are deliberate:
//
//  1. **The bytes are streamed, never a signed URL.** Returning one hands the caller a credential
//     that outlives the revocation — the link would keep working after the walker turned it off,
//     which is precisely the failure a revoke control exists to prevent. Every request is checked.
//  2. **The check is per request**, not per mint: `revoked_at`, `expires_at`, and `deleted_at`.
//  3. **An unknown slug 404s** rather than erroring. An error message that distinguishes "no such
//     card" from "revoked" tells a stranger which slugs exist.

import { corsHeaders, json, preflight, serviceKey, supabaseUrl } from "../_shared/http.ts";

/// Slugs are opaque and fixed-shape. Anything else is not looked up at all, so a malformed path
/// cannot reach PostgREST as a filter value.
const SLUG = /^[A-Za-z0-9_-]{16,64}$/;

/// Short enough that a leaked internal URL is worthless, long enough to finish one download.
const SIGNED_URL_SECONDS = 60;

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "GET") return json({ error: "method not allowed" }, 405);

  const slug = new URL(req.url).pathname.split("/").filter(Boolean).pop() ?? "";
  if (!SLUG.test(slug)) return notFound();

  const query = new URL(`${supabaseUrl()}/rest/v1/share_cards`);
  query.searchParams.set("select", "storage_path,expires_at,revoked_at,deleted_at");
  query.searchParams.set("public_slug", `eq.${slug}`);
  query.searchParams.set("limit", "1");

  // The service role, because there is no user here by design. It reads one row by an opaque
  // slug and never takes a caller-supplied filter beyond it.
  const key = serviceKey();
  const found = await fetch(query, {
    headers: { apikey: key, Authorization: `Bearer ${key}`, Accept: "application/json" },
  });
  if (!found.ok) return json({ error: "unavailable" }, 503);

  const rows = await found.json();
  const card = Array.isArray(rows) ? rows[0] : undefined;
  if (!card || card.deleted_at || card.revoked_at) return notFound();
  if (card.expires_at && Date.parse(card.expires_at) <= Date.now()) return notFound();

  const signed = await fetch(
    `${supabaseUrl()}/storage/v1/object/sign/share-cards/${card.storage_path}`,
    {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ expiresIn: SIGNED_URL_SECONDS }),
    },
  );
  if (!signed.ok) return notFound();

  const { signedURL } = await signed.json();
  const object = await fetch(`${supabaseUrl()}/storage/v1${signedURL}`);
  if (!object.ok) return notFound();

  return new Response(object.body, {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": object.headers.get("content-type") ?? "image/png",
      // **Not cacheable.** A revoked card must stop being served on the next request, and a CDN
      // holding it for five minutes is five minutes of a link the walker believes is off.
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
});

/// One shape for every refusal, so a stranger cannot tell a revoked card from one that never
/// existed by reading the response.
function notFound(): Response {
  return json({ error: "not found" }, 404);
}
