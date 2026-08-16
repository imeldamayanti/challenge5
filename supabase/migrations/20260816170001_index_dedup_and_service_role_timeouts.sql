-- 0016 — redundant indexes removed, and the timeout 0002 forgot.
-- docs/backend-supabase.md §15.2, §15.4, §15.7. Skill: postgres-patterns (composite index order).
--
-- Forward-only (b0 D2). Non-additive: this drops eight indexes. None of them was serving a query
-- another index does not serve, which is the whole point — the proof is in the comment on each
-- group, and a pgTAP guard now fails if a redundant one is reintroduced.

-- --------------------------------------------------------------------------------------------
-- 1. Eight indexes that are strict PREFIXES of another index on the same table.
--
-- A B-tree on (a, b) serves `where a = ?` exactly as well as a B-tree on (a) — same descent, same
-- leading-column comparison — so the single-column index earns nothing and costs a write on every
-- insert and on every update that touches the column. These are the SYNC tables: `revision`,
-- `server_seq` and `updated_at` change on every push, so the write amplification is paid on the
-- hottest path the design has.
--
-- It also costs planning time (more candidate paths) and cache: eight extra index relations
-- competing for the same shared_buffers as the ones doing real work.
--
-- Each drop below names what still covers it. Verified with a prefix query rather than by eye,
-- and re-asserted by test 3.19.
--
-- The FK-support check (`b2`, and the postgres-patterns anti-pattern query) still passes after
-- this: every foreign key retains an index whose LEADING column is the referencing column.

-- `user_id = ?` — every RLS policy's predicate — is served by the leading column of each `_pull`
-- index, which exists for the delta-sync cursor (user_id, server_seq) and is not optional.
drop index app.awards_user;              -- covered by awards_pull (user_id, server_seq)
drop index app.checkpoint_results_user;  -- covered by checkpoint_results_pull
drop index app.photos_user;              -- covered by photos_pull
drop index app.task_results_user;        -- covered by task_results_pull
drop index app.share_cards_user;         -- covered by share_cards_pull
drop index app.journal_entries_user;     -- covered by journal_entries_pull AND journal_user_created

-- `app.runs` carried FOUR indexes led by user_id: runs_user, runs_pull, runs_user_updated and
-- runs_user_state. The single-column one is redundant against all three.
drop index app.runs_user;                -- covered by runs_pull / runs_user_updated / runs_user_state

-- `app.profiles` is keyed BY user_id, so this index was a byte-for-byte duplicate of the primary
-- key's own unique index — the strictest form of the same mistake.
drop index app.profiles_user;            -- duplicates the primary key on (user_id)

-- Plain `drop index`, not `concurrently`: CONCURRENTLY cannot run inside a transaction and the CLI
-- wraps each migration in one. Every table here is empty on every environment, so the ACCESS
-- EXCLUSIVE lock is held for microseconds. **On a populated database, drop these one at a time
-- with `drop index concurrently` outside a migration.**

-- --------------------------------------------------------------------------------------------
-- 2. `service_role` had no statement or idle-in-transaction timeout.
--
-- Migration 0002 set both on `authenticated` and `anon` and did not mention `service_role`, so
-- this is an omission rather than a stated decision — nothing in 0002, §15 or test 6.5b explains
-- excluding it.
--
-- 0002's own rationale applies to `service_role` MORE than to the other two, not less:
--
--   "A single long-lived transaction holds back the vacuum horizon for the ENTIRE database, not
--    just its own rows. One hung mobile client with an open transaction is therefore a
--    cluster-wide bloat event, and this timeout is what turns it into an error instead."
--
-- `service_role` is the role all four Edge Functions run as. `delete-account` and
-- `merge-anonymous` are the only multi-table write paths in the system and both interleave
-- Postgres work with Storage HTTP calls — a Storage call that hangs inside an open transaction is
-- precisely the unbounded idle-in-transaction this timeout exists to bound. It also bypasses RLS,
-- so it is the one role whose runaway query scans everything.
--
-- 60s rather than `authenticated`'s 30s: FR-SET-02 deletion cascades across seven tables plus two
-- Storage objects per photo, and a bounded-but-generous limit is the point. Bounded is the part
-- that matters; the exact number is tunable and this one is a starting value, not a measurement.
alter role service_role set statement_timeout = '60s';
alter role service_role set idle_in_transaction_session_timeout = '60s';

-- Not set on `postgres` or `supabase_admin`: migrations and `db reset` legitimately run long, and
-- a timeout there turns a slow deploy into a half-applied one.
