# Phase 6 — Credential

**Size:** 2 days · **Depends on:** phase 1
**Demo sentence:** "I walked three quests without an account. Then I signed in with Apple, and all three were already there."

**Status:** `IN PROGRESS` — client done, **provider setup is the owner's** · **Started:** 2026-08-21 · **Completed:** —

<!-- MAINTAIN THIS FILE. See phase 0's header for the rules. -->

> **In the MVP as of 2026-08-21, and no longer optional.** The owner's goal for user
> data is "your walks survive a reinstall", and an anonymous session orphans data on
> reinstall — so this phase is what gives a walk somewhere to belong. It still does not
> bring anything back: that is [phase 7](phase-7-restore.md), which depends on this one.
> Shipping this without phase 7 leaves a user signed in, looking at an empty Journal,
> with their walks sitting in a database they cannot reach.

## Goal

Let a walker claim the account their walks have been filed under since phase 1.

**This is the phase the owner asked to be last, and it is last.** It is also the only
phase in C2 that adds a screen.

## Why it works at all

Because phase 1 already created the anonymous user. `merge-anonymous` attaches a real
identity to **existing** data. If the session and the login screen had arrived
together, there would be nothing to merge and every walk before sign-in would be
orphaned.

## Scope

### Provider setup — none of this is Swift

- [~] Apple: enable "Sign in with Apple" on the App ID, create the key, note the
      Services ID and Team ID.
- [~] Google: create an OAuth client. **`config.toml` has no `[auth.external.google]`
      stanza at all** — it has to be added.
- [~] `[auth.external.apple]` is **still** `enabled = false` with an empty `client_id`.
- [~] Secrets via `env(SUPABASE_AUTH_EXTERNAL_APPLE_SECRET)` and never in the repo — the
      line is already in `config.toml` and the variable is unset.
      **This project has already had one production key exposure and rotation.**
- [~] `site_url = "kultara://auth-callback"` is already set; the URL scheme has to
      exist in the app, and it names a working title that may not survive B2.
- [~] `config push` applies auth settings. It does **not** apply a function's
      `verify_jwt` — verify with `supabase functions list`, not by assuming.

### The screens

- [x] **Sign in with Apple**, `SignInWithAppleButton` at Apple's own sizing — a
      hand-drawn one is a guideline violation before it is a design decision.
      **Google is deliberately not built**: `config.toml` has no `[auth.external.google]`
      block and no OAuth client exists, so adding it would be two things blocked instead
      of one. Written here rather than left looking forgotten. The original line asked for
      both native buttons, meeting Apple's own
      placement rules — App Review rejects an app that offers Google above Apple.
- [x] **At the flow chart's login position**, which is where the wireframe already
      stood — splash → onboarding → this → Home. Not a gate: "Not now" is the same weight
      as the button beside it, and the copy says outright that everything works without
      signing in.
      [~] "Offered once, after a walk, from Profile → account" — SKIPPED. The launch
      position is what the flow chart draws and what the wireframe occupied, so building
      there replaced a drawing rather than inventing a placement. Moving it behind a walk
      is a product decision with an owner, not an implementation detail.
      completes. Never on launch, never blocking (`FR-OFF-01`).
- [x] A "Not now" as easy to press as the button, and it does not ask again in the
      session. A cancelled Apple sheet is **not** reported as a failure — the walker chose
      to stop, which is what "Not now" does.
      for a long time.
- [~] Sign out, with copy about local data. — SKIPPED: `CredentialLinking.signOut()`
      exists and is local-scope, but there is no Settings row for it yet. A sign-out
      control for an account nobody can create is premature; build it in the same pass
      that enables the provider. Settings → erase everything already signs out.

### Linking

- [x] Calls `merge-anonymous` (`verify_jwt = true`). Two details are load-bearing:
      the anonymous token is **captured before** the sign-in, because signing in replaces
      the session and that token is what tells the function which rows to move; and
      `anon_queue_empty` is answered from `AppTelemetry.queueIsEmpty` rather than
      hard-coded, because claiming an empty queue that is not empty moves rows out from
      under one that is about to add more. The original note said the anonymous JWT is
      what authorizes it).
- [x] `enable_manual_linking` stays `false`. Untouched.
- [~] Signing in to an account that **already has data** on a device that also has
      anonymous data is the hard case. Decide the rule, write it here, and make the
      screen say it before the user commits.
- [~] `app.profiles` gets a row at this point — display name, avatar, preferred
      language. It is **not syncable** and has no `server_seq`; do not put it in the
      push order.

### Deletion

- [ ] `delete-account` already exists and is deployed. Settings must call it for a
      credentialed user, and the copy must distinguish "sign out" from "delete
      everything".

## What is done, and what is blocked

**The client is built and the provider is not.** Everything in Swift is there:
`SupabaseCredentialLinking`, the nonce, `CredentialView` with Apple's own button, the
`merge-anonymous` call, and honest copy for all three outcomes. It has been seen on
iPhone 17 / iOS 26.5 — `docs/screenshots/c2p6-credential-screen.png`.

**Tapping the button cannot work yet**, and that is not a defect in the code:
`[auth.external.apple]` is `enabled = false` with an empty `client_id`, so Supabase
rejects the identity token. Enabling it needs an Apple Developer team, a Sign in with
Apple key, and a `config push` — none of which this session can do or should fake.

What the owner has to do, in order:

1. Enable **Sign in with Apple** on the App ID for `com.umar.hisplora`, create the key,
   and note the Services ID, Team ID and Key ID.
2. Set `[auth.external.apple] enabled = true` and `client_id` in `config.toml`; export
   `SUPABASE_AUTH_EXTERNAL_APPLE_SECRET`; `supabase config push`.
3. Add the **Sign in with Apple** capability to the app target in Xcode.
4. Then, in one pass: sign in on a device, watch `merge-anonymous` move the rows, and
   close the two exit criteria phases 3 and 7 both deferred — erase-all removing the
   server copy, and a second credential restoring only its own walks.

**Three things about the code are worth reading before that pass**, because each is a
mistake that fails with a message pointing somewhere else:

- **The nonce is sent twice, in two forms.** Apple signs the **SHA-256** of it into the
  identity token and Supabase compares the **raw** value against that hash. Sending the
  same string to both fails with "invalid token" and says nothing about nonces.
- **The credential signs into the app's existing `AuthClient`**, handed over from
  `SupabaseSession`. A second client would have its own Keychain storage and the walker
  would end up signed in on one of them.
- **The anonymous token is captured before the sign-in.** After it, the session is the
  new identity's and the thing `merge-anonymous` needs is gone.

## Exit criteria

- [ ] Walk anonymously, sign in with Apple, the walk is there under the same
      `user_id`.
- [ ] Same with Google.
- [ ] Sign in on a second device with the same Apple ID, and the first device's walks
      are visible — **or** the plan says explicitly that they are not, because pull
      sync is out of scope for C2. Decide before building, not after a bug report.
- [ ] Two different anonymous users linking two different credentials do not merge
      into each other.
- [ ] "Not now" leaves everything working, forever.
- [ ] Delete account removes the rows, the objects, and the local data; a second
      token's view confirms it.
- [ ] Launching offline after signing in still reaches the quest list.

## Out of scope

Email and password sign-up — the password rules in `config.toml`
(`minimum_password_length = 8`, `lower_upper_letters_digits`) exist because the
setting had to have a value, not because a password screen is planned. Passkeys.
Account recovery flows. Profile editing beyond a display name.

## Risk notes

- **Pull sync is not in C2**, so "sign in on a second device and see my walks" does
  **not** work when this ships. That is the single most likely thing a user will
  expect from a login screen. Either scope pull in, or make the screen's copy honest
  about what signing in does — which is: keeps your walks if you lose this phone,
  eventually.
- **Sign in with Apple has App Review rules with teeth.** If any third-party sign-in is
  offered, Apple's must be offered too and given equal prominence. Google-only is a
  rejection.
- **The URL scheme `kultara://` names a working title.** "Kultara" is a real community
  storyteller organization in Sanur — a research partner, not a brand (B2). A scheme
  is hard to change after release.
- **Linking is the one irreversible user-facing operation in C2.** A merge that goes
  the wrong way loses walks. The screen has to say what will happen before it happens,
  and the function has to be idempotent under a retry from a flaky network.
