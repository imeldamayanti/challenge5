# C2 — Wiring the deployed backend to the app

`b0`–`b3` built and deployed a Supabase backend. `c1` wrote two client kits for it.
**The app calls neither.** Eighteen migrations, four Edge Functions, 236 green
assertions and a hosted project in `ap-southeast-1` — and an app that would behave
identically if the project were deleted tomorrow.

This folder is the plan that closes that gap.

`docs/backend-supabase.md` is the design of record and outranks every file here
wherever they disagree. `.claude/prds/cultural-heritage-quest.full.prd.md` is the
requirements document and outranks both.

## The loop this work must produce

```
walk happens offline, locally, exactly as it does today
  → a session exists that nobody was asked to create
  → the walk's own records carry sync identity
  → they push to the server when the network happens to be there
  → photographs follow their rows
  → a finished walk can be shown to someone who does not have the app
  → and only at the end, a person can claim the account it was all filed under
```

If a task does not move that loop forward, it does not belong in C2.

## The constraint this plan is shaped around

Stated by the owner, 2026-08-20: **no login, register or OAuth screens until every
other feature is finished.**

That is honoured — those screens are phase 6, last. But the plan separates two
things the word "auth" covers, because conflating them breaks phases 3–5:

| | What it is | When |
|---|---|---|
| **Session** | an `auth.users` row and a JWT, obtained anonymously, no screen, nobody asked | phase 1 |
| **Credential** | Apple / Google, the linking screen, `merge-anonymous` | phase 6 |

Every `app.*` table declares `user_id uuid not null references auth.users(id)` and
every RLS policy reads `user_id = (select auth.uid())`. With no session there is no
row that can be inserted and no policy that can pass — so phases 3–5 cannot be
built, or even tested, without one. Deferring the session does not delay those
phases; it deletes them.

The anonymous session is also what makes the deferred credential work at all:
`merge-anonymous` attaches a real identity to an anonymous user's **existing** data.
Introduce the session at the same time as the login screen and there is nothing left
to merge.

## Documents

| File | Purpose |
|---|---|
| **[PROGRESS.md](PROGRESS.md)** | **Start here every session — what is done, what is next, what is blocked** |
| [00-scope.md](00-scope.md) | Verified state of the deployed backend, what is in, what is out |
| [01-architecture.md](01-architecture.md) | Where sync sits, which seams it uses, the rules it must not break |
| [02-data-model.md](02-data-model.md) | Field-by-field client ↔ server mapping, and the five gaps |
| [03-security-privacy.md](03-security-privacy.md) | Keys, RLS, the privacy rules, and the non-engineering blockers |
| [04-verification.md](04-verification.md) | How each phase is proved. Not "it looked right on device" |
| [phases/](phases/) | Phase-by-phase build plan with exit criteria |

## Schedule

**There are no dates in this plan, deliberately.** C2 has no external deadline, and
a date on a phase that is gated on a consent letter is a fiction. Phases are ordered
by dependency and sized in days of focused work.

| # | Phase | Depends on | Size | Outcome |
|---|---|---|---|---|
| 0 | [Governance & Telemetry](phases/phase-0-governance-telemetry.md) | — | 1–2 d | The two kits `c1` wrote are actually called. Kill-switch works |
| 1 | [Anonymous Session](phases/phase-1-anonymous-session.md) | — | 1 d | A JWT exists from first launch. No screen, no prompt |
| 2 | [Sync Identity](phases/phase-2-sync-identity.md) | — | 2 d | Client records carry `device_id`, `revision`, tombstones, bucketed accuracy |
| 3 | [Push Sync](phases/phase-3-push-sync.md) | 1, 2 | 3 d | A walk completed offline appears in the database |
| 4 | [Photo Upload](phases/phase-4-photo-upload.md) | 1, 3 | 2 d | A checkpoint photograph has a row, two objects, and an `uploaded_at` |
| 5 | [Share Card](phases/phase-5-share-card.md) | 1, 4 | 3 d | A stranger without the app can open a finished walk. Revocation revokes |
| 6 | [Credential](phases/phase-6-credential.md) | 1 | 2 d | Apple / Google sign-in. Anonymous data survives the link |

**Phases 0, 1 and 2 depend on nothing and on each other not at all.** They can run in
any order, in parallel, alongside unrelated UI work. Phase 2 touches no network code
whatsoever and is pure `RunEngine`.

## Cut-line

When this has to shrink, cut in this order:

1. **Phase 5 (share card).** It is blocked on consent that has not been requested
   (`03-security-privacy.md` §4), it needs a new Edge Function, and the recap card
   it would share is not built. Cutting it costs nothing the walker can see today.
2. **Phase 4's thumbnail derivative.** Ship the full-size object only and let the
   grid download it. Costs bandwidth, not correctness. `thumb_path` stays null.
3. **Phase 0's telemetry half.** The kill-switch half is a safety control and stays;
   the events half only informs the team.
4. **Phase 6.** It is already last, and the app is designed to work without it
   forever.

**Never cut:** the anonymous session (phase 1 — everything below it stops existing),
tombstones (phase 2 — without them a delete on one device resurrects on another the
moment pull sync ships), accuracy bucketing (phase 2 — it is `NFR-PRIV-02`, not a
format detail), or the sidequest-photo exclusion (phase 4 — `FR-SIDE-13`).

## Rules for executing this plan

1. **The walk works offline, at every phase, unconditionally.** `AD-3`. A phase that
   makes a screen wait on the network has failed regardless of what it shipped.
2. **No reachability checks.** Not in any phase, not "just to show a better error".
   `ImportBoundaryTests.noModuleChecksReachability` is the guard and it stays green.
3. **Local storage is the source of truth.** `FileRunStore` is not replaced. The
   server is a copy.
4. **`RunStore` stays the seam.** Sync goes behind or beside it, never in front. No
   view model learns that a server exists.
5. **Nothing new goes in the database.** Every planned feature already has a table.
   Wanting a new one means the design answered the question differently — read
   `docs/backend-supabase.md` before writing a migration.
6. **The Supabase MCP is read-only.** `b0` D9. `apply_migration` and
   `deploy_edge_function` write to the remote and create no repo file, so the two
   diverge with nothing to detect it. Migration file → `db reset` → tests → `db push`.
7. **Prove isolation over HTTP with a real user token.** `execute_sql` runs elevated
   and bypasses RLS, so it can say what a table contains and nothing about who may
   read it (`b3` §4).
8. **The service-role key never enters the app.** Any build configuration, any
   convenience, including local development. See `03-security-privacy.md` §1.
9. **Claim only what is verified.** A ticked box means it is in the repo and it ran
   against the deployed project — not that it is written down here.

## Tracking progress

Every phase file carries a **Status** block and checkboxes; `PROGRESS.md` carries the
roll-up.

> Update the plan in the same commit as the code. Tick what landed, set the phase
> status, append a line to the session log in `PROGRESS.md`.

Checkbox meaning: `[ ]` not done · `[x]` done, in the repo, **and verified against
the deployed project** · `[~]` deliberately skipped, with ` — SKIPPED: reason` on the
line.

Tick a box only when the thing is real. A checkbox that lags the repo is worse than
no checkbox, because the next session trusts it.

## Do this before writing code

<!-- Tick these off in place. -->

- [ ] `supabase link --project-ref ppwcxmvetmmwliusliac`. There is no linked target
      right now, so `db push` and `functions deploy` have nothing to act on.
- [ ] Confirm the Supabase MCP session you are using is read-only, or accept rule 6
      as a convention with nothing enforcing it. `.mcp.json` carries no
      `&read_only=true` today.
- [ ] Read `00-scope.md` §3 — the Supabase MCP token lists only `team_5`, a
      different, INACTIVE project in another org. Do not deploy into it.
- [ ] Fix `xcode-select` or export `DEVELOPER_DIR` — every build and test command in
      this plan fails without it (`CLAUDE.md`, "This machine's toolchain is
      misconfigured").
- [ ] Decide who owns the four cross-cutting consent blockers in
      `03-security-privacy.md` §4. They block phase 5 and they are not engineering
      work.
