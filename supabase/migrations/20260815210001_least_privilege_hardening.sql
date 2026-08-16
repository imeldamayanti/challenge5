-- 0013 — least privilege on trigger functions, and policies scoped to a role.
--
-- Forward-only (b0 D2): the first push to the hosted project surfaced two Supabase advisors that
-- the local stack does not run, and the fix is a new migration rather than an edit to a merged one.
--
-- Neither is exploitable as it stands. Both are the kind of thing that stops being true quietly.

-- --------------------------------------------------------------------------------------------
-- Advisor 0028 / 0029 — "Public Can Execute SECURITY DEFINER Function".
--
-- Postgres grants EXECUTE on a new function to PUBLIC by default, so both trigger functions were
-- callable as `/rest/v1/rpc/…` by `anon` and `authenticated`. Calling a trigger function directly
-- fails at runtime ("can only be called as trigger"), which is why this was a warning rather than a
-- hole — but app.resolve_sync_conflict is `security definer` (§9.4 needs it to write past
-- sync_conflicts' forced RLS), and a definer function reachable from the public API is exactly the
-- shape §8.1 case 3 warns about. Least privilege is cheaper than the argument.
-- --------------------------------------------------------------------------------------------
revoke all on function app.resolve_sync_conflict() from public, anon, authenticated;
revoke all on function app.stamp_server_seq()     from public, anon, authenticated;
revoke all on function ops.rebuild_suppressions_document() from public, anon, authenticated;

-- Triggers execute as the table owner's rights on the trigger itself, not through the caller's
-- EXECUTE privilege, so the sync path is unaffected — proved by the full suite re-run after this.

-- --------------------------------------------------------------------------------------------
-- Advisor 0012 — "Anonymous Access Policies".
--
-- The policies in 0008 and 0012 carry no `TO` clause, which means PUBLIC — including `anon`. In
-- practice `anon` cannot reach these tables at all: 0001 revokes every grant and the USAGE on the
-- schema, and RLS is only consulted after the grants layer lets a role through. But a policy that
-- names a role it does not intend is a policy that stops matching the grants the day somebody
-- "fixes" a permission error with a `grant`.
--
-- `authenticated` is the right and only audience: design §7's anonymous walker holds a real JWT and
-- is `authenticated` as far as Postgres roles are concerned — `is_anonymous` is a claim, not a role.
-- --------------------------------------------------------------------------------------------
do $$
declare
  p record;
begin
  for p in
    select schemaname, tablename, policyname, cmd,
           pg_get_expr(pol.polqual, pol.polrelid)      as using_expr,
           pg_get_expr(pol.polwithcheck, pol.polrelid) as check_expr
      from pg_policies pg
      join pg_policy pol on pol.polname = pg.policyname
      join pg_class c on c.oid = pol.polrelid and c.relname = pg.tablename
      join pg_namespace n on n.oid = c.relnamespace and n.nspname = pg.schemaname
     where pg.schemaname = 'app'
       and pg.roles = '{public}'
  loop
    execute format('drop policy %I on %I.%I', p.policyname, p.schemaname, p.tablename);
    execute format(
      'create policy %I on %I.%I for %s to authenticated %s %s',
      p.policyname, p.schemaname, p.tablename, lower(p.cmd),
      case when p.using_expr is null then '' else 'using (' || p.using_expr || ')' end,
      case when p.check_expr is null then '' else 'with check (' || p.check_expr || ')' end
    );
  end loop;
end $$;

-- app.sync_conflicts' insert policy is `to postgres` already (0011) and is skipped by the filter
-- above, which is the intent: it exists only so the definer trigger can write past forced RLS, and
-- PostgREST never connects as `postgres`.
