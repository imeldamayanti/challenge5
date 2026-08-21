# 00 — Scope

## 1. What C2 is

The app's first network call. Nothing else.

No new tables, no new screens except phase 6's, no change to how a walk behaves.
Every phase either calls something already deployed or prepares the client to be
able to.

## 2. Verified state of the deployed backend

Checked 2026-08-20 against the running project, not read from a document.

| Fact | How it was checked |
|---|---|
| Hosted project `ppwcxmvetmmwliusliac`, `https://ppwcxmvetmmwliusliac.supabase.co`, `ap-southeast-1` | `get_project_url` |
| 18 migrations applied, `20260815200001`–`20260816200001`, matching `supabase/migrations/` file-for-file | `list_migrations` |
| 4 Edge Functions ACTIVE at version 4 | `list_edge_functions` |
| `ingest` is `verify_jwt: false`; `delete-account`, `merge-anonymous`, `publish-suppressions` are `true` — matching `config.toml` | `list_edge_functions` |
| Kill-switch document live, world-readable, schema 2, three empty arrays | `GET /storage/v1/object/public/content/suppressions.json` → 200, no key sent |
| The app target links neither `TelemetryKit` nor `GovernanceKit` | no reference in `project.pbxproj`; no `import` outside package tests |
| No `URLSession`, no Supabase SDK, no remote URL anywhere in the app target | source scan |
| Local Docker stack exists but every container is stopped | `docker ps -a` |
| The CLI is **not linked** | no `supabase/.temp/project-ref` |

## 3. Two operational traps

Each of these costs an hour if met cold.

**The Supabase MCP token lists only `team_5`.** `list_projects` returns exactly one
project — `mchizboalmzgbaiaztdz`, ap-northeast-2, status INACTIVE, a different
organization. It reaches `ppwcxmvetmmwliusliac` on a direct query but does not
enumerate it. `team_5` is not this project. When a tool asks for a project id and
offers only that one, stop.

**Nothing is linked.** `supabase link --project-ref ppwcxmvetmmwliusliac` before any
`db push` or `functions deploy`, or those commands have no target.

## 4. The tables, and which phase touches each

| Schema | Table | Phase | Note |
|---|---|---|---|
| `ops` | `events` | 0 | **Has no `user_id` column and must never acquire one** (design §2.4) |
| `ops` | `suppressions`, `suppressions_document` | 0 | Read via the public bucket, never directly |
| `ops` | `survey_responses` | — | The recall survey is not built. Out of scope |
| `app` | `profiles` | 1 | Not syncable — no `server_seq`, absent from the push order |
| `app` | `runs` | 3 | |
| `app` | `checkpoint_results` | 3 | |
| `app` | `task_results` | 3 | |
| `app` | `awards` | 3 | |
| `app` | `photos` | 4 | Created before `task_results` in migration 0006 for the FK order |
| `app` | `share_cards` | 5 | |
| `app` | `journal_entries` | — | See §6 |
| `app` | `sync_conflicts` | — | Live pull only. Out of scope; phase 7's restore cannot produce one |

## 5. Storage buckets

| Bucket | Public | Cap | Types | Phase |
|---|---|---|---|---|
| `content` | **yes** | none | any | 0 — read only, `to anon, authenticated` |
| `trip-photos` | no | 10 MiB | `image/heic`, `image/jpeg` | 4 |
| `share-cards` | no | 10 MiB | `image/png`, `image/jpeg` | 5 — and "no" is the phase-5 problem |

## 6. Deliberately not in C2

Each of these is a decision, not an oversight.

- **Live pull sync and the conflict UI.** `app.sync_conflicts` and the
  `<table>_resolve_conflict` triggers exist and are tested. The presentation for a
  conflict does not, and a pull that silently picks a winner is worse than no pull.
  **Amended 2026-08-21:** the *one-shot restore* in phase 7 is now in scope and is not
  this. It runs only into an empty local store and refuses otherwise, so there is no
  second writer and no conflict to show — the same argument phase 3 makes for push.
  Continuous pull, merging, and anything that compares two versions of a row stay out.
- **`app.journal_entries`.** It stores a user-authored `body`. The app has no journal
  editor — the Journal renders the Run's own snapshots (`AD-4`, `FR-RUN-06`). There
  is nothing to put in it. Wiring it means inventing a feature to justify a table.
- **`ops.survey_responses`.** The recall survey is not built.
- **A scheduler for `publish-suppressions`.** Still invoked by hand, as `c1` §6 left
  it. An operator running it is a documented gap, not a broken feature.
- **The `catalog` schema.** `b0` D5 recommends not building it.
- **Any edit to the 18 deployed migrations.** Forward-only; a merged migration is
  never edited.
- **A remote `ContentRepository`.** That is v3 and it is a swap behind the existing
  protocol (`AD-3`). C2 does not touch content delivery — the app keeps reading the
  bundle.

## 7. What "done" means for C2 as a whole

A walker installs the app, walks a quest in airplane mode, finishes it, and later
opens the app somewhere with signal. Without ever having seen a login screen, their
walk — its checkpoints, answers, awards and photographs — is on the server, filed
under an account they have not yet claimed, readable by nobody else, and deletable
by them from Settings.

Phase 6 then lets them claim it.
