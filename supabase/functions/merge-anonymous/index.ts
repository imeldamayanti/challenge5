// POST /functions/v1/merge-anonymous — the §7.3 flow.
// docs/backend-supabase.md §7.3, §9.5, §15.3, §14 defect 20. b0 D7.
//
// A walker reinstalls, walks anonymously for a week, then registers with the address they used
// last year. Supabase refuses the link — that identity is taken — and the anonymous rows are
// stranded with no path anywhere. RLS forbids the client re-pointing them, and it MUST, because
// reassigning rows is an account-takeover primitive.
//
// This is an Edge Function rather than a `security definer` SQL function for one reason: a definer
// function that rewrites user_id rests its entire safety on argument validation, and plpgsql
// cannot verify a JWT signature without the signing secret. This can. Both identities are proven
// from tokens the caller had to actually hold, and NEITHER UID IS EVER READ FROM A REQUEST BODY.
//
//   1. verify the caller's JWT   → target_uid, and it is NOT anonymous
//   2. verify anon_access_token  → anon_uid, is_anonymous = true, no linked identity
//   3. refuse if target_uid = anon_uid, or if either verification fails
//   4. move objects, move rows, delete the anonymous auth.users row

import { bearer, json, preflight, rest, rpc, userFromToken } from "../_shared/http.ts";
import { copyObject, listAll, removeObjects } from "../_shared/storage.ts";

const BUCKETS = ["trip-photos", "share-cards"];

Deno.serve(async (req: Request) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const token = bearer(req);
  if (!token) return json({ error: "unauthenticated" }, 401);

  // 1 — the target, from the caller's own session.
  const target = await userFromToken(token);
  if (!target) return json({ error: "unauthenticated" }, 401);
  if (target.is_anonymous) {
    return json({ error: "the target of a merge must be a linked account" }, 400);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "malformed json" }, 400);
  }

  const anonToken = body["anon_access_token"];
  if (typeof anonToken !== "string" || anonToken.length === 0) {
    return json({ error: "anon_access_token required" }, 400);
  }

  // 2 — the source, from a token the caller had to actually hold. A forged or expired token gets
  //     nothing back from GoTrue, which is the single most important rejection in this file: a
  //     merge that trusts its input is account takeover.
  const anon = await userFromToken(anonToken);
  if (!anon) return json({ error: "anonymous session could not be verified" }, 401);
  if (!anon.is_anonymous) return json({ error: "source session is not anonymous" }, 400);
  if ((anon.identities ?? []).length > 0) {
    return json({ error: "source session already has a linked identity" }, 400);
  }

  // 3
  if (anon.id === target.id) return json({ error: "refusing to merge an identity into itself" }, 400);

  // §15.3: the merge moves rows while a device may still be pushing to either identity. Rejecting
  // is simpler than reconciling mid-move, and the client retries once its queue drains. The server
  // cannot see the client's `sync_state`, so the client asserts it — and the assertion has to be
  // explicit, because a default of "probably fine" is how this becomes a silent half-merge.
  if (body["anon_queue_empty"] !== true) {
    return json({ error: "anon_queue_empty must be asserted true; drain the push queue first" }, 409);
  }

  // 4a — objects first: COPY, then move the rows, then delete the originals, so an interruption at
  //      any point leaves the original readable (§7.3 rule 4).
  const copied: Array<{ bucket: string; from: string }> = [];
  for (const bucket of BUCKETS) {
    for (const from of await listAll(bucket, `${anon.id}/`)) {
      const to = `${target.id}/${from.slice(anon.id.length + 1)}`;
      if (await copyObject(bucket, from, to)) copied.push({ bucket, from });
    }
  }

  // 4b — rows, with both collisions resolved inside one transaction (§7.3 rules 2, 3, 5).
  const res = await rpc("merge_anonymous_rows", { anon_uid: anon.id, target_uid: target.id });
  if (!res.ok) {
    const detail = await res.text();
    console.error("merge_anonymous_rows failed", res.status, detail);
    // The copies are left in place: they are unreachable duplicates under the target's prefix,
    // which the orphan sweeper (§4.7) removes. Deleting them here would risk removing the only
    // copy if the failure was partial.
    return json({ error: "merge failed", detail }, 500);
  }
  const summary = await res.json();

  // 4c — the originals, now that the rows point at the new prefix.
  for (const bucket of BUCKETS) {
    const stale = copied.filter((c) => c.bucket === bucket).map((c) => c.from);
    // Failures are surfaced rather than swallowed: these are the ANONYMOUS user's objects, already
    // copied to the target, so anything left behind is a duplicate of the walker's own data
    // sitting under an identity they no longer control.
    const leftover = await removeObjects(bucket, stale);
    if (leftover.length > 0) {
      console.error("merge: could not remove source objects", bucket, leftover.length);
    }
  }

  // Idempotent (§7.3 rule 1): a second run finds no anonymous user, no objects and no rows, and
  // reports zero moved rather than failing.
  const remaining = await rest(`runs?user_id=eq.${anon.id}&select=id`);
  const leftover = remaining.ok ? (await remaining.json()).length : 0;

  return json({ merged: true, ...summary, objects_moved: copied.length, leftover_rows: leftover }, 200);
});
