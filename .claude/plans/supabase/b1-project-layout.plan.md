# B1 — The `supabase/` project, concretely

Everything here is the practice from `docs/backend-supabase.md` §8 and §15 applied to this schema.
General Postgres advice that does not bite this design is left out on purpose.

## 1. Creating it

From the repository root:

```bash
supabase init          # writes supabase/config.toml and supabase/.gitignore
supabase start         # local stack: Postgres, PostgREST, GoTrue, Storage, Studio
```

`supabase/.gitignore` is generated and already excludes `.branches/` and `.temp/`. Nothing else in
`supabase/` is ignored — migrations, tests, functions and `config.toml` are all committed.

## 2. `config.toml`

Only the settings that differ from the defaults for a reason. Everything else stays as `init` wrote
it.

```toml
project_id = "kultara"

[api]
enabled = true
port = 54321
# The enforcement of "clients never read catalog or ops" (b0 D1, design §5/§6.2).
# `ops` has no client policies at all and would be wide open if listed here.
schemas = ["app"]
extra_search_path = ["extensions"]
# Caps any single PostgREST response. RLS keeps a user to their own rows; this keeps a power
# user's history from arriving as one document a phone cannot hold.
max_rows = 1000

[db]
port = 54322
major_version = 15          # NULLS NOT DISTINCT (design §4.5) needs 15+

[db.pooler]
enabled = true
default_pool_size = 15
# Edge Functions connect through this, never the direct port (design §15.6). Transaction mode
# means no session state: no SET, no held prepared statements, no advisory locks.
pool_mode = "transaction"

[auth]
enabled = true
site_url = "kultara://auth-callback"
# Design §7: every user has an auth.users row from first launch, and nothing in the walk is gated
# on a credential or a radio.
enable_anonymous_sign_ins = true
enable_confirmations = true

[auth.email]
enable_signup = true

[storage]
enabled = true
# A 1600 px HEIC derivative is ~250 KB (design §4.7). 10 MiB is generous for a photograph that has
# already been downscaled on device, and low enough that an un-downscaled original is rejected
# rather than silently accepted.
file_size_limit = "10MiB"

[functions.ingest]
# Deliberately unauthenticated — NFR-SEC-03 prefers accepting junk to shipping credentials in a
# bundle. Rate limiting and schema-version rejection happen inside the function (design §6.2).
verify_jwt = false

[functions.delete-account]
verify_jwt = true

[functions.merge-anonymous]
verify_jwt = true
```

`site_url` is the app's custom scheme so email confirmation returns to the app rather than a web
page. Production values come from `supabase secrets` and the linked project's dashboard, not from
this file.

## 3. Migrations

`supabase migration new <name>` for each. Contents follow the design document section named on each
row; this table is the order and the reason, not a second copy of the DDL.

### Phase 0 — `ops` only, no accounts, no `app` schema

| Migration | Contents | Design |
|---|---|---|
| `0001_schemas_roles_grants` | `create schema app, catalog, ops`; `revoke all on schema public from public`; grants to `authenticated`; `alter default privileges`; **no grants to `anon` on `app`** | §8 |
| `0002_role_settings` | `statement_timeout` and `idle_in_transaction_session_timeout` on `authenticated` and `anon` | §15.7 |
| `0003_ops_tables` | `suppressions`, `events`, `survey_responses`; BRIN on both `received_at`; GIN `jsonb_path_ops` on `events.params`; `(name, occurred_at)` | §6.1, §6.2 |
| `0004_ops_suppressions_publish` | trigger regenerating `suppressions.json` into Storage on every change | §6.1 |

`0002` is second, not last, because every later migration and every test then runs under the same
timeouts the deployed database uses. A migration that only passes without a statement timeout is a
migration that will fail on deploy.

`0001` grants nothing on `app` to `anon`. Supabase's anonymous sessions are `authenticated` as far as
Postgres roles are concerned — `is_anonymous` is a JWT claim, not a role — so §7's anonymous walker
is covered by the `authenticated` grants and `anon` never needs to reach user data.

### Phase 1 — accounts

| Migration | Contents | Design |
|---|---|---|
| `0005_sync_sequence` | `app.sync_seq`; `grant usage … to authenticated`; `stamp_server_seq()` — **not** `security definer`, `set search_path = ''` | §4.1, §8.1 |
| `0006_app_tables` | `profiles`, `runs`, `checkpoint_results`, `task_results`, `awards`, `photos`; check constraints; `stamp_server_seq` trigger on each | §4.1–§4.7 |
| `0007_app_indexes` | every FK index; `(user_id, server_seq)` per table; partial uniques on `deleted_at is null`; `awards_one_per_source` with `nulls not distinct` | §15.5, §4.5 |
| `0008_app_rls` | `enable` + `force` on every table; select/insert/update policies using `(select auth.uid())`; **no delete policy anywhere** | §8 |
| `0009_storage_buckets` | `trip-photos`, `share-cards` private; `content` public-read; `storage.objects` policies for **all four** verbs on `storage.foldername(name)[1]` | §8.3 |
| `0010_app_autovacuum` | `autovacuum_vacuum_scale_factor = 0.05` on the sync tables | §15.7 |

`0007` before `0008` so the policies are never evaluated against unindexed columns during the
migration run itself.

`0009`'s four verbs are the point. A storage policy written for `select` only — the common shape —
leaves `insert`, `update` and `delete` open on a private bucket.

### Phase 2 — pull sync

| Migration | Contents | Design |
|---|---|---|
| `0011_sync_conflicts` | table, RLS with select-only, **no insert policy** (the trigger writes it), the conflict trigger | §9.4 |

### Phase 3 — journal, sharing

| Migration | Contents | Design |
|---|---|---|
| `0012_journal_share` | `journal_entries`, `share_cards`, their indexes, RLS, storage policy for share cards | §4.6, §4.8 |

### The rule for changing a check constraint

`awards.type` and `suppressions.entity_type` will both grow again. Never a bare drop-and-add:

```sql
alter table app.awards drop constraint awards_type_check;
alter table app.awards add constraint awards_type_check
  check (type in ('stamp','badge','letter')) not valid;      -- instant, no scan
alter table app.awards validate constraint awards_type_check; -- weak lock, reads and writes continue
```

Bare `add constraint` takes `ACCESS EXCLUSIVE` and holds it while scanning every row. Harmless on an
empty table; an outage on a live one. Same discipline for `create index concurrently` once there is
data — it cannot run inside a transaction, so it needs its own migration.

## 4. Tests — `supabase/tests/`

Run by `supabase test db` against a database `supabase db reset` has just rebuilt.

```
supabase/tests/
├── 00_setup.sql              create extension pgtap; two seeded users, A and B
├── 01_isolation.test.sql     the nine assertions of design §8.2
└── 02_structure.test.sql     the four structural checks + the two catalogue queries
```

`01` proves the per-table guarantee: as user B, zero rows of A's runs, checkpoint_results,
task_results, awards, journal_entries, photos, share_cards, sync_conflicts. Plus: an insert carrying
`user_id = A` is **rejected** rather than silently rewritten; an update on A's row id is **rejected**
rather than matching zero rows; a delete is rejected everywhere; an unauthenticated select returns
zero rows rather than erroring.

The reject-versus-match-nothing distinction is the one worth writing carefully. A policy that matches
nothing and a policy that denies look identical from the client until the day somebody changes the
predicate, and only one of them is a guarantee.

`02` is the file that keeps working after everyone forgets it exists:

- every table in `app` has `relrowsecurity` **and** `relforcerowsecurity`
- every view in `app` has `security_invoker`
- every `security definer` routine has a non-mutable `search_path`
- every foreign key has an index on its referencing column

Those four fail when somebody **adds** a table, view, function or foreign key — which is exactly the
moment the hand-written assertions in `01` get forgotten. This mirrors what the Swift package already
does with `ImportBoundaryTests` and the contrast suites: a rule a reviewer would have to remember
becomes a build failure.

## 5. Edge Functions — `supabase/functions/`

```
supabase/functions/
├── _shared/            cors.ts, supabase client factory, zod-style validators
├── ingest/index.ts     POST batch of events + survey rows. verify_jwt = false
├── delete-account/     FR-SET-02. verify_jwt = true
└── merge-anonymous/    the §7.3 flow. verify_jwt = true
```

`ingest` rejects an unknown `schema_version` rather than storing it, rate-limits, caps batch size, and
never reads. It is write-only by construction, not by policy.

`delete-account` follows §8's ordering exactly — flag, objects, rows in batches, `auth.users` last.
Objects before rows, because of the two possible half-states only one is survivable: rows pointing at
missing bytes is a broken thumbnail; bytes with no row is unreachable personal data.

`merge-anonymous` verifies both JWTs through the auth admin API before touching anything, and refuses
if the anonymous user has rows still in flight.

## 6. `seed.sql`

Local development only. `supabase db reset` runs it; `supabase db push` does not.

Two users, a handful of runs, one completed walk with snapshots. Enough to open the app against a
local stack. **Nothing resembling a real person's walk**, and no content rows — content comes from
`ContentKit`, not from the database (`b0` D5).

## 7. CI

One job, on every pull request touching `supabase/`:

```bash
supabase db reset          # applies every migration from scratch, then seed.sql
supabase db lint           # catches unqualified references and common mistakes
supabase test db           # pgTAP: isolation + structure
```

`db reset` from scratch on every run is what makes `b0` D2's forward-only rule safe: a migration that
only works against a database that already had the previous shape fails here rather than on deploy.

Deploy is `supabase db push` against the linked project, from a protected branch only, with the
service role key from CI secrets.

## 8. Files created

| Path | |
|---|---|
| `supabase/config.toml` | §2 |
| `supabase/migrations/*.sql` | §3 — 12 migrations across four phases |
| `supabase/tests/00_setup.sql`, `01_isolation.test.sql`, `02_structure.test.sql` | §4 |
| `supabase/functions/_shared/`, `ingest/`, `delete-account/`, `merge-anonymous/` | §5 |
| `supabase/seed.sql` | §6 |
| `.github/workflows/supabase.yml` | §7 |
| `CLAUDE.md` | a `supabase/` row in the directory layout, and the three commands |

## 9. Verification

Phase 0 is done when, from a clean checkout:

```bash
supabase db reset && supabase test db
```

passes, `select * from ops.events` is unreachable over PostgREST with the publishable key, and a
`POST /functions/v1/ingest` with a valid batch inserts rows while the same request with an unknown
`schema_version` is rejected.

Phase 1 adds: as user B, every assertion in `01_isolation.test.sql` passes, and an upload to
`trip-photos/<A's uid>/…` as B is refused by storage.

---

## Execution — 2026-08-15

**Status: built and green, locally. Nothing was pushed.** `supabase db push` and
`supabase functions deploy` were not run, and the hosted project `ppwcxmvetmmwliusliac` still holds
zero migrations and zero tables — confirmed through the read-only MCP (`list_migrations` → `[]`,
`list_tables` → `[]`). Pushing is `b3` §3 steps 5–9 and is a separate, deliberate act.

### What was built

```
supabase/
├── config.toml                     §2, with the two security settings of b0 D1
├── seed.sql                        pgTAP + dblink, the tests.* helpers, fixtures for users A and B
├── migrations/                     12 files, 20260815200001 … 20260815200012
├── tests/
│   ├── 01_structure.test.sql       b2 §1        02_isolation.test.sql    b2 §2
│   ├── 03_constraints.test.sql     b2 §3        04_sync.test.sql         b2 §4
│   ├── 05_auth_merge.test.sql      b2 §5        07_performance.test.sql  b2 §7
│   ├── functions/                  b2 §8  — ingest, delete-account, merge-anonymous, storage
│   ├── http/                       b3 §4  — isolation over real HTTP with real user JWTs
│   ├── concurrency/                b2 §6 and §4.2.7 — two real sessions per test
│   └── _helpers.ts                 shared token/REST/storage helpers
├── functions/
│   ├── _shared/                    http.ts, storage.ts, ratelimit.ts — no third-party imports
│   ├── ingest/index.ts             verify_jwt = false
│   ├── delete-account/index.ts     verify_jwt = true
│   └── merge-anonymous/index.ts    verify_jwt = true
└── ../.github/workflows/supabase.yml
```

Migration contents follow §3's table. The 12 files are the 12 rows, in that order, with the DDL
taken from `docs/backend-supabase.md` §4, §6, §8 and §9.

### Deviations, each with its reason

1. **`major_version = 17`, not 15.** §2 pins 15 because `NULLS NOT DISTINCT` needs 15+. The hosted
   project runs **17.6.1.155** (`get_project`), and the local major version must match the remote's
   or `db reset` rebuilds a different database than production. 17 satisfies the stated
   requirement; pinning 15 against a 17 project would create the divergence the pin exists to
   prevent.

2. **`0004` maintains `ops.suppressions_document` rather than writing `suppressions.json` to
   Storage.** Postgres cannot write object bytes into Supabase Storage — Storage keeps bytes behind
   an HTTP API and `storage.objects` is only its metadata table. The two ways a trigger could reach
   that API both require the service_role key **inside the database**, and design §8 says that key
   belongs in Edge Function environment and CI secrets, "nowhere else". So the trigger does the part
   that must be transactional (deriving the schema-2 document atomically with the change) and
   publication is a read of one row by a privileged caller. The client's contract is unchanged.

3. **`app.ingest_batch` was added to `0003`.** `ingest` has to write to `ops`, and `ops` is not
   exposed over PostgREST (b0 D1). The alternative was a direct pooler connection from the function
   (§15.6), which needs a third-party Postgres driver in the function bundle. A `security definer`
   RPC in `app` with `EXECUTE` granted to `service_role` alone keeps the functions dependency-free
   and enforces the batch cap and schema-version rejection in two places rather than one.

4. **`0012` carries three more service-role routines**: `app.merge_anonymous_rows`,
   `app.delete_account_batch`, `app.anonymous_cull_candidates`. They live in the last migration
   because each has to see every table it touches. §7.3 rejects a definer function that rewrites
   `user_id` because "its entire safety rests on argument validation"; that objection is answered by
   the EXECUTE grant rather than by argument validation — no role a client can hold may call them,
   and the Edge Function proves both JWTs before passing either uid.

5. **`app.profiles` gained `deleting_at`.** §15.3 requires "a flag the upload path checks"; §4.2's
   DDL predates it. The flag is additionally enforced in the `trip-photos` insert policy, so a
   client cannot skip it — the failure it prevents (an object landing after FR-SET-02 removed its
   row) is unreachable, undeletable personal data.

6. **`app.journal_entries` and `app.share_cards` gained the §4.1 sync columns.** Both are in §9.2's
   push order and §15.5 asks for the pull index "on every syncable table", but neither table's DDL
   in §4.6/§4.8 carries `server_seq`. As published they would be pushable and then invisible to pull
   forever. Recorded in the migration itself.

7. **Storage buckets carry an explicit `file_size_limit`.** A bucket row with a NULL limit is
   *unlimited* — it does not inherit config.toml's global `file_size_limit` — so the 10 MiB in §2
   described an intention nothing enforced. Test 8.14 uploaded 11 MiB successfully before this was
   fixed.

8. **Setup lives in `seed.sql`, not `tests/00_setup.sql`.** `supabase test db` hands its directory
   to pg_prove, which runs every `.sql` file as a test and reports one with no plan as a failure.
   `seed.sql` is the file the CLI already runs immediately before the tests and never runs against a
   deployed project (`db push` skips it), which is exactly the guard §4 wanted.

9. **Share-card storage policies are in `0009`, with the bucket**, rather than in `0012` as §3's
   table lists. No private bucket should exist for even one migration without a policy on every
   verb.

10. **`ops` tables have RLS enabled and forced with no policies.** §8 says `ops` has "no client
    policies at all"; enabling RLS with none is a third free layer under the exposed-schema
    configuration and the absent grants.

### Two defects the tests found in the code written here

- **The conflict trigger silently cancelled referential actions.** `task_results.photo_id` is
  `on delete set null`, which Postgres performs as an internal UPDATE carrying the same revision and
  device_id — indistinguishable from an idempotent retry, so `app.resolve_sync_conflict` returned
  NULL and the column kept pointing at a deleted row. Fixed with `pg_trigger_depth() > 1`. Found by
  test 3.14.
- **`delete_account_batch` was not actually batched.** It deleted `app.runs` in the same call, and
  the cascade took every child with it — so one "bounded" call finished an entire account, which is
  the unbounded lock §15.2 rules out. The parent now goes only once every child is gone. Found by
  test 6.7b.

Both were introduced by this implementation, not inherited from the design.

### Verification

```
$ supabase db reset
Applying migration 20260815200001_schemas_roles_grants.sql...
… (all twelve) …
Applying migration 20260815200012_journal_share.sql...
Seeding data from supabase/seed.sql...
Finished supabase db reset on branch backend-design-revision.

$ supabase db lint -s app,ops,catalog,public --fail-on warning
Linting schema: app / ops / catalog / public
No schema errors found

$ supabase test db
01_structure.test.sql .... ok      02_isolation.test.sql .... ok
03_constraints.test.sql .. ok      04_sync.test.sql ......... ok
05_auth_merge.test.sql ... ok      07_performance.test.sql .. ok
All tests successful.
Files=6, Tests=145,  1 wallclock secs

$ deno test --allow-net --allow-env --allow-run supabase/tests/functions/
ok | 33 passed | 0 failed (8s)

$ deno test --allow-net --allow-env --allow-run supabase/tests/http/
ok | 11 passed | 0 failed (2s)

$ deno test --allow-net --allow-env --allow-run supabase/tests/concurrency/
ok | 8 passed | 0 failed (8s)
```

**197 assertions in total.** `deno test` needs its permission flags spelled out under Deno 2; b3
§0's `deno test supabase/tests/functions/` fails on the first `fetch` without them.

`db lint` is scoped to the four schemas this repository owns. pgTAP installs ~90 plpgsql functions
of its own into `extensions` and plpgsql_check reports upstream warnings for them; an unscoped lint
is never clean on any project that has pgTAP installed.

### Left out, deliberately

- **No `db push`, no `functions deploy`, no `link`.** b3 §3 steps 5–9, and a human's decision.
- **No `catalog` tables.** b0 D5. The schema exists and is empty so its absence is a decision.
- **No `app.recommend_quests`.** §14 defect 15: it returns zero rows as written, and §10 already
  requires the client to compute the ranking locally.
- **No down-migrations.** b0 D2.
- **Nothing under `challange-5/`.** The Swift client is a separate plan; this builds a server
  nothing yet calls.

### New known gaps

1. **The rate limit is per-worker and in-memory.** `_shared/ratelimit.ts` stops a loop from one
   client and will not stop a distributed flood. A real limit is a shared counter, and a shared
   counter keyed on IP is itself IP retention — so it belongs with the §14 defect 17 decision about
   what these functions may record about a caller at all, not before it.
2. **`merge-anonymous` trusts the client's `anon_queue_empty` assertion.** §15.3 says to reject when
   the anonymous user has rows mid-push, and the server cannot see a client's `sync_state`. The
   assertion is required to be explicit and defaults to refusing, which is the safe direction, but
   it is a claim rather than a check.
3. **`ops.events` still has no retention horizon** (§14 defect 18, open). The BRIN index that makes
   the retention delete cheap exists; the delete does not.
4. **Nothing publishes `suppressions.json` yet.** Deviation 2 leaves a row that a job or Edge
   Function must read and write to Storage. That job is not built.
5. **The orphan sweeper is not built** (§4.7). `delete-account` sweeps by prefix on the path it
   controls, but no scheduled job finds objects whose row never existed.
6. **`ops.suppressions_document` is regenerated per statement, not per row.** Correct and cheaper,
   but it means a bulk suppression update rewrites the document once — which is the intent, and
   worth knowing before someone adds a per-row trigger beside it.
