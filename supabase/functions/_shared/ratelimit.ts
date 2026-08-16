// A fixed-window per-IP counter for `ingest` (design §6.2: "rate-limited by IP").
//
// LIMITATION, STATED RATHER THAN DISCOVERED LATER: this counter lives in the worker's memory, so
// it is per-worker and resets on cold start. That is enough to stop a loop from one client and is
// NOT enough to stop a distributed flood. A real limit is a shared counter — Postgres or Redis —
// and it belongs with the §14 defect 17 decision about what these functions may record about a
// caller's IP at all, because a shared counter keyed on IP is itself IP retention.

const WINDOW_MS = 60_000;
const MAX_PER_WINDOW = 60;

/**
 * A hard ceiling on how many distinct keys the map may hold.
 *
 * WITHOUT THIS THE LIMITER IS A MEMORY-EXHAUSTION VECTOR, which is worse than having no limiter.
 * `clientIp` reads `x-forwarded-for`, an attacker-controlled header, so the KEY SPACE BELONGS TO
 * THE CALLER: one client spraying unique values gets a new map entry per request, on the only
 * unauthenticated endpoint in the system. Entries were only ever expired lazily, when the SAME ip
 * came back — an ip that never returns stayed forever. The worker grew until it was killed.
 *
 * 20 000 entries is a few MB and far above any believable count of real clients inside a 60 s
 * window at this scale.
 */
const MAX_TRACKED_KEYS = 20_000;

const hits = new Map<string, { count: number; resetAt: number }>();

/** Drops every window that has already closed. O(n) but only run when the map is actually full. */
function evictExpired(now: number): void {
  for (const [key, entry] of hits) {
    if (now >= entry.resetAt) hits.delete(key);
  }
}

export function rateLimited(ip: string, now = Date.now()): boolean {
  const entry = hits.get(ip);
  if (!entry || now >= entry.resetAt) {
    if (!entry && hits.size >= MAX_TRACKED_KEYS) {
      evictExpired(now);
      // Still full after eviction means the window genuinely holds that many live keys, which at
      // this scale means a flood. FAIL CLOSED: refuse the new key rather than admit it and grow.
      // A dropped telemetry batch costs a row in a chart; an OOM costs the endpoint.
      if (hits.size >= MAX_TRACKED_KEYS) return true;
    }
    hits.set(ip, { count: 1, resetAt: now + WINDOW_MS });
    return false;
  }
  entry.count += 1;
  return entry.count > MAX_PER_WINDOW;
}

/** Test seam. The map is module state, and a test that cannot clear it tests the previous test. */
export function _resetForTests(): void {
  hits.clear();
}

export function _trackedKeyCount(): number {
  return hits.size;
}

export function clientIp(req: Request): string {
  // x-forwarded-for is the only thing an edge deployment gives us. It is spoofable; see the
  // limitation above.
  return (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || "unknown";
}

export const rateLimitConfig = { WINDOW_MS, MAX_PER_WINDOW, MAX_TRACKED_KEYS };
