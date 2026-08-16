# B3 — Environments, pushing, and getting back out

## 0. Local first, and it is not a compromise

**Everything in `b1` and `b2` is built and proved against the local stack. No hosted project is
required to complete either.**

`supabase start` runs the real services in Docker — Postgres, PostgREST, GoTrue, Storage API — not
mocks or stand-ins. The same binaries the hosted platform runs. So RLS evaluation, storage
authorization, constraint behaviour, the conflict trigger, anonymous sign-in and the whole sync
protocol behave identically, and `b2` §1–§9 runs end to end on a laptop.

**`config.toml` is applied by `supabase start`.** An earlier draft of this plan claimed a
`config.toml` mistake was invisible to local testing and that only a deployed project would catch it.
That was wrong: `[api] schemas = ["app"]` configures the local PostgREST too, so §4's
`ops`-is-not-exposed check is a valid local test. It is worth re-running after a push, but it is not
a reason to need a hosted project in order to write it.

What local genuinely cannot show you is operational rather than behavioural:

| Absent locally | Matters when |
|---|---|
| S3 storage backend | signed-URL edge behaviour and CDN — not policy evaluation |
| Real SMTP (local uses Inbucket) | exercising email confirmation for real |
| Pooler behaviour under concurrency | there is load worth measuring |
| Edge Function cold starts, regional deploy | measuring latency |
| Quotas, free-tier pausing, advisors | operating it rather than building it |

None of that is in `b2`. So the sequence is:

```
now      local stack + CI on every PR          ← b1, b2 complete here
later    one hosted project, when something needs a real endpoint
         (a TestFlight build, a demo)          ← §1 onward
prod     the gates in README.md                ← §8
```

CI runs exactly the local commands, which is what makes the local pass meaningful rather than
personal:

```yaml
- uses: supabase/setup-cli@v1
- run: supabase start
- run: supabase db lint
- run: supabase test db
- run: deno test supabase/tests/functions/
```

GitHub runners have Docker, so this needs no special arrangement. A pull request that reddens this
job has broken the schema, and nobody has to remember to check.

---

## 1. Two tiers: local, then prod

**The working shape is local for every change, one hosted project for release.** No separate hosted
dev tier. Local is the development environment; §0 explains why that is sufficient rather than a
compromise.

```
edit a migration
  ↓
supabase db reset && supabase db lint && supabase test db     ← every change, locally
  ↓  green
CI repeats it on the pull request                             ← the same commands
  ↓  merged
supabase db push --dry-run  →  read it  →  supabase db push   ← prod
  ↓
b3 §4's HTTP suite against the prod URL
```

This means **prod is the first hosted environment any migration ever touches.** That is an accepted
risk, not an overlooked one, and three things carry it:

1. **Additive-only migrations are the rollback strategy** (`b0` D2), not tidiness. A migration that
   only ever adds cannot destroy data, so the worst outcome of a bad push is an unused column rather
   than a lost walk. This is the property that makes skipping a staging tier defensible; give it up
   and the argument for a hosted dev project comes straight back.
2. **`--dry-run` before every push, without exception.** It prints exactly which migrations would
   apply. One command, and it is the only thing between a mistaken local migration and a live schema.
3. **§4's HTTP suite runs against prod immediately after**, because provisioning differences are
   precisely what local cannot show.

### 1.1 Prod is not precious until the first real user

Between creating the project and the first TestFlight sign-in, prod holds nothing — so during that
window it *is* a hosted dev environment, and it can be pushed to, tested against and even reset,
freely. That is a genuine free testing period, and it has an end date.

| | Before the first real user | After |
|---|---|---|
| `db reset` on prod | fine — there is nothing to lose | **never** |
| Push cadence | as often as useful | deliberate, with a backup taken first |
| Backups | unnecessary | before every push, no exceptions |
| Plan | Free is workable | Pro — see §1.2 |
| Gates in `README.md` | do not apply yet | all of them apply |

**The first push is the easy one and worth doing early**: it applies all 12 migrations to an empty
database, which exercises the entire chain end to end against real infrastructure while nothing is at
stake. Every push after that is one or two migrations onto a database with data in it, which is a
different risk profile. Do the first one deliberately and soon.

The day the first walker signs in, every row in the "After" column becomes true at once, and nothing
in the tooling announces it. Put that transition on someone's calendar rather than in a document.

### 1.2 Prod cannot stay on the free plan

Free is fine while prod is empty. It stops being fine on the same day the gates do, and for three
reasons that are not about capacity:

| Free-tier limit | Consequence once real walkers exist |
|---|---|
| **Pauses after 7 days idle** | a paused project silently stops `/ingest`, and telemetry is the only verdict v1 produces on its own hypothesis (`system-design.md` §1). The release goes quiet with nothing reporting it |
| No PITR, limited backups | §5 lists point-in-time restore as the last resort for data loss. Without it there is no last resort, and photographs are irreplaceable |
| 500 MB database, 1 GB storage | ~175 completionist users at §4.7's ~5.7 MB each |

So **Pro is a launch requirement, not a scaling one.** It belongs in §13.1's ledger — the decision to
have accounts at all — rather than arriving as a surprise the week of release.

### 1.3 Supabase Branching is not used

**Branching is a Pro feature.** It gives ephemeral, git-integrated preview databases per pull
request. It is genuinely good, and this plan does not need it: the local stack (§0) covers what a
preview branch would, on every change, for free.

If a second hosted environment is ever wanted, it is an ordinary second project rather than a branch
— `supabase db push` cannot tell the difference, since both are just a `--project-ref`, and nothing
in `b1` or `b2` would change. Any such project shares prod's region, because one in a different
region stands in for a different latency and a different legal posture than the thing it represents.

## 2. Linking, and the file that must not be committed

```bash
supabase link --project-ref <prod-ref>    # writes supabase/.temp/, already gitignored
supabase db push --dry-run                # prints what WOULD be applied. Always first.
supabase db push
supabase functions deploy ingest delete-account merge-anonymous
```

`--dry-run` before every push, without exception. It is the only thing between a mistaken local
migration and a schema change on a live database, and it costs one command.

**`project_id` in `config.toml` is a local identifier, not a secret.** The project *ref* and the
service role key are. Neither belongs in the repository: the ref goes in CI variables, the key in CI
secrets, and `supabase/.temp/` stays gitignored.

Secrets for Edge Functions:

```bash
supabase secrets set --env-file ./supabase/.env.production   # never committed
supabase secrets list                                        # names only, no values
```

## 3. The push sequence, in order

Steps 1 and 2 run locally and again in CI on every pull request. Steps 3 onward run only when
releasing, and once prod holds real users a human approves between 4 and 5 — and takes a backup
first (§5).

```
1. supabase db reset && supabase db lint && supabase test db    ← local, from scratch
2. deno test supabase/tests/functions/                          ← Edge Functions
3. §4's HTTP suite against localhost:54321                      ← catches config.toml mistakes here
   ─────────────────────────────────────────────────────────────  everything above runs in CI too
4. take a backup                                                ← once prod holds users; §5
5. supabase link --project-ref <prod-ref>
6. supabase db push --dry-run                                   ← read the output. Every time.
7. supabase db push
8. supabase functions deploy
9. §4's HTTP suite again, against the prod URL                   ← the step people skip
10. supabase inspect db bloat / advisors                          ← §6
```

Step 3 is what makes this two-tier workflow safe: the checks that would otherwise only run after a
deploy run on the pull request instead, because `supabase start` applies `config.toml` (§0).

Step 9 is not redundant with step 3. Step 3 proves the configuration is right; step 9 proves the
hosted provisioning matches it — different grants on `anon`/`authenticated`, a different Storage
backend, a real edge in front. It is short, and it is the last thing standing between a green build
and a leak.

## 4. Isolation is proved over HTTP, not only inside the database

pgTAP runs inside the database as a role the harness chooses. That proves the *policies* are correct.
It does not prove the *stack* denies a real request, because three things sit between them that
pgTAP never touches: PostgREST's exposed-schema configuration, the grants attached to `anon` and
`authenticated`, and the Storage service's own policy evaluation.

So this suite exists separately from `b2`, and it runs in two places: **against `localhost:54321`
in CI on every pull request**, and again against any deployed URL after a push. It is the same file
with a different base URL — the local run is the one that catches things early, and the deployed run
confirms nothing about the hosted provisioning differs.

Two real signed-in test users, A and B:

| Check | Expected |
|---|---|
| `GET /rest/v1/runs` as B, with A's rows present | `[]` |
| `GET /rest/v1/runs?id=eq.<A's run>` as B | `[]` |
| `PATCH` A's run as B | no rows affected, and no change on re-read as A |
| `DELETE` any row as anyone | refused |
| `GET /rest/v1/events` (schema `ops`) | **404 / not exposed** — not an empty array |
| `GET /rest/v1/bundles` (schema `catalog`) | not exposed |
| `GET /rest/v1/runs` with the publishable key and **no** session | `[]` |
| `GET` A's storage object as B | 400/403 |
| `PUT` into A's storage prefix as B | refused |
| `POST /functions/v1/ingest` with no JWT | accepted |
| `POST /functions/v1/delete-account` with no JWT | rejected |

The `ops`/`catalog` rows are the ones that catch a `config.toml` mistake — and because `supabase
start` applies `config.toml`, they catch it **locally**, on the pull request, rather than after a
deploy. That is the argument for running this suite in CI rather than treating it as a post-push
ritual.

## 5. Getting back out

**There are no down-migrations** (b0 D2), so "rollback" means one of three things, in increasing
order of damage:

1. **Forward fix.** A new migration that corrects the previous one. Almost always this. It is the
   only option that does not risk data.
2. **Revert the deploy, not the schema.** Ship the previous app build. An additive migration —
   which is all of them, by D2 — leaves the old client working, because a column it does not know
   about does not break it. This is why additive-only is a deployment property and not just tidiness.
3. **Point-in-time restore.** Only for data loss, only on Pro, and it restores the **whole project**
   to a timestamp — every user's rows, not the broken table's. Everything written since that moment
   is gone. It is the option that trades one incident for another, and it needs a named decision at
   the time, not a runbook that makes it look routine.

**A backup is taken before every prod push** regardless, because deciding whether you needed one is
cheaper than discovering you did.

**The restore drill happens before prod holds anything.** Restore `kultara-dev` from a backup, on a
calendar, once. A backup nobody has restored is a belief rather than a backup — the same reasoning
`system-design.md` §14 applies to the airplane-mode and field-proximity gates, which are listed as
release gates precisely because they are the two most likely to be skipped.

## 6. Watching it after the push

| What | Where | Looking for |
|---|---|---|
| Security advisors | `supabase db lint` and the dashboard's advisor | a table without RLS, a definer function with a mutable `search_path` — the §8.1 cases, caught server-side as well as in CI |
| `pg_stat_statements` | enabled from migration `0001` | which query got slow, answerable after the fact instead of by guessing |
| Table bloat | `supabase inspect db bloat` | §15.7's dead-tuple accumulation, which this schema invites by design |
| Unused indexes | `supabase inspect db unused-indexes` | the ones added speculatively; drop them rather than paying their write cost forever |
| Long-running queries | `supabase inspect db long-running-queries` | a transaction holding the vacuum horizon (§15.7) |
| Edge Function logs | dashboard | ingest rejections by reason, and **the IP-retention question in §14 defect 17**, which is a live privacy issue the moment logs exist |

Defect 17 deserves attention on the first day logs are produced rather than the first day someone
audits them: Edge Function logs record client IPs with timestamps, and §2.4's anonymity claim only
holds once IP handling and log retention are stated.

## 7. What is not decided here

- **Hosted versus self-hosted.** Everything above is identical either way except step 3's target.
  Self-hosting in Jakarta is the option that removes §13.3's cross-border transfer question entirely,
  and it costs an operations burden that has to be accepted knowingly — including that a lost disk
  is unrecoverable photographs, which no forward migration fixes.
- **The project names.** `kultara-*` is a working title; the app still has no name (`CLAUDE.md`,
  known state), and a project ref is awkward to change afterwards.
- **Who holds the prod service role key**, and how it rotates. It bypasses RLS entirely, which makes
  it the single most valuable secret in the system.

## 8. Definition of done

**Local is done** when `supabase db reset && supabase db lint && supabase test db` is green from a
clean checkout, `deno test` passes, §4's HTTP suite passes against `localhost:54321`, and CI runs all
of it on every pull request. Nothing external is required to reach this, and `b1` and `b2` are
complete here.

**The first prod push is done** when all 12 migrations have applied to an empty project, the
functions are deployed, and §4's suite is green against the prod URL. Do this while prod holds
nothing — it exercises the whole migration chain against real infrastructure with nothing at stake,
and every push afterwards is a smaller change onto a database with data in it.

**Prod is ready for real users** when all of that holds *and*: a named data controller exists, the
region is chosen under §13.3, a privacy policy is published, `FR-SET-02` deletion works end to end
from inside the app, the project is on Pro (§1.2), the restore drill has been performed once, and
someone has signed the §14 defect 17 log-retention policy.

Nothing on that last list is engineering work this plan can complete alone. It is also the moment
§1.1's table flips in full, with nothing in the tooling to announce it.

---

## Execution — 2026-08-16

**Status: pushed. `Histoplora` (`ppwcxmvetmmwliusliac`, ap-southeast-1) now holds the schema, the
three functions and the pushed config.** This is §8's "first prod push is done" milestone, taken
during the window §1.1 describes: prod held nothing, so the whole migration chain ran against real
infrastructure with nothing at stake.

It is **not** §8's "ready for real users". Every item on that list is still open — see the end of
this record.

### The sequence that was actually run

§3's steps 1–3 had already been green locally (see `b1` and `b2` execution records). Then:

```
$ supabase link --project-ref ppwcxmvetmmwliusliac
{"project_ref":"ppwcxmvetmmwliusliac"}

$ supabase db push --dry-run
Would push these migrations:
 • 20260815200001_schemas_roles_grants.sql … • 20260815200012_journal_share.sql   (all twelve)

$ supabase db push
Applying migration 20260815200001_schemas_roles_grants.sql...
… (all twelve) …
Finished supabase db push.

$ supabase config push
{"services":[{"service":"api","status":"up_to_date"},{"service":"db.settings","status":"up_to_date"},
 {"service":"auth","status":"up_to_date"},{"service":"storage","status":"updated"}, …]}

$ supabase functions deploy
Deploying Function: delete-account (7.1 kB) / ingest (5.6 kB) / merge-anonymous (7.3 kB)
Deployed Functions.

$ supabase functions list
delete-account  ACTIVE  verify_jwt=true
ingest          ACTIVE  verify_jwt=false
merge-anonymous ACTIVE  verify_jwt=true

$ SUPABASE_URL=https://ppwcxmvetmmwliusliac.supabase.co … deno test supabase/tests/http/
ok | 11 passed | 0 failed (16s)                                            ← §3 step 9
```

### `supabase config push` is a step this plan did not have, and it is load-bearing

§2 and §3 list `link → db push → functions deploy`. That sequence leaves `config.toml` behind, and
`config.toml` is where **two security controls** live (`b0` D1). A hosted project's default exposed
schemas are `public, graphql_public` — so without this step `app` is unreachable, `max_rows` is
unset, anonymous sign-ins are off and the storage limit is 50 MiB. The three settings this design
depends on would all have been wrong on a project that had just passed its migration push.

**Add `supabase config push` to §3 between steps 7 and 8.** It is not optional, and nothing else in
the sequence reveals its absence — the HTTP suite would have caught it at step 9, which is the last
possible moment.

It failed the first time:

```
{"error":{"code":"LegacyConfigPushStorageUpdateStatusError",
  "message":"unexpected status 402: {\"message\":\"Please upgrade the project to a paid tier to
   enable vector buckets\"}"}}
```

`supabase init` writes `[storage.vector] enabled = true`, and Vector Buckets are paid-tier. Nothing
here stores embeddings, so it is now `false`. Worth knowing before §1.2's Pro upgrade, because it is
a 402 that has nothing to do with the reasons Pro is actually needed.

### A thirteenth migration, from advisors the local stack does not run

`get_advisors` after the push found two things, and both were fixed forward
(`20260815210001_least_privilege_hardening.sql`) rather than left in the ledger:

- **0028/0029 — `app.resolve_sync_conflict()` was executable by `anon` and `authenticated` as a
  `SECURITY DEFINER` function via `/rest/v1/rpc/`.** Postgres grants EXECUTE to PUBLIC on every new
  function; nothing in the migrations had revoked it. Not exploitable — calling a trigger function
  directly raises — but a definer function reachable from the public API is the shape §8.1 case 3
  warns about, and "not exploitable today" is not a property anyone maintains.
- **0012 — every policy in `app` applied to PUBLIC**, because none carried a `TO` clause. `anon`
  cannot reach those tables (0001 revokes the grants and the schema USAGE), so this was correct in
  effect and wrong in statement. All policies are now `TO authenticated`, which is the only audience
  they ever meant: §7's anonymous walker holds a real JWT and *is* `authenticated` as a Postgres
  role.

Both now have structural tests (`01_structure.test.sql` 1.10, 1.10b, 1.11) so they fail locally on
the next occurrence rather than being caught by an advisor after a push. The full local suite was
re-run green before the second push, and `db push --dry-run` showed exactly the one new file.

### Advisors after the fix, triaged rather than cleared

| Advisor | Level | Verdict |
|---|---|---|
| `rls_enabled_no_policy` on the four `ops` tables | INFO | **By design.** §8: "`ops`: no client policies at all". RLS with no policy denies everything to every role without BYPASSRLS, which is the intent; the tables are additionally unreachable over PostgREST and ungranted. |
| `auth_allow_anonymous_sign_ins` on `app.*` and `storage.objects` | WARN | **By design, and the design is the whole point of §7.** The advisor flags policies that admit Supabase anonymous-sign-in users. Those users are exactly who §7.1 says must be able to walk, arrive, and write their Run without an account. Removing the warning would mean removing the feature. |
| `unused_index` ×17 | INFO | **Expected.** No query has ever run against this database. §15.5 says to revisit unused indexes once there is traffic; there is none. Re-check after the first real walks, not now. |

Zero actionable security advisories remain.

### State of the project right now

```
migrations applied : 13
tables             : app ×9, ops ×4, all with rls_enabled = true
rows               : app.* → 0 everywhere
                     ops.suppressions_document → 1  (the seeded empty schema-2 document, 0004)
                     ops.events → 1                 (see below)
auth.users         : 0
functions          : 3, ACTIVE, verify_jwt as configured
```

**The 16 test identities created by the HTTP suite were deleted afterwards** through the admin API;
their rows went with them by cascade, which is itself a small live proof of §4's
`on delete cascade` chain. `auth.users` is empty and every `app` table is at zero.

**One row was left in `ops.events`** — the anonymous ingest from §4's "POST /functions/v1/ingest
with no JWT is accepted". It carries no `user_id` and cannot acquire one (§2.4), so it is a
telemetry row of the exact kind this table exists for rather than personal data. It was left rather
than removed because removing it means an elevated write through the MCP, which `b0` D9 forbids for
good reasons that do not stop applying when the write is convenient.

### Deliberately not done

- **No backup was taken first** (§3 step 4). §1.1: backups become mandatory the day prod holds a
  real user, and it holds none. This is the last push for which that is true.
- **No secrets were set** (`supabase secrets set`). The three functions read `SUPABASE_URL` and
  `SUPABASE_SERVICE_ROLE_KEY`, which the platform injects. Nothing else is needed yet, and the
  prod service_role key was read from `supabase projects api-keys` into a shell variable for the
  duration of one test run and written nowhere.
- **The function suites were not run against prod**, only §4's HTTP suite. `tests/functions/`
  inspects the database through `docker exec psql` against the *local* container, so pointing its
  HTTP calls at prod would compare two different databases. Running them against a deployed project
  needs a different inspection path, and §4 is what step 9 asks for.
- **No `supabase db reset` on prod, ever again.** It is fine today by §1.1's table and it will not
  be, and nothing in the tooling will announce the change.

### What §8's "ready for real users" still needs

Unchanged by this push, and all of it outside engineering's gift:

1. A named data controller, and the §13.3 decision about **Singapore hosting Indonesian users'
   photographs** under UU 27/2022. The project is in `ap-southeast-1`. That is a cross-border
   transfer from the first row, and there are zero rows *right now* — which makes this the cheapest
   moment in the project's life to change region if the answer is that it must.
2. A published privacy policy, and `FR-SET-02` deletion reachable from inside the app.
3. **Pro** (§1.2) — not for capacity, but because the free tier pauses after 7 days idle and a
   paused project silently stops `/ingest`, which is the only verdict v1 produces on its own
   hypothesis.
4. The restore drill, performed once, while prod still holds nothing.
5. A signed answer to §14 defect 17: Edge Function logs now exist and record client IPs.
