# C2 — Progress Tracker

**Single source of truth for what is done.** Check here before starting any work.

Last updated: **20 Aug 2026** · Updated by: **planning session**

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
| 0 | [Governance & Telemetry](phases/phase-0-governance-telemetry.md) | — | 1–2 d | `NOT STARTED` | — | — |
| 1 | [Anonymous Session](phases/phase-1-anonymous-session.md) | — | 1 d | `NOT STARTED` | — | — |
| 2 | [Sync Identity](phases/phase-2-sync-identity.md) | — | 2 d | `NOT STARTED` | — | — |
| 3 | [Push Sync](phases/phase-3-push-sync.md) | 1, 2 | 3 d | `NOT STARTED` | — | — |
| 4 | [Photo Upload](phases/phase-4-photo-upload.md) | 1, 3 | 2 d | `NOT STARTED` | — | — |
| 5 | [Share Card](phases/phase-5-share-card.md) | 1, 4 | 3 d | `BLOCKED` | — | — |
| 6 | [Credential](phases/phase-6-credential.md) | 1 | 2 d | `NOT STARTED` | — | — |

Phase 5 is `BLOCKED` before it is started, on purpose: the consent position in
`03-security-privacy.md` §4 has to change before a share card can be shown to anyone
outside the team. The engineering in it is not blocked; publishing is.

## What exists today

Verified 2026-08-20 against the running project, not read from a document.

- [x] Hosted project `ppwcxmvetmmwliusliac`, 18 migrations applied, matching the repo
      file-for-file.
- [x] 4 Edge Functions ACTIVE at version 4, `verify_jwt` matching `config.toml`.
- [x] Kill-switch document live and world-readable, schema 2, three empty arrays.
- [x] `GovernanceKit` and `TelemetryKit` written and unit-tested.
- [x] `RunEngine.UUIDv7` — row ids are already correct as generated.
- [ ] Either kit linked to the app target. **They are not** — no reference in
      `project.pbxproj`.
- [ ] Any network call from the app. **There is none** — no `URLSession`, no SDK, no
      remote URL in the app target.

## Blockers

| # | Blocker | Blocks | Owner |
|---|---|---|---|
| B1 | Consent for the five shipped places is a self-grant with placeholder signatories; none of the sites has been approached | phase 5 publish, any public build | unassigned |
| B2 | The app has no name — blocks all five consent approaches equally | B1 | unassigned |
| B3 | The History page carries nine uncited paragraphs and a portrait with no provenance (`FR-CP-05`, `FR-CP-06`) | phase 5 publish | af (decision taken 2026-08-20, remediation unassigned) |
| B4 | `FR-MAP-01`'s discovery-basemap amendment is drafted and unsigned; `FR-CP-05`'s Story Reveal exception is undocumented in the PRD | release, not wiring | unassigned |
| B5 | Apple Developer "Sign in with Apple" key and a Google OAuth client do not exist; `config.toml` has no Google stanza at all | phase 6 | unassigned |
| B6 | `xcode-select` points at CommandLineTools — every build and test command needs a `DEVELOPER_DIR` prefix. The permanent fix needs the user's password | all phases | af |

## Session log

Append one line per working session. Newest last.

- **2026-08-20** — planning session. Audited what is wired (nothing), verified the
  deployed project over MCP and HTTP, wrote this folder. No code changed.
