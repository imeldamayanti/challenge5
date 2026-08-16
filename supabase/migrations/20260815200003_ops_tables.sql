-- 0003 — `ops`: kill-switch, telemetry, survey.
-- docs/backend-supabase.md §6.1, §6.2, §2.4.
--
-- Neither ops.events nor ops.survey_responses has a user_id, and neither should ever acquire one.
-- NFR-PRIV-02/03/05 are enforced by the absence of columns, not by a policy somebody remembers.

-- --------------------------------------------------------------------------------------------
-- §6.1 Kill-switch (AD-5)
-- --------------------------------------------------------------------------------------------
create table ops.suppressions (
  -- 'sidequest' is present from the start: s3 §7 gives the kill-switch authority over sidequests,
  -- and FR-SIDE-14 deregisters a withdrawn one on next launch. The letter it already awarded is
  -- retained — the record is a snapshot and the walk happened.
  entity_type   text not null check (entity_type in ('place','quest','sidequest')),
  entity_id     text not null,
  reason        text not null,
  suppressed_at timestamptz not null default now(),
  released_at   timestamptz,
  primary key (entity_type, entity_id)
);

-- --------------------------------------------------------------------------------------------
-- §6.2 Telemetry and survey — the anonymous tier
-- --------------------------------------------------------------------------------------------
create table ops.events (
  id             uuid primary key,          -- UUIDv7, minted on device (§2.3, b0 D8)
  name           text not null,
  params         jsonb not null default '{}',
  run_key        uuid,                      -- pseudonymous, per Run (§2.4). Never joins to app.runs
  schema_version int not null,
  occurred_at    timestamptz not null,
  received_at    timestamptz not null default now()
);

create table ops.survey_responses (
  id          uuid primary key,
  run_key     uuid,
  quest_id    text,
  question_id text not null,
  response    text not null,
  occurred_at timestamptz not null,
  received_at timestamptz not null default now()
);

-- BRIN, not B-tree. These tables are append-only and `received_at` is monotonic, so physical row
-- order already correlates with time — the exact case BRIN exists for. Kilobytes where a B-tree
-- would be megabytes, and adequate for both the retention delete (§15.7) and time-range analytics.
create index events_received_brin on ops.events           using brin (received_at);
create index survey_received_brin on ops.survey_responses using brin (received_at);

-- GIN, because this jsonb IS queried — analytics filters on `params->>'questID'` and friends.
-- `jsonb_path_ops` is smaller and faster than the default operator class when containment (@>) is
-- all that is needed, which it is. Contrast app.checkpoint_results.snapshot_lore (§4.4), which is
-- never queried and must never be indexed.
create index events_params_gin on ops.events using gin (params jsonb_path_ops);

create index events_name_time on ops.events (name, occurred_at);

-- --------------------------------------------------------------------------------------------
-- RLS on `ops` with no policies at all.
--
-- Design §8 says "`ops`: no client policies at all; the ingest function uses the service role."
-- `ops` is already unreachable over PostgREST (config.toml `[api] schemas = ["app"]`) and has no
-- grants to anon or authenticated (0001). Enabling and forcing RLS with zero policies is a third,
-- free layer: if either of the other two is ever undone by mistake, these tables still deny
-- everything to every role that does not carry BYPASSRLS — which is service_role and nothing that
-- ships in the app.
-- --------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------
-- The write path for `POST /functions/v1/ingest` (b0 D7, design §6.2).
--
-- It lives in `app` rather than `ops` because PostgREST only routes to exposed schemas, and `ops`
-- is deliberately not one (b0 D1). EXECUTE is granted to `service_role` alone, so the only caller
-- that can reach it is the Edge Function holding the service key — anon and authenticated get a
-- permission error, which is what keeps §6.2's rejection of "insert-only RLS for anon" intact.
--
-- The alternative was a direct Postgres connection from the function through the transaction
-- pooler (§15.6). This shape needs no third-party driver in the function at all, and the caps are
-- then enforced in two places rather than one.
create or replace function app.ingest_batch(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  ev       jsonb;
  sr       jsonb;
  n_events int := jsonb_array_length(coalesce(payload->'events', '[]'::jsonb));
  n_survey int := jsonb_array_length(coalesce(payload->'survey_responses', '[]'::jsonb));
begin
  -- §9.1's reasoning applied to telemetry: a row that arrives in an unknown shape is rejected
  -- rather than stored, because a stored one is noise in a chart nobody can later identify.
  if (payload->>'schema_version') is null or (payload->>'schema_version')::int <> 1 then
    raise exception 'unknown schema_version %', payload->>'schema_version'
      using errcode = 'PT400';
  end if;

  if n_events + n_survey > 200 then
    raise exception 'batch of % rows exceeds the cap of 200', n_events + n_survey
      using errcode = 'PT400';
  end if;

  for ev in select * from jsonb_array_elements(coalesce(payload->'events', '[]'::jsonb))
  loop
    -- `user_id` is ignored if a client sends one: ops.events has no such column and must never
    -- acquire one (§2.4). Named columns rather than jsonb_populate_record is what makes that true.
    insert into ops.events (id, name, params, run_key, schema_version, occurred_at)
    values (
      (ev->>'id')::uuid,
      ev->>'name',
      coalesce(ev->'params', '{}'::jsonb),
      nullif(ev->>'run_key','')::uuid,
      (payload->>'schema_version')::int,
      (ev->>'occurred_at')::timestamptz
    )
    on conflict (id) do nothing;    -- a retried flush is not a duplicate row
  end loop;

  for sr in select * from jsonb_array_elements(coalesce(payload->'survey_responses', '[]'::jsonb))
  loop
    insert into ops.survey_responses (id, run_key, quest_id, question_id, response, occurred_at)
    values (
      (sr->>'id')::uuid,
      nullif(sr->>'run_key','')::uuid,
      sr->>'quest_id',
      sr->>'question_id',
      sr->>'response',
      (sr->>'occurred_at')::timestamptz
    )
    on conflict (id) do nothing;
  end loop;

  return jsonb_build_object('accepted_events', n_events, 'accepted_survey', n_survey);
end $$;

revoke all on function app.ingest_batch(jsonb) from public, anon, authenticated;
grant execute on function app.ingest_batch(jsonb) to service_role;

alter table ops.suppressions      enable row level security;
alter table ops.suppressions      force  row level security;
alter table ops.events            enable row level security;
alter table ops.events            force  row level security;
alter table ops.survey_responses  enable row level security;
alter table ops.survey_responses  force  row level security;
