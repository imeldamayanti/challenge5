-- 0007 — indexes.
-- docs/backend-supabase.md §15.5, §4.3, §4.4, §4.5, §4.7, §14 defects 4 and 10.
--
-- Before 0008 on purpose (b1 §3), so the policies are never evaluated against unindexed columns
-- during the migration run itself.
--
-- Postgres does NOT index foreign key columns automatically. Every `on delete cascade` in §4
-- resolves by scanning the child table for matching parent ids, so without these, deleting one
-- user sequentially scans every table. These are not precautionary; they are the difference
-- between a linear and a quadratic account deletion (FR-SET-02).

create index checkpoint_results_run  on app.checkpoint_results (run_id);
create index task_results_checkpoint on app.task_results (checkpoint_result_id);
create index task_results_run        on app.task_results (run_id);
-- Earns its place twice: the `on delete set null` in §4.5 also scans without it.
create index task_results_photo      on app.task_results (photo_id);
create index awards_run              on app.awards (run_id);
create index photos_run              on app.photos (run_id);

-- The user_id foreign key on every table, for the auth.users cascade (b2 §7.3).
create index profiles_user           on app.profiles (user_id);
create index runs_user               on app.runs (user_id);
create index photos_user             on app.photos (user_id);
create index checkpoint_results_user on app.checkpoint_results (user_id);
create index task_results_user       on app.task_results (user_id);
create index awards_user             on app.awards (user_id);

-- --------------------------------------------------------------------------------------------
-- §9.3's pull: filters on user_id, orders by server_seq. Needed on EVERY syncable table — §15.5
-- notes only runs and checkpoint_results had it written out.
-- --------------------------------------------------------------------------------------------
create index runs_pull               on app.runs               (user_id, server_seq);
create index photos_pull             on app.photos             (user_id, server_seq);
create index checkpoint_results_pull on app.checkpoint_results (user_id, server_seq);
create index task_results_pull       on app.task_results       (user_id, server_seq);
create index awards_pull             on app.awards             (user_id, server_seq);

-- --------------------------------------------------------------------------------------------
-- Partial uniques. Every one of these is partial on `deleted_at is null` for the same reason
-- (§14 defect 10): a plain unique lets a soft-deleted row occupy its own key forever, so the
-- walker could never re-arrive at a checkpoint whose result had been tombstoned.
-- --------------------------------------------------------------------------------------------

-- FR-START-06, at last expressible as a constraint. SwiftData could not state this
-- (schema.md §B.2) and RunEngine holds it in code; Postgres can hold it as well.
create unique index runs_one_active_per_quest
  on app.runs (user_id, quest_id)
  where state = 'active' and deleted_at is null;

create unique index checkpoint_results_one_per_checkpoint
  on app.checkpoint_results (run_id, checkpoint_id)
  where deleted_at is null;

create unique index task_results_one_per_task
  on app.task_results (checkpoint_result_id, task_id)
  where deleted_at is null;

-- NULLS NOT DISTINCT, because run_id is null for cross-quest badges and for EVERY letter — the
-- exact rows this constraint exists to protect. Postgres treats NULLs as distinct by default, so a
-- plain unique would let them duplicate without limit (§14 defect 4). It is also what makes
-- §15.3's double-tap guarantee true for letters rather than only for stamps.
create unique index awards_one_per_source
  on app.awards (user_id, run_id, type, source_id)
  nulls not distinct
  where deleted_at is null;

-- --------------------------------------------------------------------------------------------
-- Query-shape indexes named in §4.3 and §4.7.
-- --------------------------------------------------------------------------------------------
create index runs_user_updated on app.runs (user_id, updated_at);
create index runs_user_state   on app.runs (user_id, state, completed_at desc);

create index photos_pending_upload on app.photos (user_id, captured_at)
  where uploaded_at is null and deleted_at is null;
