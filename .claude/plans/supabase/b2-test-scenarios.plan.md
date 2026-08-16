# B2 — Every scenario, and where each one is proved

Nothing is pushed to a project holding real users until this matrix is green. The point is not
coverage as a number; it is that **every failure mode named in `docs/backend-supabase.md` §14 and §15
has a test that would have caught it.** Thirteen of those defects were found by reading. The next
thirteen will not be.

## 0. Where tests live and what runs them

```
supabase/tests/
├── 00_setup.sql                 pgtap; users A and B; helper to assume a role
├── 01_structure.test.sql        §1 — structural rules, no fixtures needed
├── 02_isolation.test.sql        §2 — cross-user isolation, per table
├── 03_constraints.test.sql      §3 — every check, unique, FK, partial index
├── 04_sync.test.sql             §4 — push, pull, conflict
├── 05_auth_merge.test.sql       §5 — anonymous, linking, merge, cull predicate
├── 06_concurrency.test.sql      §6 — races, locks, deadlock ordering
└── 07_performance.test.sql      §7 — plan shape assertions
supabase/tests/functions/        §8 — Deno tests for the three Edge Functions
```

`supabase test db` runs `*.test.sql` against a database `supabase db reset` has just rebuilt from
migrations. Edge Functions are tested with `deno test` against `supabase start`.

**Assuming a user in pgTAP.** RLS keys on `auth.uid()`, which reads a JWT claim. In tests, set it
directly:

```sql
create or replace function tests.as_user(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role','authenticated')::text, true),
         set_config('role', 'authenticated', true);
$$;
```

`set_config(..., true)` is transaction-local, so each test unwinds cleanly. **Tests must run as
`authenticated`, never as `postgres`** — the owner bypasses RLS and every isolation test would pass
against a table with no policies at all (§8.1 case 4). `01` asserts the harness itself is not
running as a superuser, because that single mistake invalidates the entire file below it.

---

## 1. Structural — the tests that survive being forgotten

These need no fixtures and fail the day somebody *adds* something, which is when the hand-written
assertions in every later section get overlooked.

| # | Assertion | Catches |
|---|---|---|
| 1.1 | every table in `app` has `relrowsecurity` **and** `relforcerowsecurity` | §8.1 case 1 — a new table with no RLS is readable by everyone, silently |
| 1.2 | every view in `app` has `security_invoker` | §8.1 case 2 — views do not inherit base-table RLS |
| 1.3 | every `security definer` routine has a non-mutable `search_path` | §8.1 case 3 — privilege escalation via name shadowing |
| 1.4 | every foreign key has an index on its referencing column | §15.5 — Postgres never creates these; cascade deletes go quadratic |
| 1.5 | no table in `app` grants anything to `anon` | §8 grants layer |
| 1.6 | no `delete` policy exists on any table in `app` | tombstones are the only deletion path |
| 1.7 | every syncable table has a `server_seq` column and a `stamp_server_seq` trigger | a table that syncs without a cursor is invisible to pull, forever |
| 1.8 | every syncable table has `(user_id, server_seq)` | §9.3's query without its index |
| 1.9 | the test harness is not a superuser | invalidates §2 entirely if wrong |

## 2. Isolation — the guarantee, per table

Seeded: user A owns one run with two checkpoint results, three task results, two awards, one journal
entry, two photos, one share card. User B owns nothing.

| # | As B | Expected |
|---|---|---|
| 2.1 | `select` each of `profiles`, `runs`, `checkpoint_results`, `task_results`, `awards`, `journal_entries`, `photos`, `share_cards`, `sync_conflicts` | **0 rows**, per table, individually |
| 2.2 | `insert into app.runs (user_id, …) values (A, …)` | **rejected** by `with check` |
| 2.3 | `update app.runs set state='abandoned' where id = <A's run>` | **rejected** — asserted as an error, not as "0 rows affected" |
| 2.4 | `delete from app.runs where id = <A's run>` | **rejected** — no delete policy anywhere |
| 2.5 | `insert … on conflict (id) do update` against A's row id | **rejected**, and does not silently create a second row |
| 2.6 | select with no JWT at all (`role = anon`, no `sub`) | 0 rows everywhere; `auth.uid()` is null and the comparison must deny, not error |
| 2.7 | `select from ops.events` / `ops.survey_responses` over PostgREST | **unreachable** — not "empty". `api.schemas` excludes the schema (b0 D1) |
| 2.8 | `select from catalog.*` over PostgREST | unreachable, same mechanism |

**2.3 and 2.5 are the two worth writing carefully.** A policy that *matches nothing* and a policy
that *denies* look identical from a client until somebody changes the predicate, and only one of them
is a guarantee. Assert the error, not the row count.

## 3. Constraints and data integrity

| # | Scenario | Expected |
|---|---|---|
| 3.1 | second `active` run for the same `(user_id, quest_id)` | unique violation — `FR-START-06` (§4.3) |
| 3.2 | second `active` run after the first is `completed` | **succeeds** — the index is partial on `state = 'active'` |
| 3.3 | re-insert a `checkpoint_result` whose previous row is tombstoned | **succeeds** — partial unique on `deleted_at is null` (§14 defect 10) |
| 3.4 | two `awards` with `run_id = null`, same `type` and `source_id` | **rejected** — `nulls not distinct` (§14 defect 4). This is the letter case, and a plain unique would allow infinite duplicates |
| 3.5 | two `awards` with different `run_id`, same `source_id` | succeeds — a stamp earned on two different walks |
| 3.6 | `awards.type = 'letter'` | accepted (§4.5) |
| 3.7 | `awards.type = 'trophy'` | rejected |
| 3.8 | `suppressions.entity_type = 'sidequest'` | accepted (§6.1) |
| 3.9 | `runs.state = 'notStarted'` | rejected — an in-memory-only state must not be representable |
| 3.10 | `runs.state = 'completed'` with `completed_at` null | rejected — `runs_completed_has_timestamp` |
| 3.11 | `runs.state = 'abandoned'` with no `abandon_reason` | rejected |
| 3.12 | `gps_accuracy_bucket = '20-75m'` | **rejected** — tokens only (`lt20`/`b20_75`/`gt75`). Guards the en-dash mismatch against `schema.md` §B.7 |
| 3.13 | delete a `run` | children cascade; no orphaned `checkpoint_results` |
| 3.14 | delete a `photo` referenced by a `task_result` | `photo_id` becomes null; **the task result survives** (§4.5) |
| 3.15 | `language`, `arrival_method`, `content_type` outside their check lists | rejected, each |

## 4. Sync — where the defects were

### 4.1 Push

| # | Scenario | Expected |
|---|---|---|
| 4.1.1 | insert new row | inserted; `returning` yields its id and `server_seq` |
| 4.1.2 | re-push identical row, same `revision` | no-op; **`returning` yields nothing** (§14 defect 6) |
| 4.1.3 | push `revision = 3` over stored `revision = 5` | no-op, no data change, nothing returned |
| 4.1.4 | push `revision = 6` over stored `5` | applied |
| 4.1.5 | client sends its own `server_seq` | **overwritten** by the trigger; the client's value never lands |
| 4.1.6 | push `revision = current + 5000` | rejected as a bad request (§9.2 clamp, §14 defect 9) |
| 4.1.7 | push a `task_result` whose `photo_id` has not been pushed | **FK violation** — this is the test that proves §9.2's push order is load-bearing (§14 defect 5) |
| 4.1.8 | push in the documented order | all seven tables succeed |

**4.1.2 is the one that matters most.** A losing upsert returns `200` with zero rows changed. A
client that marks `synced` on a `200` has recorded that a row it never wrote is safely on the server —
data loss that reports success. The test asserts the `returning` set is empty so the client contract
has something to rest on.

### 4.2 Pull

| # | Scenario | Expected |
|---|---|---|
| 4.2.1 | pull from cursor 0 | every row, ordered by `server_seq` |
| 4.2.2 | pull, update a row, pull again from the new cursor | the updated row reappears — `server_seq` moved |
| 4.2.3 | tombstone a row, pull | the tombstone is returned, so deletion propagates |
| 4.2.4 | `limit` smaller than the result set | pages cleanly; **no row appears in neither page** |
| 4.2.5 | two rows with identical `updated_at` straddling a page boundary | both returned — `server_seq` is unique, so there is no tie to drop (§14 defect 3) |
| 4.2.6 | write a row with `updated_at` set 3 days in the past by the client | **still pulled** — the cursor is `server_seq`, not a device clock (§14 defect 1) |
| 4.2.7 | open a transaction claiming a `server_seq`, let a reader pass it, then commit | the row is caught by the overlap window (§9.3, §15.4) |
| 4.2.8 | pull as B | only B's rows; RLS applies to the cursor query like any other |

**4.2.6 is the regression test for the false claim** that started this review. It writes what a
three-day-slow phone would write and asserts the row is still delivered.

### 4.3 Conflict

| # | Scenario | Expected |
|---|---|---|
| 4.3.1 | device 1 pushes rev 4, device 2 pushes rev 5, same row | rev 5 stored |
| 4.3.2 | same, reverse arrival order | rev 5 still stored — order of arrival must not matter |
| 4.3.3 | equal revisions, different `device_id` | earlier `updated_at` wins (§9.4) |
| 4.3.4 | any losing push | the losing row is written to `app.sync_conflicts` **in full**, never dropped |
| 4.3.5 | `sync_conflicts` as user B | 0 rows of A's conflicts |
| 4.3.6 | client `insert` into `sync_conflicts` | rejected — no insert policy; only the trigger writes there |
| 4.3.7 | two devices both start the same quest offline, both push | second gets a constraint violation; §9.5's resolution abandons the lesser run and **neither run's snapshots are lost** |

## 5. Auth, linking, and the merge

| # | Scenario | Expected |
|---|---|---|
| 5.1 | anonymous sign-in | succeeds; a real `auth.users` row; `is_anonymous` true |
| 5.2 | write a run while anonymous, then link an unused email | `user_id` unchanged; every row kept (§7) |
| 5.3 | link an email that already exists | rejected up front, **before** the walker agrees to anything (§7.3) |
| 5.4 | `merge-anonymous` with a valid anon token and target session | rows move; anon `auth.users` row deleted last |
| 5.5 | run `merge-anonymous` twice | second run moves nothing; idempotent (§7.3 rule 1) |
| 5.6 | merge where both identities have the same quest active | resolved per §9.5; neither run deleted |
| 5.7 | merge where both hold the same stamp | earlier `awarded_at` kept; duplicate dropped, not tombstoned |
| 5.8 | merge with a forged/expired anon token | **rejected**. The single most important negative test in this file — a merge that trusts its input is account takeover |
| 5.9 | merge where `target_uid = anon_uid` | rejected |
| 5.10 | merge while the anon user has rows mid-push | rejected; client retries after its queue drains |
| 5.11 | merge moves storage objects before rows | an interrupted merge leaves the original readable (§7.3 rule 4) |
| 5.12 | cull predicate against an anon user with **one** run | **not deletable**, at any age (§7.4) |
| 5.13 | cull predicate against an anon user with zero runs, zero journal, zero photos, 91 days old | deletable |

## 6. Concurrency and locking

Run with two sessions. These are the tests that need `pg_sleep`, advisory coordination, and patience;
they are also the only ones that catch the failures that appear exclusively in production.

| # | Scenario | Expected |
|---|---|---|
| 6.1 | two simultaneous pushes of the same award | one inserts, one no-ops on the unique index; **never two rows** |
| 6.2 | two sessions upserting the same row set in **opposite** id order | deadlock — demonstrates why §15.2's sort-by-id exists |
| 6.3 | the same two sessions, both sorted by id | both complete; no deadlock |
| 6.4 | delete-account while an upload is in flight | the `deleting` flag stops the final PUT; the sweeper catches anything that slipped (§15.3) |
| 6.5 | a session idle in transaction beyond the timeout | terminated by `idle_in_transaction_session_timeout` (§15.7) |
| 6.6 | a query exceeding `statement_timeout` | cancelled, not hung |
| 6.7 | account deletion for a user with 500 checkpoint results | completes in bounded time; batched, not one statement (§15.2) |

**6.2 asserts a deadlock actually happens.** A test that only proves the good path passes would also
pass if the deadlock risk were imaginary. Proving the hazard is real is what justifies the rule.

## 7. Query shape

Assertions on `explain (format json)` output rather than on timing, so they are stable in CI.

| # | Query | Expected plan |
|---|---|---|
| 7.1 | pull: `where user_id = … and server_seq > …` | index scan on `(user_id, server_seq)`; **no sequential scan** |
| 7.2 | summary embed (run + all children) | index scans throughout; no seq scan on `checkpoint_results` |
| 7.3 | `delete from auth.users` cascade | index scans on every child FK — the test that makes 1.4 meaningful rather than cosmetic |
| 7.4 | `ops.events` 30-day range | BRIN scan, not a full scan (§6.2) |
| 7.5 | `events.params @> '{"questID":"…"}'` | GIN scan |
| 7.6 | "my walks" list | index scan on `(user_id, state, completed_at desc)` |

## 8. Edge Functions — `deno test`

| # | Scenario | Expected |
|---|---|---|
| 8.1 | `ingest` with a valid batch, no JWT | accepted (`verify_jwt = false` is deliberate — `NFR-SEC-03`) |
| 8.2 | `ingest` with an unknown `schema_version` | rejected, not stored |
| 8.3 | `ingest` with a batch over the cap | rejected |
| 8.4 | `ingest` repeatedly from one IP | rate limited |
| 8.5 | `ingest` attempting any read | no read path exists — asserted by inspection and by the function's own role grants |
| 8.6 | `ingest` payload carrying a `user_id` field | ignored; `ops.events` has no such column and must never acquire one (§2.4) |
| 8.7 | `delete-account` as A | A's rows and **both derivatives** of every photo gone; B untouched |
| 8.8 | `delete-account` interrupted after objects, before rows | rows point at missing bytes — a broken thumbnail, which is the survivable half-state (§8) |
| 8.9 | `delete-account` re-run | idempotent |
| 8.10 | `delete-account` with B's JWT targeting A | rejected |
| 8.11 | storage: upload to own prefix | accepted |
| 8.12 | storage: upload to A's prefix as B | refused (§8.3) |
| 8.13 | storage: `update` and `delete` on A's object as B | refused — the two verbs commonly left unpoliced |
| 8.14 | storage: file above `file_size_limit` | refused; an un-downscaled original is rejected rather than silently accepted |
| 8.15 | signed URL after expiry | refused |

## 9. Migration safety

| # | Scenario | Expected |
|---|---|---|
| 9.1 | `supabase db reset` from empty | every migration applies in order; this runs on every CI job |
| 9.2 | `supabase db push --dry-run` against dev | reports only the migrations intended |
| 9.3 | a check-constraint change using `not valid` + `validate` | applies without `ACCESS EXCLUSIVE` for the duration of the scan (§15.8) |
| 9.4 | `db reset` twice in a row | identical schema both times — no migration depends on leftover state |
| 9.5 | `supabase db lint` | clean |
| 9.6 | Supabase advisors, after push to dev | no security advisories; performance advisories triaged and either fixed or recorded |

## 10. What is deliberately not tested

Named so the gaps are decisions:

- **Load and volume.** At pilot scale the numbers are uninteresting, and a load test built now would
  measure a schema with no users. Revisit if a collection ever exceeds a single region's worth.
- **Backup restore.** Belongs to `b3` §5 as a drill with a stated cadence, not a unit test.
- **The iOS client's half of sync.** `RunEngine` is covered by `swift test`; the queue, the
  `sync_state` transitions and the retry policy are the client plan's, and the contract between them
  is what §4 above pins down.
- **`catalog`.** Not built (b0 D5).

---

## Execution — 2026-08-15

**Status: every scenario in §1–§9 is implemented, and the matrix is green against the local stack.**
197 assertions across four harnesses. Nothing was pushed, so the two scenarios that require a
deployed project (§9.2, §9.6) are deliberately unexecuted rather than quietly dropped.

### Where each section ended up

| Section | File | Harness |
|---|---|---|
| §1 structure | `supabase/tests/01_structure.test.sql` | pgTAP |
| §2 isolation | `02_isolation.test.sql` **and** `tests/http/isolation_over_http.test.ts` | pgTAP + HTTP |
| §3 constraints | `03_constraints.test.sql` | pgTAP |
| §4 sync | `04_sync.test.sql`; §4.2.7 in `tests/concurrency/` | pgTAP + two sessions |
| §5 auth and merge | `05_auth_merge.test.sql` **and** `tests/functions/merge_anonymous.test.ts` | pgTAP + HTTP |
| §6 concurrency | `tests/concurrency/concurrency.test.ts`; 6.4 in `storage.test.ts`, 6.7 in `delete_account.test.ts` | two psql sessions |
| §7 query shape | `07_performance.test.sql` | pgTAP |
| §8 Edge Functions | `tests/functions/{ingest,delete_account,merge_anonymous,storage}.test.ts` | Deno + HTTP |
| §9 migration safety | 9.1/9.4/9.5 in the commands below; 9.3 in `tests/concurrency/` | CLI |

§0's file numbering is followed except that `00_setup.sql` became `seed.sql` (b1 execution,
deviation 8) and there is no `06_*.test.sql` — §6 needs two sessions and pgTAP runs in one.

### Scenarios whose expected result was wrong, and what was asserted instead

These are the three places where the matrix asked for something the designed system cannot do. In
each case the guarantee was still proved; the *shape* of the proof changed.

- **2.3 — "an update on A's row id is rejected, not 0 rows affected."** With
  `for update using (user_id = auth.uid())`, A's row is invisible to B, so Postgres has nothing to
  reject and the statement matches zero rows cleanly. An error is only reachable when the row is
  visible and the `with check` fails. Asserted: the update affects nothing, A's row is unchanged on
  re-read, **and** the rejection that *is* expressible — B moving their own row to A raises 42501.
  The distinction the plan cares about (deny versus match-nothing) is real; it lives on the write
  side, not the read side.
- **2.6 / b3 §4 — "a select with the publishable key and no session returns `[]`."** It is refused
  outright, because §8's grants layer revokes everything on `app` from `anon`. A refusal is strictly
  stronger than an empty list. Both the pgTAP and the HTTP test accept either and assert the thing
  that matters — no row escapes — while recording which actually happens.
- **6.5 — "a session idle in transaction beyond the timeout is terminated."** `ALTER ROLE … SET`
  applies at connection time to the *connecting* role, and `authenticated`/`anon` are NOLOGIN;
  PostgREST reaches them through `SET ROLE`, which does not re-read those settings. So the mechanism
  is proved on a real session (6.5) and the configuration is asserted separately from
  `pg_db_role_setting` (6.5b). Asserting only one of the two would have been a test that passes with
  the timeouts unset.

### 8.5, restated

"`ingest` attempting any read — asserted by inspection" is now three assertions: every method other
than POST returns 405, the success body carries only counts, and `anon`/`authenticated` hold no
EXECUTE on `app.ingest_batch` (02_isolation 2.8c/2.8d). There is no read path in the function and no
role that could reach one if there were.

### Verification

```
$ supabase db reset && supabase db lint -s app,ops,catalog,public --fail-on warning
No schema errors found                                                     ← 9.5

$ supabase test db
01_structure.test.sql .... ok      02_isolation.test.sql .... ok
03_constraints.test.sql .. ok      04_sync.test.sql ......... ok
05_auth_merge.test.sql ... ok      07_performance.test.sql .. ok
All tests successful.  Files=6, Tests=145                                  ← §1–§5, §7

$ deno test --allow-net --allow-env --allow-run supabase/tests/functions/
ok | 33 passed | 0 failed                                                  ← §8, 6.4, 6.7

$ deno test --allow-net --allow-env --allow-run supabase/tests/http/
ok | 11 passed | 0 failed                                                  ← b3 §4

$ deno test --allow-net --allow-env --allow-run supabase/tests/concurrency/
ok | 8 passed | 0 failed                                                   ← §6, 4.2.7, 9.3
```

9.4, "`db reset` twice in a row gives an identical schema", run as a real check:

```
$ supabase db reset && pg_dump --schema-only --schema=app --schema=ops --schema=catalog > 1.sql
$ supabase db reset && pg_dump --schema-only --schema=app --schema=ops --schema=catalog > 2.sql
$ diff 1.sql 2.sql
5c5
< \restrict 5MSKcqpnP7205bFXxSQb1tTFT9TczeqxoPbltx1LPP52KU3LaNsvmaQ8cPZSEhc
---
> \restrict gmKCMwdRBti3WS9of0a1RabWIcRLafvO2XnQzVXe0fbma3LphB9X6W43WqTzTjn
```

The only difference across 1 899 lines is pg_dump's own per-invocation `\restrict` token. No
migration depends on leftover state.

### Two real defects the matrix caught

Both were in code written for this plan, which is the point of writing the tests rather than
reviewing the code:

1. **3.14** — the conflict trigger silently cancelled `on delete set null`, leaving
   `task_results.photo_id` pointing at a deleted photo. A cascaded update reaches the trigger with
   an unchanged revision and device_id, which is indistinguishable from an idempotent retry.
2. **6.7b** — `delete_account_batch` deleted `app.runs` in the same call, so the cascade finished
   the whole account in one "bounded" statement. The batch size was a fiction.

Also caught, in the configuration rather than the code: **8.14** uploaded 11 MiB to a bucket whose
row had a NULL `file_size_limit`. A NULL limit is unlimited; it does not inherit the global one.

### Deliberately not executed

- **9.2 `supabase db push --dry-run`** and **9.6 advisors after a push to dev.** Both require the
  linked project, and pushing is `b3` §3 steps 5–9. The hosted project `ppwcxmvetmmwliusliac` was
  confirmed untouched at the end of this work through the read-only MCP: `list_migrations` → `[]`,
  `list_tables` → `[]` for `app`, `ops`, `catalog` and `public`.
- Everything in §10, unchanged: load and volume, backup restore, and the iOS client's half of sync.

### New known gaps in the coverage itself

1. **8.9 and 5.5 accept `401` as well as `200` on the second call.** Once the identity is deleted
   its token no longer resolves, so a retried request cannot reach the idempotent path at all. The
   underlying steps are separately proved idempotent (`delete_account_batch` returns 0;
   `merge_anonymous_rows` reports `moved_runs: 0`), which is the part a retry actually re-enters.
2. **8.8 simulates the interruption rather than causing one.** The objects are deleted through the
   Storage API and the function is then run from that state. A genuine crash between steps 2 and 3
   is not reachable from a test.
3. **§7's plan assertions depend on planner choices at the volumes the test creates** — 5 000 runs,
   4 000 checkpoint results, 150 000 events. They are stable today; a planner upgrade could change
   one, and the failure would be a plan assertion rather than a correctness one. The volumes are in
   the file and can be raised.
4. **6.1 and 6.2 are timing-shaped.** They coordinate two psql processes with `pg_sleep`, so a
   loaded runner could in principle serialise them and lose the race. Both assert on the error the
   loser reports, so a missed race fails loudly rather than passing silently.
5. **Nothing tests the pooler.** §15.6 requires Edge Functions to use the transaction-mode pooler
   for direct connections, and the three functions built here make none — they reach the database
   over PostgREST. The rule stands for whatever needs it next; there is nothing yet to test.
