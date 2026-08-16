-- 0005 — the pull cursor.
-- docs/backend-supabase.md §4.1, §9.3, §14 defects 1–3, §8.1 case 3.
--
-- `server_seq` is the load-bearing column of the whole sync protocol and it is NOT a timestamp.
-- `created_at` and `updated_at` arrive from the device — they are what the walker's phone believed
-- the time was — so neither can order a pull. A phone three days slow writes a row stamped in the
-- past, another device's cursor is already beyond it, and that row is never pulled by anybody,
-- ever. A server timestamp does not fix it either: `now()` is transaction-start time, so a slow
-- transaction can commit a row whose stamp is older than a cursor that has already passed.

create sequence app.sync_seq;

-- This grant is the whole reason `security definer` looked necessary on the trigger below.
grant usage on sequence app.sync_seq to authenticated;
grant usage on sequence app.sync_seq to service_role;

-- One shared sequence rather than one per table, so a single cursor per table still works while
-- gaps (from rolled-back transactions) stay harmless — the reader only ever asks for GREATER THAN,
-- never for "the next one".

-- NOT `security definer`. A BEFORE trigger already sets the value regardless of what the caller
-- sent, so definer rights buy nothing and only widen the blast radius (§8.1 case 3).
-- `set search_path = ''` is mandatory on anything that could be one (§8.1 case 3), and costs
-- nothing here.
create or replace function app.stamp_server_seq() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.server_seq := nextval('app.sync_seq');
  return new;
end $$;

comment on function app.stamp_server_seq() is
  'Overwrites server_seq on every insert and update. The client cannot write this column: whatever arrives is discarded (design §4.1).';
