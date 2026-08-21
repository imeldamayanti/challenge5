# Phase 5 — Share Card

**Size:** 3 days · **Depends on:** phases 1, 4
**Demo sentence:** "I sent someone who does not have the app a link to my finished walk. Then I revoked it, and the same link stopped working."

**Status:** `DEPLOYED` — live on prod, at the owner's explicit instruction over the consent caveat · **Started:** 2026-08-21 · **Completed:** 2026-08-21

<!-- MAINTAIN THIS FILE. See phase 0's header for the rules. -->

## Deployed 2026-08-21, at the owner's explicit instruction

**The consent question was still unanswered when this was switched on.** Asked
directly — "share cards would publish a walk through 5 real Bali sites whose consent
is a self-grant nobody has asked them to sign; deploy anyway?" — the owner chose
"Yes, deploy it now." That is recorded here rather than treated as resolved: the
consent position in `docs/consent-log.md` has **not changed**, and this decision does
not change it either. It is the owner's product call to make, and they made it
knowingly.

What actually happened, in order:

1. `supabase config push --project-ref ppwcxmvetmmwliusliac` — no-op for the function
   itself (`config push` doesn't carry function `verify_jwt`, only `functions deploy`
   does).
2. `supabase functions deploy share --project-ref ppwcxmvetmmwliusliac` — live,
   `verify_jwt: false`, confirmed via `functions list`.
3. Smoke-tested against prod before touching the client: an unknown slug and a
   malformed slug both `404`, a `POST` is `405` — the same shape `share.test.ts`
   asserts locally.
4. `SupabaseShareCardMinting.isAvailable` flipped to `true`. `NoShareCardMinting`
   (the no-backend case) stays `false` — that one is not the consent switch, it is
   "there is nothing to mint against."
5. `ShareCardTests` rewritten for the new reality: the no-backend case is still off,
   a configured backend is now available, and a third test proves "available" does
   not mean "unconditional" — minting still needs a real session.

**What is still not built**, unchanged from before: the `ShareLink` URL replacement
and the revoke control. `mint()` can now return a real URL, but nothing in the Trip
pages calls it yet — they still hand over plain text. Building that is a further
step, not part of this one; ask if it should happen next.

## Why it was blocked before it was started

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

- [x] `supabase/functions/share/index.ts`, `verify_jwt = false`. **Written and not
      deployed** — `functions list` shows the same four as before.
- [x] Looks up the slug, checks `revoked_at`, `expires_at` **and `deleted_at`** per
      request, then
      streams the object or 404s.
- [x] **Never returns a signed URL at all.** It signs one internally for 60 seconds and
      streams the bytes, so no credential outlives the revocation. `Cache-Control:
      no-store` for the same reason: a CDN holding a revoked card for five minutes is five
      minutes of a link the walker believes is off.
- [x] One response shape for **every** refusal — unknown, revoked, expired, deleted — so
      a stranger cannot tell them apart. Slugs are matched against a fixed shape before
      anything is looked up, so a malformed path never reaches PostgREST as a filter value.
      The original note said an error message that
      distinguishes "revoked" from "never existed" is an enumeration oracle.
- [x] **No migration was needed.** The function holds the service role from its own
      environment and reads one row by an opaque slug; a `security definer` accessor would
      have been a second way to do what it can already do. Nothing was added
      shape as `c1`'s 0014. **Additive only** — a non-additive migration here is a
      stop-and-ask.
- [~] `config.toml` has the `[functions.share] verify_jwt = false` entry **locally and
      unpushed**, with a comment saying why. Verifying it with `functions list` is part of
      the deploy that has not happened. The original note:
      `supabase functions list` — `config push` does **not** apply it, `functions
      deploy` does.

### Client — minting

- [x] `ShareCardArtwork` renders `FR-DONE-06` at a fixed 1080 × 1350 canvas — a card is
      an image with one job, and letting it reflow with Dynamic Type would make every
      walker's card a different picture. The palette is passed in rather than read from
      the environment, because `ImageRenderer` draws outside the view tree. Previously
      `ShareLink` hands over plain text today, deliberately, so the screen does not
      promise a card it cannot produce.
- [x] Uploads to `share-cards` under `{user_id}/…`, same prefix rule as photos. **Bytes
      before the row**, which is the opposite of `app.photos` and deliberate: a photograph
      with no bytes is an orphan the sweeper finds, but a share row with no bytes is a live
      link serving nothing to whoever the walker just sent it to.
- [x] Mints a 32-character slug over a 64-symbol alphabet — 192 bits — and writes the
      row. A slug is the only thing between a stranger and a walker's card, so it is length
      rather than prettiness.
- [~] Replace the `ShareLink`'s `item` with the URL. — Not done, because there is no URL
      to put there while `isAvailable` is `false`; the Trip pages keep handing over plain
      text exactly as before. This is the one line to change when sharing is switched on.
      **The bar does not otherwise
      change** — that was the plan when the plain-text version shipped.

### Client — revoking

- [~] A way to revoke from the app. `revoke(runID:)` exists and sets `revoked_at` rather
      than deleting — so the record that a card was shared survives, which is a thing a
      walker might want to see. **No control renders it yet**, because there is nothing to
      revoke. Build the control in the same pass that turns sharing on; a revocation
      control
      nobody can reach is the same as no revocation.
- [x] Revoking sets `revoked_at`; the serve function stops serving on the next
      request.

### Content of the card

- [x] Rendered from the **Run's own snapshots** (`AD-4`, `FR-RUN-06`), and
      `ShareCardBoundaryTests` scans the file to prove it reaches for no repository. Never
      from live
      content. A walk shared after a place is withdrawn still renders what the walker
      saw.
- [x] Carries no coordinates, no accuracy, no timestamps finer than the day — scanned
      for, not reviewed. A time of day plus a named place is a statement about where a
      person was and when, to the minute, forwarded to strangers.
- [x] Carries the walker's own written answers only if they opt in per share —
      `reflections` is empty unless the caller fills it. Consent to share once is not
      consent to share always. They
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
