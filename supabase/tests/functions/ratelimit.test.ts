// 0016 — the rate limiter's own state, tested as a unit.
//
// These are pure-function tests against module state, not HTTP tests: the defect they pin is
// invisible over HTTP because it is about what the worker RETAINS between requests, and a passing
// 429 tells you nothing about how many megabytes it took to produce.

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  _resetForTests,
  _trackedKeyCount,
  clientIp,
  rateLimitConfig,
  rateLimited,
} from "../../functions/_shared/ratelimit.ts";

Deno.test("r1 a single client is limited after the window's allowance", () => {
  _resetForTests();
  const now = 1_000_000;
  for (let i = 0; i < rateLimitConfig.MAX_PER_WINDOW; i++) {
    assertEquals(rateLimited("1.2.3.4", now), false, `refused at request ${i + 1}`);
  }
  assertEquals(rateLimited("1.2.3.4", now), true);
});

Deno.test("r2 the allowance resets in the next window", () => {
  _resetForTests();
  const now = 2_000_000;
  for (let i = 0; i <= rateLimitConfig.MAX_PER_WINDOW; i++) rateLimited("5.6.7.8", now);
  assertEquals(rateLimited("5.6.7.8", now), true);
  assertEquals(rateLimited("5.6.7.8", now + rateLimitConfig.WINDOW_MS + 1), false);
});

Deno.test("r3 THE DEFECT: expired entries are released instead of retained forever", () => {
  // `clientIp` reads x-forwarded-for, so the key space belongs to the caller. Before 0016 an ip
  // that never came back was never expired — entries were only dropped lazily when the SAME ip
  // returned — so one client spraying unique values grew the map without bound on the only
  // unauthenticated endpoint in the system. The worker grew until it was killed.
  _resetForTests();
  const t0 = 3_000_000;
  for (let i = 0; i < 5_000; i++) rateLimited(`10.0.${(i / 256) | 0}.${i % 256}`, t0);
  assertEquals(_trackedKeyCount(), 5_000);

  // A later window, with enough distinct keys to reach the ceiling and force a sweep.
  const t1 = t0 + rateLimitConfig.WINDOW_MS + 1;
  for (let i = 0; i < rateLimitConfig.MAX_TRACKED_KEYS; i++) {
    rateLimited(`11.0.${(i / 256) | 0}.${i % 256}`, t1);
  }
  assert(
    _trackedKeyCount() <= rateLimitConfig.MAX_TRACKED_KEYS,
    `map grew past its ceiling: ${_trackedKeyCount()}`,
  );
});

Deno.test("r4 a full window of LIVE keys fails closed rather than growing", () => {
  // Fail closed is the deliberate choice: a dropped telemetry batch costs a row in a chart, an
  // OOM costs the endpoint for everyone.
  _resetForTests();
  const now = 4_000_000;
  for (let i = 0; i < rateLimitConfig.MAX_TRACKED_KEYS; i++) {
    rateLimited(`12.${(i / 65536) | 0}.${((i / 256) | 0) % 256}.${i % 256}`, now);
  }
  assertEquals(_trackedKeyCount(), rateLimitConfig.MAX_TRACKED_KEYS);
  assertEquals(rateLimited("13.13.13.13", now), true, "a new key was admitted past the ceiling");
  assertEquals(_trackedKeyCount(), rateLimitConfig.MAX_TRACKED_KEYS);
});

Deno.test("r5 a missing x-forwarded-for does not key everything under empty string", () => {
  assertEquals(clientIp(new Request("https://x.test")), "unknown");
  assertEquals(
    clientIp(new Request("https://x.test", { headers: { "x-forwarded-for": "9.9.9.9, 1.1.1.1" } })),
    "9.9.9.9",
  );
});
