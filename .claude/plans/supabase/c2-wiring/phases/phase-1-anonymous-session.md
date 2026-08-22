# Phase 1 — Anonymous Session

**Size:** 1 day · **Depends on:** nothing
**Demo sentence:** "The app has an account. Nobody was asked to make one, and nothing on screen changed."

**Status:** `COMPLETE` · **Started:** 2026-08-21 · **Completed:** 2026-08-21

<!-- MAINTAIN THIS FILE. See phase 0's header for the rules. -->

## Goal

Obtain and keep an anonymous Supabase session, invisibly, so that phases 3–5 have a
`user_id` to write under.

**No screen. No prompt. No button.** The owner's constraint is that login, register
and OAuth screens come last, and this phase adds none of them.

## Why this is not the auth feature being deferred

"Auth" covers two different things and only one of them is a feature:

| | What it is | When |
|---|---|---|
| Session | an `auth.users` row and a JWT, obtained anonymously | here |
| Credential | Apple / Google, the linking screen, `merge-anonymous` | phase 6 |

Every `app.*` table declares `user_id uuid not null references auth.users(id)` and
every policy reads `user_id = (select auth.uid())`. Without a session there is no row
that can be inserted and no policy that can pass — deferring it does not delay phases
3–5, it deletes them.

The design already assumed this. `config.toml` sets `enable_anonymous_sign_ins =
true` with the comment: every user has an `auth.users` row from first launch, and
nothing in the walk is gated on a credential or a radio (`AD-3`, `FR-OFF-01`,
`FR-START-08`).

And `merge-anonymous` only works if the anonymous session existed **first**. Introduce
the session together with the login screen in phase 6 and there is nothing to merge.

## Scope

### Decide the transport, and write it down here

- [x] **Decided 2026-08-21 by the owner: `supabase-swift`.** Wired ahead of the rest of
      this phase, so the decision is in the repo rather than in a note.
      `01-architecture.md` §5 carries the reasoning and the four wiring decisions;
      the short version is below.

## Decision — the SDK

`supabase-swift` **2.55.1**, pinned `upToNextMinor`, linked to the **app target only**.
It buys token refresh, storage upload and PostgREST building — the three things C2
would otherwise write by hand and get wrong.

- **Four products, not the umbrella**: `Auth`, `PostgREST`, `Storage`, `Functions`.
  **`Realtime` is deliberately not linked** — it holds a WebSocket open, which is a
  battery cost on a walking app for a feature C2 does not have, and a client keeping a
  socket up is one step from behaving like the reachability check `AD-3` bans. The
  umbrella would pull it in along with CryptoSwift and swift-secp256k1.
- **Six transitive packages** arrive with it: swift-crypto, swift-asn1,
  swift-http-types, swift-concurrency-extras, swift-clocks, xctest-dynamic-overlay.
  That is the price, stated rather than absorbed.
- **`Package.resolved` is now tracked** (a narrow `.gitignore` negation). Untracked, a
  third-party graph resolves differently on every machine and in CI.
- **The package targets stay clean.** `ContentKit`, `RunEngine` and `DesignSystem` gain
  nothing; `ImportBoundaryTests` and the two-second macOS `swift test` are unaffected.

### Where credentials live, now that there are two kinds

- **App**: project URL and the **publishable** key, in `challange-5/Config/Backend.xcconfig`,
  written into the bundle as `Backend.plist` by a build phase and read by
  `BackendConfiguration`. Public by design; RLS is what protects the data.
- **Operator**: `.env.local` at the repository root — gitignored, and already the home
  `.gitignore` names for exactly this. `.env.example` is the checked-in template, and
  `supabase/scripts/publish-suppressions.sh` reads it without ever echoing the key.
  **Not a plist, and not in the app**: the service-role key bypasses RLS entirely, and
  `docs/backend-supabase.md` §8 puts it in two places only — an Edge Function's
  environment and CI secrets.

### The service

- [x] `SupabaseSession` in `challange-5/Services/`, beside `LocationService` — a
      platform edge, following the placement rule. An `actor`, so the session-minting
      race is closed by isolation rather than by a lock.
- [x] Sign in anonymously when there is no stored session. **`AuthClient`, not
      `SupabaseClient`** — the umbrella pulls `Realtime`, which is the thing
      `01-architecture.md` §5 linked four products to avoid.
- [x] Persist the session and reuse it. A relaunch must **not** create a second user.
      Observed on prod: the app minted `e2ba2362-83bf-4711-8914-71ef8c70c9b5` at
      02:05:07 UTC and every later launch reused it — `auth.users` still holds exactly
      one row from this app.
- [x] Refresh before expiry (`jwt_expiry = 3600`). Two mechanisms, deliberately:
      the SDK's `autoRefreshToken` ticks while the app is foregrounded, and
      `accessToken()` refreshes anything inside a 60-second margin before handing it
      out — a token that is valid when checked can still expire in flight.
      **A refresh that fails returns the old token rather than nil**: it may still be
      good, and a caller getting a stale token gets a 401 it can survive, where nil is
      a push that never happens.
      [~] **On a 401** — SKIPPED here and belongs to phase 3: nothing calls an
      authenticated endpoint yet, so there is no 401 to react to and no way to test one.
- [x] Expose the access token to phases 3–5 and nothing else. `SupabaseSessionProviding`
      has three members — token, user id, sign out — and no view model sees it.
- [x] Wired into `KultaraEnvironment` as `any SupabaseSessionProviding`. With no backend
      configured the default is `UnconfiguredSupabaseSession` rather than a
      `SupabaseSession` holding a nil client — the two behave identically, and this way a
      test that forgets to pass one cannot accidentally reach the network.

### The rules it must not break

- [x] Launch never waits on it. `prepare()` returns before the network is touched; the
      root view's `.task` calls it and moves on.
- [x] No reachability check (`AD-3`). `noModuleChecksReachability` green.
- [x] No error surface. Every failure path is `try?`, and the app behaves exactly as it
      did before there was a backend.
- [x] `enable_manual_linking` stays `false`. Untouched.

### Storage of the session

- [x] Refresh token in the Keychain, not `UserDefaults`.
      `AuthClient.Configuration.defaultLocalStorage` is `KeychainLocalStorage` on Apple
      platforms; it is **named rather than defaulted** so a change to the SDK's default
      cannot quietly move a bearer credential into a plist.
- [x] Cleared by `DataEraser` (`FR-SET-02`). Local scope only: revoking server-side
      would make a Settings action that must work offline depend on the network.

### Device identity

- [x] `device_id` UUID generated once per installation, on `AppPreferencesStore` and
      **read-only from outside** — minted on first access, so there is exactly one way
      for the value to exist. `removeAll()` takes it with it, so a walker who erases
      stops being the same device to the server as well as to this phone.

## Exit criteria

- [x] Cold install produces a session; the project shows one new anonymous user
      (`e2ba2362…`, 2026-08-21 02:05:07 UTC).
- [x] Relaunch produces **no** second user. `auth.users` holds one row from this app
      across five launches.
- [x] Airplane-mode behaviour is unchanged. Phase 0 already proved the shape with an
      unreachable host; nothing here waits on the session, and the tests cover the
      no-session path directly.
- [~] After 61 minutes of foreground use, a request still succeeds. — SKIPPED: there
      is no authenticated request to make until phase 3, so this cannot be observed yet.
      The trace shows the SDK's refresh timer armed and counting
      (`access token expires in 105 ticks, a tick lasts 30.0s`). **Re-check in phase 3**,
      where a real push after an hour is the actual test.
- [x] Settings → erase clears the session, guarded by `SupabaseSessionTests`. The
      "next launch makes a new user" half is [~] **not observed on a device** — see the
      Keychain note below, which is why it cannot be checked by reinstalling.
- [x] `noModuleChecksReachability` green.

## Out of scope

Any UI. Sign in with Apple, Google, email, password. `merge-anonymous`. A profile row
— `app.profiles` is not syncable and nothing in C2 needs it until phase 6 gives the
user a display name.

## Two things this phase learned the hard way

- **The simulator's unified log is unusable for this app.** Every message from the
  process renders as `<compose failure>`, and `simctl launch --console` drops nearly
  everything. An hour went into "the session is not being created" when it had been
  created on the first launch. The answer was a file:
  `ConsoleSupabaseLogger` (debug only, 2 MB cap) writes the SDK's own diagnostics to
  `Library/Application Support/supabase-trace.log`, and that file is what proved both
  that sign-in worked and that a relaunch reuses the stored session. **Read it before
  reaching for the log.**
- **The simulator Keychain survives `simctl uninstall`.** So "delete the app and launch
  again" is *not* a cold install as far as the session is concerned — the stored session
  comes straight back and no new user is created. Anything that needs a genuinely fresh
  identity has to erase from Settings, or use a different simulator. This matters most
  in phase 7, whose whole premise is a device with nothing on it.

## Risk notes

- **This is the phase after which prod holds real user data.** `b3` §1.1's "prod is
  not precious until the first real user signs in" ends here, silently, with no
  announcement. Every later `db reset` on prod becomes destructive. Say so out loud
  when this ships to any build that reaches people.
- **Anonymous sign-in is rate limited to 30 per hour per IP.** A test rig that
  reinstalls in a loop will hit it and the failure will look like a bug in the client.
- **A session per install means a reinstall orphans the previous user's data.** That
  is correct and intended until phases 6 and 7 — but it means "I lost my walks when I
  reinstalled" is a true report with no fix before both of them ship, and
  support-facing copy must not promise otherwise until then. Phase 6 gives the walks
  somewhere to belong; **phase 7 is what brings them back**, and neither alone is
  enough.
