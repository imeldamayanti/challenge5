-- 0018 — the autovacuum tuning two tables never received.
-- docs/backend-supabase.md §15.7. Additive: two `alter table … set (…)`, no data touched.
--
-- Migration 0010 tuned the five syncable tables that existed when it was written. Migration 0012
-- then added `app.journal_entries` and `app.share_cards` — both fully syncable, both carrying
-- `server_seq`, `revision` and `deleted_at` — and did not tune them. Nothing connected the two,
-- because 0012 was about a feature and 0010 was about vacuum.
--
-- This is the second instance of the same shape found today. Migration 0002 set timeouts on
-- `authenticated` and `anon` and never covered `service_role` (fixed in 0016). Both are a tuning
-- migration that enumerated the tables/roles present at the time, and a later migration adding one
-- more without knowing it was on a list. **The guard at the end of this file is the actual fix**;
-- the two ALTERs below are just the arrears.
--
-- §15.7's reasoning applies to these two identically, and to journal_entries most of all:
--
--   * tombstones mean rows are never removed (`schema.md` §C.3 rule 3), so tables only grow;
--   * every sync update bumps the INDEXED `server_seq`, which rules out a HOT update and leaves a
--     dead tuple plus fresh index entries on each write;
--   * a journal entry is EDITED — title and body, repeatedly, by a walker writing up a trip — so
--     it takes more updates per row than anything else in this schema. It is the table that most
--     needed the tuning and the one that went without it.
--
-- The default `autovacuum_vacuum_scale_factor` of 0.2 waits until a FIFTH of the table is dead
-- before collecting. On an append-and-update table with tombstones that is a lot of bloat held for
-- a long time, and the index entries are held with it.

alter table app.journal_entries set (
  autovacuum_vacuum_scale_factor  = 0.05,
  autovacuum_analyze_scale_factor = 0.02
);

alter table app.share_cards set (
  autovacuum_vacuum_scale_factor  = 0.05,
  autovacuum_analyze_scale_factor = 0.02
);

-- No tuning for `app.profiles`: one row per user, updated rarely, and it has no `server_seq` at
-- all — it is not part of the delta-sync set, which is why the guard keys on that column rather
-- than on a hand-maintained list of table names. A list is what produced this migration.
--
-- Nor for `app.sync_conflicts`: server-authored, insert-only, and read once. It has no `server_seq`
-- either, so the guard correctly ignores it.
