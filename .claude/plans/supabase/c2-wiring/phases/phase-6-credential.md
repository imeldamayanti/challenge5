# Phase 6 — Credential

**Size:** 2 days · **Depends on:** phase 1
**Demo sentence:** "I walked three quests without an account. Then I signed in with Apple, and all three were already there."

**Status:** `NOT STARTED` · **Started:** — · **Completed:** —

<!-- MAINTAIN THIS FILE. See phase 0's header for the rules. -->

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

- [ ] Apple: enable "Sign in with Apple" on the App ID, create the key, note the
      Services ID and Team ID.
- [ ] Google: create an OAuth client. **`config.toml` has no `[auth.external.google]`
      stanza at all** — it has to be added.
- [ ] `[auth.external.apple]` is `enabled = false` with an empty `client_id` today.
- [ ] Secrets via `env(SUPABASE_AUTH_EXTERNAL_APPLE_SECRET)` and never in the repo.
      **This project has already had one production key exposure and rotation.**
- [ ] `site_url = "kultara://auth-callback"` is already set; the URL scheme has to
      exist in the app, and it names a working title that may not survive B2.
- [ ] `config push` applies auth settings. It does **not** apply a function's
      `verify_jwt` — verify with `supabase functions list`, not by assuming.

### The screens

- [ ] Sign in with Apple, Sign in with Google. Both native buttons, meeting Apple's own
      placement rules — App Review rejects an app that offers Google above Apple.
- [ ] Reached from Profile → account, and offered **once**, non-modally, after a walk
      completes. Never on launch, never blocking (`FR-OFF-01`).
- [ ] A "not now" that is as easy to press as the buttons, and that does not ask again
      for a long time.
- [ ] Sign out, and copy that says plainly what happens to local data when they do.

### Linking

- [ ] Call `merge-anonymous` (`verify_jwt = true` — the anonymous session's own JWT is
      what authorizes it).
- [ ] `enable_manual_linking` stays `false`. Merging goes through the function.
- [ ] Signing in to an account that **already has data** on a device that also has
      anonymous data is the hard case. Decide the rule, write it here, and make the
      screen say it before the user commits.
- [ ] `app.profiles` gets a row at this point — display name, avatar, preferred
      language. It is **not syncable** and has no `server_seq`; do not put it in the
      push order.

### Deletion

- [ ] `delete-account` already exists and is deployed. Settings must call it for a
      credentialed user, and the copy must distinguish "sign out" from "delete
      everything".

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
