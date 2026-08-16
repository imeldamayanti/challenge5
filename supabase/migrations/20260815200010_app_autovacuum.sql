-- 0010 — autovacuum settings on the sync tables.
-- docs/backend-supabase.md §15.7, §4.1.
--
-- Postgres does not leak memory the way a process does. It leaks dead tuples, and this schema is
-- unusually exposed to it for three reasons that are all deliberate:
--   * tombstones mean rows are never removed (schema.md §C.3 rule 3), so tables only grow;
--   * every sync update bumps the indexed `server_seq`, which rules out the HOT (heap-only tuple)
--     path and leaves a dead tuple plus fresh index entries on each write (§4.1);
--   * the snapshot columns are wide, so each dead tuple is expensive rather than incidental.
--
-- The default scale factor of 0.2 waits until a fifth of the table is dead before vacuuming, which
-- on an append-and-tombstone schema means the bloat is already paid for by the time it is noticed.

alter table app.runs set (
  autovacuum_vacuum_scale_factor  = 0.05,
  autovacuum_analyze_scale_factor = 0.02
);
alter table app.checkpoint_results set (
  autovacuum_vacuum_scale_factor  = 0.05,
  autovacuum_analyze_scale_factor = 0.02
);
alter table app.task_results set (
  autovacuum_vacuum_scale_factor  = 0.05,
  autovacuum_analyze_scale_factor = 0.02
);
alter table app.awards set (
  autovacuum_vacuum_scale_factor  = 0.05,
  autovacuum_analyze_scale_factor = 0.02
);
alter table app.photos set (
  autovacuum_vacuum_scale_factor  = 0.05,
  autovacuum_analyze_scale_factor = 0.02
);
