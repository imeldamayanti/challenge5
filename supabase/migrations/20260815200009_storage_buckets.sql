-- 0009 — Storage is a second authorization system.
-- docs/backend-supabase.md §8.3, §4.7, §14 defect 13.
--
-- Bucket policies are separate objects from table policies and are frequently written for `select`
-- only, leaving insert, update and delete open on a private bucket. All four verbs are needed, on
-- both private buckets, and that is the entire point of this migration.

-- The per-bucket size limit is set explicitly rather than left to config.toml's global
-- `file_size_limit`. A bucket row with a NULL limit is UNLIMITED — it does not inherit the global
-- one — so the 10 MiB in config.toml describes an intention that nothing enforces. Found by test
-- 8.14, which uploaded 11 MiB successfully against a bucket the design believed was capped.
--
-- 10 MiB (§4.7): generous for an already-downscaled 1600 px HEIC derivative at ~250 KB, and low
-- enough that an un-downscaled original is rejected rather than silently accepted.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('trip-photos', 'trip-photos', false, 10485760, array['image/heic','image/jpeg']),
  ('share-cards', 'share-cards', false, 10485760, array['image/png','image/jpeg']),
  -- The published content bundle (§5). Public-read, service-role write. No size limit: a content
  -- bundle is an archive, not a photograph, and it is written by the publish pipeline rather than
  -- by anything a user controls.
  ('content',     'content',     true,  null,     null)
on conflict (id) do nothing;

-- --------------------------------------------------------------------------------------------
-- `storage.foldername(name)[1]` is the first segment of the OBJECT NAME, which excludes the
-- bucket — the reason §4.7 stores paths without a bucket prefix. Both derivatives of a photograph
-- sit under the same `{user_id}/` prefix, so one predicate covers `…/{id}.heic` and
-- `…/{id}_t.heic` together.
-- --------------------------------------------------------------------------------------------
create policy trip_photos_read on storage.objects
  for select to authenticated using (
    bucket_id = 'trip-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- The insert predicate carries §15.3's `deleting` flag as well.
--
-- The design describes it as "a flag the upload path checks before its final PUT" — i.e. client
-- discipline. Enforcing it here instead makes it a rule a client cannot skip, which matters
-- because the failure it prevents (an object landing after FR-SET-02 has deleted its row) is
-- unreachable, undeletable personal data on the one code path where that is least acceptable. The
-- orphan sweeper (§4.7) remains the backstop: this narrows the race, it does not close it.
create policy trip_photos_insert on storage.objects
  for insert to authenticated with check (
    bucket_id = 'trip-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and not exists (
      select 1 from app.profiles p
       where p.user_id = (select auth.uid()) and p.deleting_at is not null
    )
  );

create policy trip_photos_update on storage.objects
  for update to authenticated using (
    bucket_id = 'trip-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  ) with check (
    bucket_id = 'trip-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy trip_photos_delete on storage.objects
  for delete to authenticated using (
    bucket_id = 'trip-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy share_cards_read on storage.objects
  for select to authenticated using (
    bucket_id = 'share-cards'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy share_cards_insert on storage.objects
  for insert to authenticated with check (
    bucket_id = 'share-cards'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy share_cards_update on storage.objects
  for update to authenticated using (
    bucket_id = 'share-cards'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  ) with check (
    bucket_id = 'share-cards'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy share_cards_delete on storage.objects
  for delete to authenticated using (
    bucket_id = 'share-cards'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- The published bundle is meant to be world-readable; its integrity rests on the checksum and, per
-- §14 defect 16, ought to rest on a detached signature as well. No write policy for any client
-- role: the publish pipeline holds the service role, which bypasses RLS.
create policy content_read on storage.objects
  for select to anon, authenticated using (bucket_id = 'content');
