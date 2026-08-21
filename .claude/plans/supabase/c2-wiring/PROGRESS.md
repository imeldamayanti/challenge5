# C2 — Progress Tracker

**Single source of truth for what is done.** Check here before starting any work.

Last updated: **21 Aug 2026** · Updated by: **phase 0 session**

> **Read this first, every session.** If a phase below is `COMPLETE`, do not rebuild
> it — read its phase file to see what exists. If it is `IN PROGRESS`, the unticked
> boxes in that phase file are the remaining work.

## Legend

| Marker | Meaning |
|---|---|
| `[ ]` | Not done |
| `[x]` | Done, in the repo, **and verified against the deployed project** |
| `[~]` | Deliberately skipped — the line says why. **Do not re-litigate.** |
| `NOT STARTED` / `IN PROGRESS` / `COMPLETE` / `BLOCKED` | Phase-level status |

A box is ticked only when the thing is real. Not "written in a doc", not "works in a
unit test with a stubbed transport". If it has not run against
`https://ppwcxmvetmmwliusliac.supabase.co`, it stays unticked.

## Phases

| # | Phase | Depends on | Size | Status | Started | Completed |
|---|---|---|---|---|---|---|
| 0 | [Governance & Telemetry](phases/phase-0-governance-telemetry.md) | — | 1–2 d | `COMPLETE` | 2026-08-21 | 2026-08-21 |
| 1 | [Anonymous Session](phases/phase-1-anonymous-session.md) | — | 1 d | `COMPLETE` | 2026-08-21 | 2026-08-21 |
| 2 | [Sync Identity](phases/phase-2-sync-identity.md) | — | none | `COMPLETE` — collapsed, no code | 2026-08-21 | 2026-08-21 |
| 3 | [Push Sync](phases/phase-3-push-sync.md) | 1, 2 | 2 d | `COMPLETE` | 2026-08-21 | 2026-08-21 |
| 4 | [Photo Upload](phases/phase-4-photo-upload.md) | 1, 3 | 2 d | `COMPLETE` | 2026-08-21 | 2026-08-21 |
| 6 | [Credential](phases/phase-6-credential.md) | 1 | 2 d | `NOT STARTED` | — | — |
| 7 | [Restore](phases/phase-7-restore.md) | 1, 3, 4 | 1½ d | `COMPLETE` | 2026-08-21 | 2026-08-21 |
| 5 | [Share Card](phases/phase-5-share-card.md) | 1, 4 | 3 d | `BLOCKED` · post-MVP | — | — |

**The MVP is 1 → 2 → 3 → 4 → 6 → 7, in that order, and phase 5 is not in it.** Set by
the owner on 2026-08-21: the goal for user data is *"your walks survive a reinstall"*,
which needs a credential to survive one and a read to come back. So phase 6 is no
longer "last, and optional forever" — it is load-bearing, and phase 7 exists because
without it the server holds a copy no walker can ever see.

Phase 5 is `BLOCKED` before it is started, on purpose: the consent position in
`03-security-privacy.md` §4 has to change before a share card can be shown to anyone
outside the team. The engineering in it is not blocked; publishing is. It is now also
explicitly outside the MVP, so that block costs nothing.

### What the 2026-08-21 trim removed

The owner asked for MVP only, no speculative machinery. Cut, each with the reason it
was safe to cut written into the phase that used to hold it:

| Cut | Was | Safe because |
|---|---|---|
| `revision` bumped on every local write | phase 2 | Resolves conflicts; there is one writer and restore only runs into an empty store. Column is `default 1` server-side |
| Tombstones | phase 2 | Nothing in the app deletes one walk — `RunStore.delete(id:)` has no caller. The only delete is erase-all, which phase 3 pairs with `delete-account` |
| `GPSAccuracyBucket` in `RunEngine` | phase 2 | `TelemetryKit.AccuracyBand` already is it — same three tokens, shipped, and its rows are on prod |
| "pushed at revision N" marker, resumable partial pushes | phase 3 | One `needsPush` boolean per walk. A walk is ~12 idempotent upserts, so restarting *is* finishing |

Nothing about **storage volume** was cut, because volume was never the problem: a walk
is about 4 KB of rows (`snapshot_lore` is ~870 bytes × five checkpoints). A photograph
is ~500 KB, two derivatives — a hundred times everything else — and the owner chose to
keep photo upload as planned.

## What exists today

Verified 2026-08-20 against the running project, not read from a document.

- [x] Hosted project `ppwcxmvetmmwliusliac`, 18 migrations applied, matching the repo
      file-for-file.
- [x] 4 Edge Functions ACTIVE at version 4, `verify_jwt` matching `config.toml`.
- [x] Kill-switch document live and world-readable, schema 2, three empty arrays.
- [x] `GovernanceKit` and `TelemetryKit` written and unit-tested.
- [x] `RunEngine.UUIDv7` — row ids are already correct as generated.
- [x] Both kits linked to the app target **and** to `challange-5Tests` (phase 0,
      2026-08-21).
- [x] The app makes network calls. `quest_started` and `checkpoint_arrived` from a real
      arrival on iPhone 17 / iOS 26.5 are in `ops.events` on the deployed project, read back
      2026-08-21 00:42 UTC, and the kill-switch document is fetched on launch and on every
      foreground.
- [x] A **non-empty** kill-switch document observed applying, and still applying with the
      backend stopped — on the **local** stack, and then in full **on prod** (2026-08-21).
      `AD-5` is a working control now, not correct code.

## Blockers

| # | Blocker | Blocks | Owner |
|---|---|---|---|
| B1 | Consent for the five shipped places is a self-grant with placeholder signatories; none of the sites has been approached | phase 5 publish, any public build | unassigned |
| B2 | The app has no name — blocks all five consent approaches equally | B1 | unassigned |
| B3 | The History page carries nine uncited paragraphs and a portrait with no provenance (`FR-CP-05`, `FR-CP-06`) | phase 5 publish | af (decision taken 2026-08-20, remediation unassigned) |
| B4 | `FR-MAP-01`'s discovery-basemap amendment is drafted and unsigned; `FR-CP-05`'s Story Reveal exception is undocumented in the PRD | release, not wiring | unassigned |
| B5 | Apple Developer "Sign in with Apple" key and a Google OAuth client do not exist; `config.toml` has no Google stanza at all | phase 6 | unassigned |
| B6 | `xcode-select` points at CommandLineTools — every build and test command needs a `DEVELOPER_DIR` prefix. The permanent fix needs the user's password | all phases | af |
| ~~B7~~ | **Closed 2026-08-21.** The prod drill ran: suppress, publish, quest gone on device, release, quest back, prod left clean. The deployed function accepts the real production service role — the half the local stack could not prove. Two prod-only findings are in phase 0: a published document takes **60–90 s** to reach readers, and the MCP being read-only again means data writes go through `supabase db query --linked` | — | done |

## Session log

Append one line per working session. Newest last.

- **2026-08-20** — planning session. Audited what is wired (nothing), verified the
  deployed project over MCP and HTTP, wrote this folder. No code changed.
- **2026-08-21** — phase 0, most of the way. Linked both kits to the app target and to
  `challange-5Tests`; added `BackendConfiguration`, `GovernanceGate` and `AppTelemetry` under
  `Services/`; wired the kill-switch into the quest list, both map surfaces, the nearby
  sidequest list, the region monitor and an in-progress Run (`placeSuppressed`, which nothing
  set before); wired four catalogue events into the walk; extended `FR-SET-02` erasure to the
  queue. **The app made its first network call**: two events from a real arrival are in
  `ops.events` on `ppwcxmvetmmwliusliac`. Two guards added —
  `TelemetryPayloadBoundaryTests` (proved to fire) and `AppTelemetryTests` (6 tests).
  Package suite unchanged at four pre-existing failures; `challange-5Tests` 219 → 225, green.
  Kill-switch round trip then run in full on the local stack at the owner's instruction:
  suppress → quest gone; backend stopped → still gone; release → back
  (`docs/screenshots/c2p0-killswitch-*.png`). Phase 0 `COMPLETE`.
- **2026-08-21, later** — owner supplied the service-role key and **B7 closed on prod**.
  Suppressed `badung-museum-bali`, published, the quest and its sidequest left the app on a
  foreground, released it, both came back, prod left with zero rows and an empty document.
  The deployed function accepts the real production service role. Two things prod taught
  that local could not: a published document takes **60–90 s** to reach a reader, and the
  Supabase MCP is read-only again so data writes go through `supabase db query --linked`.
  Transport decision also landed: **`supabase-swift` 2.55.1**, app target only, four products
  without `Realtime`, `Package.resolved` now tracked.
