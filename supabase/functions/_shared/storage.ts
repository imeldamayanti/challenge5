// Storage REST helpers. Storage is a SECOND authorization system (design §8.3) and a second
// STORE: no Postgres transaction spans it, which is why the deletion order in §8 is a design
// decision rather than an implementation detail.

import { serviceKey, supabaseUrl } from "./http.ts";

function headers(): HeadersInit {
  return {
    apikey: serviceKey(),
    Authorization: `Bearer ${serviceKey()}`,
    "Content-Type": "application/json",
  };
}

/**
 * Every object name under `prefix`, recursively.
 *
 * The list endpoint returns one level at a time — an entry with no `id` is a folder — and object
 * names here are `{user_id}/{run_id}/{photo_id}.heic`, so one level is never enough.
 *
 * IT ALSO PAGES. The first version sent `{limit: 1000, offset: 0}` once per level and took what
 * came back, so any folder holding more than 1000 entries was SILENTLY TRUNCATED — and this is the
 * sweep FR-SET-02 relies on to find objects the database has lost track of. A user with more than
 * 1000 runs, or a run with more than 1000 objects, kept the remainder forever. §4.7's own words:
 * "leaving one behind is a privacy failure that passes every database test."
 *
 * Throws rather than returning a short list when the API fails. A caller deleting an account must
 * be able to tell "nothing there" from "could not look", and the previous `return out` on !res.ok
 * made those identical.
 */
export async function listAll(bucket: string, prefix: string): Promise<string[]> {
  const out: string[] = [];
  const PAGE = 1000;

  for (let offset = 0; ; offset += PAGE) {
    const res = await fetch(`${supabaseUrl()}/storage/v1/object/list/${bucket}`, {
      method: "POST",
      headers: headers(),
      body: JSON.stringify({ prefix, limit: PAGE, offset }),
    });
    if (!res.ok) {
      throw new Error(`storage list failed for ${bucket}/${prefix}: ${res.status} ${await res.text()}`);
    }
    const entries = (await res.json()) ?? [];
    for (const e of entries) {
      const name = prefix ? `${prefix}${prefix.endsWith("/") ? "" : "/"}${e.name}` : e.name;
      if (e.id === null || e.id === undefined) {
        out.push(...await listAll(bucket, name));
      } else {
        out.push(name);
      }
    }
    if (entries.length < PAGE) break;
  }
  return out;
}

/**
 * Deletes objects by path. Deleting one that was never written is free; leaving one behind is a
 * privacy failure that passes every database test (§4.7). So callers delete unconditionally.
 *
 * RETURNS THE PATHS IT COULD NOT DELETE, and the caller must not report success while that list is
 * non-empty. The first version logged the failure and carried on returning `void`, so a Storage
 * outage produced `{"deleted": true}` from delete-account — the one response in this system that
 * must never be optimistic. FR-SET-02 is a promise about bytes, not about intent.
 */
export async function removeObjects(bucket: string, paths: string[]): Promise<string[]> {
  const failed: string[] = [];
  if (paths.length === 0) return failed;
  for (let i = 0; i < paths.length; i += 100) {
    const chunk = paths.slice(i, i + 100);
    const res = await fetch(`${supabaseUrl()}/storage/v1/object/${bucket}`, {
      method: "DELETE",
      headers: headers(),
      body: JSON.stringify({ prefixes: chunk }),
    });
    if (!res.ok) {
      console.error("storage delete failed", bucket, res.status, await res.text());
      failed.push(...chunk);
    }
  }
  return failed;
}

export async function copyObject(bucket: string, from: string, to: string): Promise<boolean> {
  const res = await fetch(`${supabaseUrl()}/storage/v1/object/copy`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({ bucketId: bucket, sourceKey: from, destinationKey: to }),
  });
  return res.ok;
}
