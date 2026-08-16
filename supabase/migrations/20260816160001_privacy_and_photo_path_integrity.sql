-- 0015 — two defects found by reading the schema back after deployment.
-- docs/backend-supabase.md §2.4 and §4.7. NFR-PRIV-02/03/05, FR-SET-02, FR-SET-03, NFR-OBS-06.
--
-- Forward-only (b0 D2). Both tables are empty on every environment, so both changes are free now
-- and neither is free later — which is the whole reason to do them before the first real user.
--
-- NOT ADDITIVE. This migration drops a column. It is the first one that does, and the drop is
-- stated here rather than buried: `app.checkpoint_results.lore_dwell_ms` has never been written by
-- anything, and no client type has ever had a field for it.

-- --------------------------------------------------------------------------------------------
-- 1. Telemetry must not sit on a row that names a person (§2.4).
--
-- §2.4: "Signing in must not deanonymise the measurement apparatus… NFR-PRIV-02/03/05 are enforced
-- by the ABSENCE OF COLUMNS, not by a policy somebody has to remember."
--
-- `lore_dwell_ms` is a measurement, and it sat on `app.checkpoint_results`, whose every row carries
-- `user_id not null`. That is the one thing §2.4 says the schema must make impossible, and it was
-- reachable by a single UPDATE. Nothing exploited it because nothing ever wrote the column — but
-- "no writer yet" is a fact about today, and the sentence above is a promise about the design.
--
-- NFR-OBS-06 (per-checkpoint dwell MUST be instrumented) is unaffected: `schema.md` §B.7 already
-- specifies the `checkpoint_departed` event carrying `{checkpointID, dwellMs}` into `ops.events`,
-- which has no `user_id` column and never will. The metric survives; the join back to a person
-- does not exist to be made. The PRD's data model (§6, CheckpointResult) is amended to match.
--
-- `lore_first_opened_at` STAYS. It is not a duration — it is the FR-CP-04 fact that the lore was
-- opened, which the summary and the award rules read, and `RunEngine.markLoreOpened` writes it.
alter table app.checkpoint_results drop column lore_dwell_ms;

-- --------------------------------------------------------------------------------------------
-- 2. A photo row with no path is an object nobody can delete (§4.7).
--
-- §4.7's upload ordering is explicit about step 1:
--
--     1. insert app.photos   — storage_path and thumb_path SET, uploaded_at NULL
--     2. PUT the thumb   3. PUT the full   4. update … uploaded_at = now()
--
-- and explains why: "the paths are deterministic from `id`, and a failure leaves a row with
-- `uploaded_at` null, which is resumable and visible."
--
-- The DDL in the same document left both paths nullable, and this schema faithfully copied it. So
-- the design contradicted itself, and the nullable half won. A row with a null `storage_path` is
-- NOT resumable — there is no path to resume to — and FR-SET-02's deletion, which §4.7 requires to
-- "delete by path unconditionally rather than branching on `uploaded_at`", has nothing to delete
-- by. The bytes, if any were ever written, stay.
--
-- §4.7 names that outcome itself: "leaving one behind is a privacy failure that passes every
-- database test." This is that failure, in the column definitions, one UPDATE away.
--
-- Set directly rather than through the `not valid` → `validate` dance of §15.3: that pattern exists
-- to avoid a full-table scan under ACCESS EXCLUSIVE, and both tables hold zero rows on every
-- environment. **If either table ever holds rows, use the two-step pattern instead** — a direct
-- SET NOT NULL on a populated table takes ACCESS EXCLUSIVE for the length of a full scan.
alter table app.photos alter column storage_path set not null;
alter table app.photos alter column thumb_path   set not null;

comment on column app.photos.storage_path is
  'Deterministic from id: {user_id}/{run_id}/{id}.heic. NOT NULL because §4.7 writes the row before the bytes and FR-SET-02 deletes by path unconditionally — a null here is an object nothing can find or erase.';
comment on column app.photos.thumb_path is
  'Deterministic from id: {user_id}/{run_id}/{id}_t.heic. NOT NULL for the same reason as storage_path — FR-SET-02 deletes BOTH objects per row.';

-- --------------------------------------------------------------------------------------------
-- Deliberately NOT changed, so the next reader does not have to re-derive it:
--
-- `byte_size`, `width_px`, `height_px`, `content_type` stay nullable. A null `byte_size` does make
-- FR-SET-03's storage report under-count silently (SUM skips nulls), which is a real if smaller
-- problem — but unlike the paths, it is not clear from any document that the device knows these at
-- INSERT time rather than after encoding, and tightening them on a guess would trade a quiet
-- under-count for a hard insert failure on the capture path. Left as a known gap.
--
-- `run_id` stays nullable: a photo can outlive the deletion of its Run, and the cascade only fires
-- when it is set.
--
-- The four `snapshot_*` columns on app.checkpoint_results stay exactly as they are. They were
-- examined in the same pass and are correct: AD-4 requires a summary to render forever after
-- content is corrected or a place withdrawn, `snapshot_lore` is documented as never indexed, and
-- splitting them into a 1:1 table would buy a join on the one read path that always wants them.
