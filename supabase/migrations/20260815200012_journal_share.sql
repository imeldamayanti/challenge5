-- 0012 — journal entries and share cards.
-- docs/backend-supabase.md §4.6, §4.8, §9.2, §15.5.
--
-- DEVIATION FROM §4.6 AND §4.8, DELIBERATE AND STATED.
-- Neither table's DDL in the design carries the §4.1 sync columns, yet §9.2's corrected push order
-- ends `… → journal_entries → share_cards`, and §15.5 says the pull index is needed "on every
-- syncable table". §4.1 is explicit that these are "columns every syncable table carries". Written
-- as published, both tables would be pushable and then invisible to pull forever — which is
-- exactly the failure b2 §1.7 exists to catch, so shipping it here to stay literal would be
-- shipping a known defect. The sync columns are therefore added, and this note is the record.

create table app.journal_entries (
  id      uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  -- Nullable on purpose: the chart draws Create Journal hanging off the completion screen, but a
  -- journal about a place someone simply passed (the notification branch) has no Run behind it.
  run_id  uuid references app.runs(id) on delete cascade,
  title   text,
  body    text not null default '',

  device_id  uuid not null,
  revision   bigint not null default 1,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  server_seq bigint not null default nextval('app.sync_seq'),
  deleted_at timestamptz
);

create table app.share_cards (
  id           uuid primary key,
  user_id      uuid not null references auth.users(id) on delete cascade,
  run_id       uuid not null references app.runs(id) on delete cascade,
  template     text not null,
  storage_path text not null,
  public_slug  text unique,     -- null until a link is minted
  expires_at   timestamptz,
  -- §14 defect 14 is OPEN: a signed URL already in someone's hands ignores this column until it
  -- expires. Either serve share cards through a function that checks it per request, or keep
  -- signed-URL lifetimes to minutes. Recorded here so the column is not mistaken for a guarantee.
  revoked_at   timestamptz,

  device_id  uuid not null,
  revision   bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  server_seq bigint not null default nextval('app.sync_seq'),
  deleted_at timestamptz
);

create index journal_entries_run  on app.journal_entries (run_id);
create index journal_entries_user on app.journal_entries (user_id);
create index share_cards_run      on app.share_cards (run_id);
create index share_cards_user     on app.share_cards (user_id);

create index journal_user_created on app.journal_entries (user_id, created_at desc);

create index journal_entries_pull on app.journal_entries (user_id, server_seq);
create index share_cards_pull     on app.share_cards     (user_id, server_seq);

create trigger journal_entries_stamp_seq before insert or update on app.journal_entries
  for each row execute function app.stamp_server_seq();
create trigger share_cards_stamp_seq before insert or update on app.share_cards
  for each row execute function app.stamp_server_seq();

create trigger journal_entries_resolve_conflict before update on app.journal_entries
  for each row execute function app.resolve_sync_conflict();
create trigger share_cards_resolve_conflict before update on app.share_cards
  for each row execute function app.resolve_sync_conflict();

alter table app.journal_entries enable row level security;
alter table app.journal_entries force  row level security;
alter table app.share_cards     enable row level security;
alter table app.share_cards     force  row level security;

create policy journal_entries_select on app.journal_entries
  for select using (user_id = (select auth.uid()));
create policy journal_entries_insert on app.journal_entries
  for insert with check (user_id = (select auth.uid()));
create policy journal_entries_update on app.journal_entries
  for update using (user_id = (select auth.uid()))
              with check (user_id = (select auth.uid()));

create policy share_cards_select on app.share_cards
  for select using (user_id = (select auth.uid()));
create policy share_cards_insert on app.share_cards
  for insert with check (user_id = (select auth.uid()));
create policy share_cards_update on app.share_cards
  for update using (user_id = (select auth.uid()))
              with check (user_id = (select auth.uid()));

-- The `share-cards` bucket and all four of its storage policies were created in 0009, alongside
-- `trip-photos`, so that no private bucket ever exists without a policy on every verb (§8.3).
-- b1 §3 lists the share-card storage policy against this migration; putting it with the bucket is
-- the safer ordering and the only difference is which file it lives in.

-- ============================================================================================
-- Service-role routines.
--
-- They live at the end of the last migration because each one has to see every table it touches.
--
-- §7.3 rejects a `security definer` SQL function that rewrites `user_id`, on the grounds that its
-- "entire safety rests on argument validation inside plpgsql, and plpgsql cannot verify a JWT
-- signature". That objection is answered here by the EXECUTE grant rather than by argument
-- validation: nothing a client can hold — `anon` or `authenticated` — may call these at all. The
-- Edge Function verifies BOTH tokens through the auth admin API and only then calls in with two
-- uids it has actually proven. Neither uid is ever read from a request body.
-- ============================================================================================

-- §7.3 — move an anonymous identity's rows onto a real account.
create or replace function app.merge_anonymous_rows(anon_uid uuid, target_uid uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  moved_runs int := 0;
  dropped_awards int := 0;
  r record;
  keep_anon boolean;
begin
  if anon_uid = target_uid then
    raise exception 'refusing to merge an identity into itself' using errcode = 'PT400';
  end if;

  -- Rule 2: `runs_one_active_per_quest` WILL collide — the same quest may be active on both
  -- identities. Resolved exactly as §9.5 resolves the sync case: keep the Run with more
  -- checkpoint_results (ties to the earlier started_at), abandon the other. NEVER delete either;
  -- the abandoned Run keeps its snapshots and still renders.
  for r in
    select a.id as anon_run, t.id as target_run,
           (select count(*) from app.checkpoint_results c where c.run_id = a.id) as anon_cps,
           (select count(*) from app.checkpoint_results c where c.run_id = t.id) as target_cps,
           a.started_at as anon_started, t.started_at as target_started
      from app.runs a
      join app.runs t
        on t.quest_id = a.quest_id
       and t.user_id  = target_uid
       and t.state    = 'active'
       and t.deleted_at is null
     where a.user_id = anon_uid
       and a.state = 'active'
       and a.deleted_at is null
  loop
    keep_anon := (r.anon_cps > r.target_cps)
                 or (r.anon_cps = r.target_cps and r.anon_started < r.target_started);

    if keep_anon then
      update app.runs
         set state = 'abandoned', abandoned_at = now(), abandon_reason = 'userChoice',
             revision = revision + 1, updated_at = now()
       where id = r.target_run;
    else
      update app.runs
         set state = 'abandoned', abandoned_at = now(), abandon_reason = 'userChoice',
             revision = revision + 1, updated_at = now()
       where id = r.anon_run;
    end if;
  end loop;

  -- Rule 3: `awards_one_per_source` collides on anything earned under both identities. Only the
  -- run_id-null rows (cross-quest badges and every letter) can collide across identities, since a
  -- run belongs to one of them. Keep the earlier awarded_at; DROP the duplicate rather than
  -- tombstoning it — it was never a distinct award.
  with dup as (
    select a.id
      from app.awards a
      join app.awards t
        on t.user_id = target_uid
       and t.run_id is null
       and t.type = a.type
       and t.source_id = a.source_id
       and t.deleted_at is null
     where a.user_id = anon_uid
       and a.run_id is null
       and a.deleted_at is null
       and t.awarded_at <= a.awarded_at
  )
  delete from app.awards where id in (select id from dup);
  get diagnostics dropped_awards = row_count;

  update app.runs               set user_id = target_uid where user_id = anon_uid;
  get diagnostics moved_runs = row_count;
  -- Rule 4's other half: an object name begins with the owner's uid (§4.7, §8.3), so a row whose
  -- path still starts with the anonymous uid points somewhere §8.3's policy no longer grants. The
  -- Edge Function copies the bytes to the new prefix BEFORE calling this, and deletes the originals
  -- after, so an interruption at any point leaves the original readable.
  --
  -- `revision` is bumped rather than left alone, for two reasons that turn out to be the same
  -- reason. It is a real change the walker's other devices must pull. And app.resolve_sync_conflict
  -- reads an update with an unchanged revision and an unchanged device_id as an idempotent retry
  -- and returns NULL, so a rewrite that did not bump it would be silently discarded — which is
  -- exactly what happened until test 05's last two assertions caught it.
  update app.photos
     set storage_path = target_uid::text || substring(storage_path from length(anon_uid::text) + 1),
         thumb_path   = case when thumb_path is null then null
                             else target_uid::text || substring(thumb_path from length(anon_uid::text) + 1) end,
         revision = revision + 1,
         updated_at = now()
   where user_id = anon_uid
     and storage_path is not null
     and storage_path like anon_uid::text || '/%';
  update app.share_cards
     set storage_path = target_uid::text || substring(storage_path from length(anon_uid::text) + 1),
         revision = revision + 1,
         updated_at = now()
   where user_id = anon_uid
     and storage_path like anon_uid::text || '/%';
  update app.photos             set user_id = target_uid where user_id = anon_uid;
  update app.checkpoint_results set user_id = target_uid where user_id = anon_uid;
  update app.task_results       set user_id = target_uid where user_id = anon_uid;
  update app.awards             set user_id = target_uid where user_id = anon_uid;
  update app.journal_entries    set user_id = target_uid where user_id = anon_uid;
  update app.share_cards        set user_id = target_uid where user_id = anon_uid;
  update app.sync_conflicts     set user_id = target_uid where user_id = anon_uid;
  delete from app.profiles where user_id = anon_uid;

  -- Rule 5: the anonymous auth.users row goes last, in the same transaction as the moves. By this
  -- point it owns nothing, so the cascade removes nothing.
  delete from auth.users where id = anon_uid and is_anonymous;

  return jsonb_build_object('moved_runs', moved_runs, 'dropped_duplicate_awards', dropped_awards);
end $$;

revoke all on function app.merge_anonymous_rows(uuid, uuid) from public, anon, authenticated;
grant execute on function app.merge_anonymous_rows(uuid, uuid) to service_role;

-- FR-SET-02, step 3 — hard-delete rows leaf-first, in bounded batches.
-- §15.2: `delete from auth.users` cascades through every table in one statement, taking every lock
-- at once. For a heavy user that is a long transaction blocking their own sync. The Edge Function
-- calls this repeatedly and commits between calls.
create or replace function app.delete_account_batch(target_uid uuid, batch_size int default 500)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  removed int := 0;
  n int;
  children int;
begin
  delete from app.task_results
   where id in (select id from app.task_results where user_id = target_uid limit batch_size);
  get diagnostics n = row_count; removed := removed + n;

  delete from app.checkpoint_results
   where id in (select id from app.checkpoint_results where user_id = target_uid limit batch_size);
  get diagnostics n = row_count; removed := removed + n;

  delete from app.share_cards
   where id in (select id from app.share_cards where user_id = target_uid limit batch_size);
  get diagnostics n = row_count; removed := removed + n;

  delete from app.journal_entries
   where id in (select id from app.journal_entries where user_id = target_uid limit batch_size);
  get diagnostics n = row_count; removed := removed + n;

  delete from app.awards
   where id in (select id from app.awards where user_id = target_uid limit batch_size);
  get diagnostics n = row_count; removed := removed + n;

  delete from app.photos
   where id in (select id from app.photos where user_id = target_uid limit batch_size);
  get diagnostics n = row_count; removed := removed + n;

  delete from app.sync_conflicts
   where id in (select id from app.sync_conflicts where user_id = target_uid limit batch_size);
  get diagnostics n = row_count; removed := removed + n;

  -- The parent goes ONLY once every child is gone.
  --
  -- Deleting app.runs first would cascade through all of them in one statement, which is precisely
  -- the unbounded lock §15.2 rules out — and it would make the batch size a fiction, since one
  -- "bounded" call would finish the whole account. Test 6.7b caught exactly that.
  if not exists (select 1 from app.task_results       where user_id = target_uid)
     and not exists (select 1 from app.checkpoint_results where user_id = target_uid)
     and not exists (select 1 from app.share_cards        where user_id = target_uid)
     and not exists (select 1 from app.journal_entries    where user_id = target_uid)
     and not exists (select 1 from app.awards             where user_id = target_uid)
     and not exists (select 1 from app.photos             where user_id = target_uid)
  then
    children := 0;
  else
    children := 1;
  end if;

  if children = 0 then
    delete from app.runs
     where id in (select id from app.runs where user_id = target_uid limit batch_size);
    get diagnostics n = row_count; removed := removed + n;

    if not exists (select 1 from app.runs where user_id = target_uid) then
      delete from app.profiles where user_id = target_uid;
      get diagnostics n = row_count; removed := removed + n;
    end if;
  end if;

  return removed;
end $$;

revoke all on function app.delete_account_batch(uuid, int) from public, anon, authenticated;
grant execute on function app.delete_account_batch(uuid, int) to service_role;

-- §7.4 — the cull predicate, written once so nobody reaches for the default cron.
-- Anonymous users are billable MAU and Supabase's own guidance is to delete unused ones. Running
-- that as written would silently delete the synced walks of exactly the population §7.2 identifies
-- as unrecoverable: people who never registered and whose device is their only other copy.
-- An anonymous user with a single Run is never culled, AT ANY AGE.
create or replace function app.anonymous_cull_candidates(older_than interval default '90 days')
returns table (user_id uuid)
language sql
security definer
set search_path = ''
as $$
  select u.id
    from auth.users u
   where u.is_anonymous
     and u.last_sign_in_at < now() - older_than
     and not exists (select 1 from app.runs            r where r.user_id = u.id)
     and not exists (select 1 from app.journal_entries j where j.user_id = u.id)
     and not exists (select 1 from app.photos          p where p.user_id = u.id);
$$;

revoke all on function app.anonymous_cull_candidates(interval) from public, anon, authenticated;
grant execute on function app.anonymous_cull_candidates(interval) to service_role;
