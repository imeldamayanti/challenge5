# B0 — Scope, and the decisions the migrations rest on

## 1. In scope

- A `supabase/` project at the repository root, created by `supabase init`.
- `config.toml` configured for this design, not left at defaults — two of its settings are load-bearing
  security controls rather than conveniences (D1).
- Forward-only timestamped migrations reproducing `docs/backend-supabase.md` §4, §6, §8, §9.
- A pgTAP suite proving cross-user isolation (§8.2) and two catalogue queries that hold the structural
  rules (§8.2, §15.5).
- Three Edge Functions: `ingest`, `delete-account`, `merge-anonymous`.
- A CI job running `supabase db reset` + `supabase test db` on every pull request.

## 2. Deliberately not in it

| Left out | Why |
|---|---|
| Any change to the iOS app | The client half is `docs/backend-supabase.md` §11's seam work and belongs in its own plan. This folder builds a server that nothing yet calls. |
| `catalog` schema and the publish pipeline | D5 below. §13.7 already concluded git wins; building the Postgres authoring store anyway would be building the option the design rejected. |
| `app.recommend_quests` | Defect 15. It returns zero rows as written, and §10 already requires the client to compute the ranking locally. |
| Seed data resembling production | `seed.sql` is local-development only. Seeding anything that looks like a real user's walk into a shared environment is how test data reaches a release. |
| Self-hosting configuration | Decided as a later concern. Everything here runs identically on hosted Supabase and on a self-hosted stack; only `config.toml`'s project linkage differs. |

## 3. Decisions

### D1 — Two `config.toml` settings are security controls, not preferences

Most of `config.toml` configures the local stack. Two settings decide what the *deployed* database
exposes, and both were specified in `docs/backend-supabase.md` §8 as design requirements:

```toml
[api]
schemas = ["app"]     # NOT ["public", "app", "catalog", "ops"]
max_rows = 1000
```

`schemas` is the actual enforcement of "clients never read `catalog` or `ops`" (§5, §6.2). A policy
saying they should not is a sentence; a schema absent from this list is unreachable over PostgREST no
matter what policies exist. `ops` in particular has **no client policies at all** and would be fully
exposed if it appeared here.

`max_rows` caps any single PostgREST response. Without it, one request with no filter returns a
user's entire history in one document — RLS still keeps it to *their* rows, so this is a resource
control rather than an isolation one, but an uncapped endpoint is how a mobile client OOMs on a
power user.

These two lines are reviewed on every change to this file, as a rule.

### D2 — Migrations are forward-only, and there is no `down`

The Supabase CLI does not run down-migrations, and this design should not want them. A rollback that
executes `drop table app.runs` on a database holding real walks is a worse outcome than any forward
fix. Recovery from a bad migration is a **new migration** plus, if data was lost, point-in-time
restore.

The practical consequence, and it is a discipline rather than a setting: **a migration that drops or
rewrites a column must be split across two releases** — add the new shape, backfill, ship a client
that reads both, then remove the old shape in a later migration. §12's "each phase is independently
revertible" only holds if no migration is destructive.

### D3 — One migration per concern, ordered by dependency, never edited after merge

```
0001_schemas_roles_grants        schemas, revoke public, role grants, default privileges
0002_role_settings               statement_timeout, idle_in_transaction_session_timeout
0003_ops_tables                  suppressions, events, survey_responses + BRIN/GIN
0004_ops_suppressions_publish    the trigger that regenerates suppressions.json
─────────────────────────────────  phase 0 ends here; no `app` schema exists yet
0005_sync_sequence               app.sync_seq, stamp_server_seq trigger function
0006_app_tables                  profiles, runs, checkpoint_results, task_results, awards, photos
0007_app_indexes                 FK indexes, pull indexes, partial uniques
0008_app_rls                     enable, force, policies, no delete policy anywhere
0009_storage_buckets             trip-photos, share-cards, content + storage.objects policies
0010_app_defaults                autovacuum per-table settings on the sync tables
─────────────────────────────────  phase 1 ends here
0011_sync_conflicts              table, RLS, the conflict trigger
0012_journal_share               journal_entries, share_cards
```

**A merged migration is immutable.** Editing one that has run anywhere means two databases with the
same migration history and different schemas, which the CLI cannot detect and nobody notices until a
constraint fires in production. Fix forward, always.

Numbers above are ordering labels; the CLI generates real timestamped filenames via
`supabase migration new <name>`.

### D4 — `public` is empty and stays empty

Everything lives in `app`, `catalog`, or `ops`. `0001` runs `revoke all on schema public from public`
and nothing is ever created there.

The reason is that `public` is the default target for anything created without a schema qualifier —
a helper function, an extension's objects, a table added in a hurry from the dashboard. Keeping it
empty means an object appearing there is visibly a mistake rather than being indistinguishable from
the rest of the schema.

Extensions go in a dedicated `extensions` schema, which is Supabase's own default.

### D5 — `catalog` is not built, and this plan records why rather than silently skipping it

`docs/backend-supabase.md` §5 designs Postgres as the content authoring store, and §13.7 concludes
that authoring in git with Postgres as a publish target is both cheapest and the only option that
keeps the validator gating a **merge** — which is the mechanism `NFR-GOV-01` actually relies on.

Those two sections contradict each other and the contradiction is unresolved in the design document.
This plan resolves it operationally by not building `catalog`: content stays in
`Sources/ContentKit/Content/`, `content-validator` stays a CI gate on pull requests, and v3 delivery
becomes a signed archive on a CDN behind the existing `ContentRepository` seam.

If product later wants a CMS with an editing UI, that is a new decision with a new plan, and it
should reopen §5 rather than inherit it.

### D6 — pgTAP is a project dependency, not an afterthought

`supabase test db` runs `.sql` files in `supabase/tests/` against a freshly reset database. The
extension is enabled in a migration guarded to local use, or created by the test harness itself.

This matters because of what §8.2 asks the suite to prove. Four of its nine assertions are
**structural** — every table has RLS forced, every view is `security_invoker`, every
`security definer` routine has a fixed `search_path`, every foreign key is indexed. Those catch the
regression that per-table assertions cannot: somebody adding a *new* table, view or function and
forgetting the rule. They fail the build the day the omission lands rather than the day it is
exploited.

The per-table assertions are still written out, because a structural check cannot tell you that
`runs_select` compares the wrong column.

### D7 — Edge Functions hold the service role; nothing else does

Three functions, and each exists because the operation cannot be done safely from a client:

| Function | Why it cannot be a client call or a SQL function |
|---|---|
| `ingest` | Batching limits, schema-version rejection and rate limits live here. Insert-only RLS for `anon` would hand every installed app a token that writes directly to the database (§6.2). |
| `delete-account` | `FR-SET-02` spans Postgres and object storage, which no transaction covers. The ordering that makes the half-states survivable is program logic (§8). |
| `merge-anonymous` | Verifying two JWTs needs the auth admin API. A `security definer` SQL function that rewrites `user_id` is an account-takeover primitive whose entire safety is argument validation (§7.3). |

`verify_jwt` is **false** for `ingest` — it is deliberately unauthenticated (`NFR-SEC-03`: accepting
junk is preferable to shipping credentials in a bundle) — and **true** for the other two.

The `service_role` key exists in exactly two places: Edge Function environment, and CI secrets. Never
the app, never a config file, never a migration.

### D8 — UUIDv7 is a client-side change this plan depends on but does not make

`docs/backend-supabase.md` §2.3 pins UUIDv7 for every device-generated primary key. Nothing in the
migrations enforces it — the column is `uuid` either way, and a v4 id inserts and works correctly.

So the server cannot hold this rule, and it will silently degrade to v4 if the client is never
changed. The consequence is index bloat that grows with the table rather than a visible failure. It
belongs in the client-side plan, listed here so it is not lost between the two.

### D9 — The Supabase MCP is read-only here

The MCP server is configured at project scope (`.mcp.json`) and exposes write tools. **Two of them
would break this plan and must not be used.**

`apply_migration` writes DDL straight to the hosted project and creates **no file** in
`supabase/migrations/`. The remote then holds a change the repository has never seen, which the CLI
cannot reconcile: a later `db push` conflicts or silently diverges, `db reset` locally rebuilds a
different database than production, and D2's forward-only guarantee is gone. The failure is invisible
until a constraint fires somewhere nobody is looking. `deploy_edge_function` does the same to
`supabase/functions/`.

| Use it for | Never |
|---|---|
| `list_tables`, `list_migrations` — confirming what is actually deployed matches the repo | `apply_migration` |
| `get_advisors` — the §8.1 RLS cases, caught server-side as well as in CI | `deploy_edge_function` |
| `execute_sql`, **`select` only** — verification and inspection | `execute_sql` for DDL or data repair |
| `query_logs` — including §14 defect 17's IP-retention question | `create_branch` (Pro, and unused by D-none — see `b3` §1.3) |

`execute_sql` runs elevated and therefore **bypasses RLS**, which makes it good for asking what a
table contains and worthless for proving who can read it. Isolation is proved by a real HTTP request
carrying a real user's JWT (`b3` §4), never by a query the MCP runs as an administrator.

Every schema change goes: migration file → local `db reset` → tests → `db push`. There is no second
path, and the MCP is not one.

## 4. What this work is blocked on

| Blocker | Blocks | Owner |
|---|---|---|
| Edge Services ownership — who runs it, what uptime (`system-design.md` §16) | phase 0 | engineering + product |
| §13.3 — UU 27/2022, the project region, and the named data controller | phase 1, hard | product + legal |
| A privacy policy and a user-facing deletion path | phase 1 | product |
| §14 defects 14, 16, 17, 18 — still open in the design | phases 3, 4 | engineering |
| Photo activities shipped on device | phase 3 | engineering |
