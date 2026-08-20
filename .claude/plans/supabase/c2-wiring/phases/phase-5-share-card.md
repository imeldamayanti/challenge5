# Phase 5 — Share Card

**Size:** 3 days · **Depends on:** phases 1, 4
**Demo sentence:** "I sent someone who does not have the app a link to my finished walk. Then I revoked it, and the same link stopped working."

**Status:** `BLOCKED` · **Started:** — · **Completed:** —

<!-- MAINTAIN THIS FILE. See phase 0's header for the rules. -->

## This phase is blocked before it is started

Not on engineering. On [`../03-security-privacy.md`](../03-security-privacy.md) §4:

- **B1** — consent for the five shipped places is a self-grant with placeholder
  signatories, and none of the five sites has been approached.
- **B2** — the app has no name, which blocks all five approaches equally.
- **B3** — the History page carries nine uncited paragraphs and a portrait with no
  provenance (`FR-CP-05`, `FR-CP-06`).

A share card is the first artefact this project produces that is **seen by someone who
never agreed to anything**. Everything above is survivable inside a non-public academic
prototype and none of it is survivable on a public link.

Build the engineering if it is useful. Do not mint a public slug until B1–B3 move.

## Goal

A finished walk can be shown to a stranger, and un-shown.

## Why this is last of the data phases

It needs photographs (phase 4), it needs the walk on the server (phase 3), it needs a
session (phase 1), and it is the only phase with **server work left in it**.

## The problem the schema left open

`app.share_cards` has `public_slug`, `expires_at` and `revoked_at`. The `share-cards`
bucket is **private**, `for select to authenticated`. A public link therefore cannot
read it as shipped.

And migration 0012 records the deeper half:

> §14 defect 14 is OPEN: a signed URL already in someone's hands ignores this column
> until it expires. Either serve share cards through a function that checks it per
> request, or keep signed-URL lifetimes to minutes.

A column that looks like a control and is not one is worse than no column.

## Scope

### Server — the serve function

- [ ] A fifth Edge Function: `GET /functions/v1/share/{slug}`, `verify_jwt = false`.
- [ ] Looks up the slug, checks `revoked_at` and `expires_at` **per request**, then
      streams the object or 404s.
- [ ] Never returns a long-lived signed URL to the caller. That is the defect.
- [ ] A slug that was never minted 404s rather than erroring — an error message that
      distinguishes "revoked" from "never existed" is an enumeration oracle.
- [ ] One additive migration if a `security definer` accessor is needed, in the same
      shape as `c1`'s 0014. **Additive only** — a non-additive migration here is a
      stop-and-ask.
- [ ] `config.toml` updated with the new function's `verify_jwt`, and verified with
      `supabase functions list` — `config push` does **not** apply it, `functions
      deploy` does.

### Client — minting

- [ ] Render the recap card (`FR-DONE-06`). **It does not exist**; the Trip Summary's
      `ShareLink` hands over plain text today, deliberately, so the screen does not
      promise a card it cannot produce.
- [ ] Upload to `share-cards` under `{user_id}/…`, same prefix rule as photos.
- [ ] Mint a slug, write the `app.share_cards` row.
- [ ] Replace the `ShareLink`'s `item` with the URL. **The bar does not otherwise
      change** — that was the plan when the plain-text version shipped.

### Client — revoking

- [ ] A way to revoke from the app, and it has to be findable. A revocation control
      nobody can reach is the same as no revocation.
- [ ] Revoking sets `revoked_at`; the serve function stops serving on the next
      request.

### Content of the card

- [ ] Rendered from the **Run's own snapshots** (`AD-4`, `FR-RUN-06`), never from live
      content. A walk shared after a place is withdrawn still renders what the walker
      saw.
- [ ] Carries no coordinates, no accuracy, no timestamps finer than the day.
- [ ] Carries the walker's own written answers only if they opt in per share. They
      wrote those for themselves.

## Exit criteria

- [ ] A **signed-out** client, in a browser with no app installed, opens a minted link
      and sees the card.
- [ ] After revocation, the same link fails on the next request — not after a cache
      expiry.
- [ ] After `expires_at`, the same link fails.
- [ ] A never-minted slug 404s, indistinguishably from a revoked one.
- [ ] A second user cannot mint a slug for someone else's run.
- [ ] The card renders from snapshots with live content suppressed.
- [ ] **B1, B2 and B3 are resolved, or the slug-minting path is behind a flag that is
      off.** This box is the phase's real gate.

## Out of scope

Journal sharing, the template-preview branch of the flow chart, and every other
wireframe screen. Social-network integrations. Analytics on who opened a card — that
would put a viewer's behaviour in `ops.events`, which has no `user_id` and must not
grow one.

## Risk notes

- **The frames draw a share glyph the app cannot honour.** That is why the plain-text
  `ShareLink` shipped. Do not restore the glyph before the card exists.
- **A public URL is permanent in practice.** It may be cached, indexed, screenshotted
  and forwarded. Revocation stops future fetches; it does not un-send anything. Copy
  in the app should not imply otherwise.
- **The card names real heritage sites.** That is the whole of B1. A card is not a
  screenshot of a private app — it is the project making a public claim about a place
  it has not asked.
- **`revoked_at` will look like it works before the function exists.** A signed URL
  with a short lifetime *appears* to honour revocation, because it expires anyway.
  Test revocation inside the lifetime window or the test proves nothing.
