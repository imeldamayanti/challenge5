# Phase 1 — Anonymous Session

**Size:** 1 day · **Depends on:** nothing
**Demo sentence:** "The app has an account. Nobody was asked to make one, and nothing on screen changed."

**Status:** `NOT STARTED` · **Started:** — · **Completed:** —

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

- [ ] `SupabaseSession` in `challange-5/Services/`, beside `LocationService` — a
      platform edge, following the placement rule.
- [ ] Sign in anonymously when there is no stored session.
- [ ] Persist the session and reuse it. A relaunch must **not** create a second user.
- [ ] Refresh before expiry (`jwt_expiry = 3600`) and on a 401.
- [ ] Expose the access token to phases 3–5 and nothing else. No view model sees this
      type.
- [ ] Wire into `KultaraEnvironment` as `any SupabaseSessionProviding` with a default,
      matching how every other service is composed.

### The rules it must not break

- [ ] Launch never waits on it. Cold launch in airplane mode reaches the quest list.
- [ ] No reachability check (`AD-3`).
- [ ] No error surface. A session that cannot be obtained is the normal offline case.
- [ ] `enable_manual_linking` stays `false`. Linking goes through `merge-anonymous` in
      phase 6.

### Storage of the session

- [ ] Refresh token in the Keychain, not `UserDefaults`. It is a bearer credential for
      a user's own walking history.
- [ ] Cleared by `DataEraser` — `FR-SET-02` erasure must not leave a live session
      behind.

### Device identity

- [ ] `device_id` UUID generated once per installation and stored in preferences. It
      is phase 2's field but this is the natural place to create it, next to the other
      per-install identity.

## Exit criteria

- [ ] Cold install produces a session; the project shows one new anonymous user.
- [ ] Relaunch produces **no** second user.
- [ ] Airplane-mode cold install reaches the quest list, starts a walk and completes a
      checkpoint with no session at all.
- [ ] After 61 minutes of foreground use, a request still succeeds — refresh works.
- [ ] Settings → erase clears the session and the next launch makes a **new** user.
- [ ] `noModuleChecksReachability` green.

## Out of scope

Any UI. Sign in with Apple, Google, email, password. `merge-anonymous`. A profile row
— `app.profiles` is not syncable and nothing in C2 needs it until phase 6 gives the
user a display name.

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
