-- 0008 — row-level security.
-- docs/backend-supabase.md §8, §8.1.
--
-- RLS IS NOT ONE DEFENCE AMONG SEVERAL — IT IS THE ONE. The publishable key ships inside every copy
-- of the app and is meant to be public; anyone who installs the app can extract it and speak to
-- PostgREST directly with any query they like. Nothing in the client constrains what reaches the
-- database. A missing policy on one table is that table readable by everybody, and it fails
-- silently because the app's own screens never ask for another user's rows.
--
-- Three details that are easy to get wrong and expensive to discover later:
--   * `(select auth.uid())` rather than bare `auth.uid()` — Postgres caches the scalar sub-select
--     once per statement instead of re-evaluating it per row.
--   * `force row level security`, because the table owner otherwise bypasses its own policies.
--   * `user_id` is denormalised onto every child table (§4.1) so no policy needs a join to
--     app.runs. A recursive `exists` per row is the shape that makes RLS look slow.

alter table app.profiles           enable row level security;
alter table app.profiles           force  row level security;
alter table app.runs               enable row level security;
alter table app.runs               force  row level security;
alter table app.photos             enable row level security;
alter table app.photos             force  row level security;
alter table app.checkpoint_results enable row level security;
alter table app.checkpoint_results force  row level security;
alter table app.task_results       enable row level security;
alter table app.task_results       force  row level security;
alter table app.awards             enable row level security;
alter table app.awards             force  row level security;

-- profiles keys on its primary key, which IS the user id.
create policy profiles_select on app.profiles
  for select using (user_id = (select auth.uid()));
create policy profiles_insert on app.profiles
  for insert with check (user_id = (select auth.uid()));
create policy profiles_update on app.profiles
  for update using (user_id = (select auth.uid()))
              with check (user_id = (select auth.uid()));

create policy runs_select on app.runs
  for select using (user_id = (select auth.uid()));
create policy runs_insert on app.runs
  for insert with check (user_id = (select auth.uid()));
create policy runs_update on app.runs
  for update using (user_id = (select auth.uid()))
              with check (user_id = (select auth.uid()));

create policy photos_select on app.photos
  for select using (user_id = (select auth.uid()));
create policy photos_insert on app.photos
  for insert with check (user_id = (select auth.uid()));
create policy photos_update on app.photos
  for update using (user_id = (select auth.uid()))
              with check (user_id = (select auth.uid()));

create policy checkpoint_results_select on app.checkpoint_results
  for select using (user_id = (select auth.uid()));
create policy checkpoint_results_insert on app.checkpoint_results
  for insert with check (user_id = (select auth.uid()));
create policy checkpoint_results_update on app.checkpoint_results
  for update using (user_id = (select auth.uid()))
              with check (user_id = (select auth.uid()));

create policy task_results_select on app.task_results
  for select using (user_id = (select auth.uid()));
create policy task_results_insert on app.task_results
  for insert with check (user_id = (select auth.uid()));
create policy task_results_update on app.task_results
  for update using (user_id = (select auth.uid()))
              with check (user_id = (select auth.uid()));

create policy awards_select on app.awards
  for select using (user_id = (select auth.uid()));
create policy awards_insert on app.awards
  for insert with check (user_id = (select auth.uid()));
create policy awards_update on app.awards
  for update using (user_id = (select auth.uid()))
              with check (user_id = (select auth.uid()));

-- NO DELETE POLICY ANYWHERE, on any table in `app`, ever. Rows are tombstoned with `deleted_at`
-- (schema.md §C.3 rule 3). 0001 additionally withholds the DELETE grant, so the rule is held twice:
-- once by the grants layer and once by the absence of a policy. FR-SET-02 deletion is a
-- service-role Edge Function (§8), not something a client can reach.
