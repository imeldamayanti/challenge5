// POST /functions/v1/delete-account — FR-SET-02, "delete all my data".
// docs/backend-supabase.md §8, §4.7, §15.2, §15.3. b0 D7.
//
// IT CANNOT BE ONE TRANSACTION, and an earlier draft of the design claimed it could. Postgres and
// object storage are two systems and no transaction spans them, so the order has to make the
// SURVIVING state safe instead:
//
//   1. mark the user deleting        — a flag the upload path checks (§15.3)
//   2. delete every storage object   — idempotent; deleting a missing object is a no-op
//   3. hard-delete rows, in batches  — §15.2: one giant cascade takes every lock at once
//   4. delete the auth.users row
//
// Objects FIRST. A crash after step 2 leaves rows pointing at bytes that are gone, which reads as
// a broken thumbnail and is recoverable. The reverse order leaves bytes with no row — unreachable,
// undeletable, and still personal data. Of the two possible half-states only one is survivable, so
// the order is not a preference.

import { bearer, deleteAuthUser, json, preflight, rest, rpc, userFromToken } from "../_shared/http.ts";
import { listAll, removeObjects } from "../_shared/storage.ts";

const BATCH = 500;

Deno.serve(async (req: Request) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const token = bearer(req);
  if (!token) return json({ error: "unauthenticated" }, 401);

  const caller = await userFromToken(token);
  if (!caller) return json({ error: "unauthenticated" }, 401);

  // A caller may only delete themselves. The body's user_id is accepted so the mistake is an
  // explicit rejection rather than a silently ignored field.
  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch { /* empty body is the normal case */ }
  const requested = body["user_id"];
  if (typeof requested === "string" && requested !== caller.id) {
    return json({ error: "a caller may only delete their own account" }, 403);
  }

  const uid = caller.id;

  // 1 — the deleting flag (§15.3). Narrows the upload-completes-after-deletion race; the orphan
  //     sweeper is the backstop, because a narrowed race is not a closed one.
  const flag = await rest("profiles?on_conflict=user_id", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify({ user_id: uid, deleting_at: new Date().toISOString() }),
  });
  if (!flag.ok) {
    console.error("could not set deleting flag", flag.status, await flag.text());
    return json({ error: "could not begin deletion" }, 500);
  }

  // 2 — objects. By stored path AND by prefix sweep: a row whose uploaded_at is null may still
  //     have a partial object at either path, and an object with no row at all is exactly what the
  //     sweeper exists for.
  // `config.toml` sets `max_rows = 1000`, which caps EVERY PostgREST response — so the unpaged
  // version of this read returned at most 1000 photo rows and silently missed the rest of a heavy
  // user's paths. The prefix sweep below is the backstop, and it had the same 1000-entry bug.
  // Both are fixed; both are kept, because they fail in different directions: the table knows
  // about objects outside the uid prefix, and the sweep knows about objects the table has lost.
  async function allPaths(table: string, columns: string[]): Promise<string[]> {
    const found: string[] = [];
    const PAGE = 1000;
    for (let offset = 0; ; offset += PAGE) {
      const res = await rest(
        `${table}?user_id=eq.${uid}&select=${columns.join(",")}&limit=${PAGE}&offset=${offset}`,
      );
      if (!res.ok) {
        throw new Error(`could not read ${table}: ${res.status} ${await res.text()}`);
      }
      const rows = await res.json();
      for (const r of rows) for (const c of columns) if (r[c]) found.push(r[c]);
      if (rows.length < PAGE) break;
    }
    return found;
  }

  let orphans: string[] = [];
  try {
    const photoPaths = await allPaths("photos", ["storage_path", "thumb_path"]);
    photoPaths.push(...await listAll("trip-photos", `${uid}/`));
    orphans.push(
      ...(await removeObjects("trip-photos", [...new Set(photoPaths)])).map((p) => `trip-photos/${p}`),
    );

    const cardPaths = await allPaths("share_cards", ["storage_path"]);
    cardPaths.push(...await listAll("share-cards", `${uid}/`));
    orphans.push(
      ...(await removeObjects("share-cards", [...new Set(cardPaths)])).map((p) => `share-cards/${p}`),
    );
  } catch (e) {
    // Could not even enumerate. Stop BEFORE deleting rows: rows are the only remaining record of
    // which objects exist, so destroying them here would strand the bytes permanently.
    console.error("storage enumeration failed", e);
    return json({ error: "could not enumerate stored objects; nothing was deleted" }, 502);
  }

  if (orphans.length > 0) {
    // Rows are deliberately NOT deleted. FR-SET-02 is a promise about bytes; reporting success
    // with objects still standing is the one failure this endpoint must never produce, and
    // keeping the rows is what makes a retry able to find them.
    console.error("storage delete failed for", orphans.length, "objects");
    return json({ error: "storage deletion incomplete; nothing was deleted", objects_remaining: orphans.length }, 502);
  }

  // 3 — rows, leaf-first, in bounded batches, committing between them (§15.2).
  let removed = 0;
  for (let i = 0; i < 200; i++) {
    const res = await rpc("delete_account_batch", { target_uid: uid, batch_size: BATCH });
    if (!res.ok) {
      console.error("delete_account_batch failed", res.status, await res.text());
      return json({ error: "deletion incomplete", rows_removed: removed }, 500);
    }
    const n = await res.json();
    removed += n;
    if (n === 0) break;
    if (i === 199) {
      // 200 × 500 = 100 000 rows. Past that the loop used to fall out silently and step 4's
      // `delete auth.users` finished the job by ONE GIANT CASCADE — precisely what §15.2 batches
      // to avoid, taking every lock on every table at once. Refuse instead, and say so: a caller
      // can re-invoke, and each re-invocation clears another 100 000.
      console.error("delete_account_batch hit the loop cap with rows remaining", { uid, removed });
      return json({
        error: "deletion incomplete; re-invoke to continue",
        rows_removed: removed,
        more: true,
      }, 202);
    }
  }

  // 4 — the auth.users row, last.
  const gone = await deleteAuthUser(uid);
  if (!gone.ok && gone.status !== 404) {
    console.error("auth user delete failed", gone.status, await gone.text());
    return json({ error: "rows deleted, identity remains", rows_removed: removed }, 500);
  }

  // Idempotent: a re-run finds no objects, no rows and no user, and returns the same shape.
  return json({ deleted: true, rows_removed: removed }, 200);
});
