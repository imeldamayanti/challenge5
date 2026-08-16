// b2 §6 — concurrency and locking, plus §4.2.7's cursor window.
// docs/backend-supabase.md §15.2, §15.3, §15.4, §15.7, §9.3.
//
// These are the tests that need two sessions, and they are the only ones that catch failures which
// appear exclusively in production. pgTAP runs inside a single transaction, so they cannot live
// there: a deadlock needs two transactions taking the same locks in opposite orders, and a
// transaction that commits behind a reader needs a reader.
//
// dblink was the obvious alternative and does not work here: the local stack authenticates
// host connections with `trust`, and dblink refuses to connect as a non-superuser unless the
// password it is given is actually used by the server. So each session is a real psql process in
// the database container.
//
// 6.4 (the deleting flag) is proved in tests/functions/storage.test.ts, where the upload it blocks
// actually happens. 6.7 (a heavy account deletion) is in tests/functions/delete_account.test.ts.

import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { dbContainer, sql } from "../_helpers.ts";

interface Result {
  code: number;
  out: string;
  err: string;
}

async function psql(script: string): Promise<Result> {
  const container = await dbContainer();
  const cmd = new Deno.Command("docker", {
    args: ["exec", "-i", container, "psql", "-U", "postgres", "-d", "postgres", "-At", "-q"],
    stdin: "piped",
    stdout: "piped",
    stderr: "piped",
  });
  const child = cmd.spawn();
  const writer = child.stdin.getWriter();
  await writer.write(new TextEncoder().encode(script));
  await writer.close();
  const { code, stdout, stderr } = await child.output();
  return {
    code,
    out: new TextDecoder().decode(stdout).trim(),
    err: new TextDecoder().decode(stderr).trim(),
  };
}

const USER_A = "11111111-1111-4111-8111-111111111111";
const DEVICE = "99999999-9999-4999-8999-999999999999";

async function freshRun(): Promise<string> {
  const id = crypto.randomUUID();
  await sql(`
    insert into app.runs (id, user_id, quest_id, content_version, language, state, started_at,
                          device_id, created_at, updated_at)
    values ('${id}', '${USER_A}', 'concurrency-${id.slice(0, 8)}', '1', 'id', 'active', now(),
            '${DEVICE}', now(), now())
  `);
  return id;
}

async function dropRun(id: string): Promise<void> {
  await sql(`delete from app.runs where id = '${id}'`);
}

Deno.test("6.1 two simultaneous pushes of the same award produce exactly one row", async () => {
  // §15.3: SideQuestEngine.answerQuiz awards at most one letter ever, held by tests in `swift
  // test`. The server's half is awards_one_per_source — with `nulls not distinct`, so it actually
  // applies to letters. This is that half.
  const runId = await freshRun();
  const source = `stamp-race-${crypto.randomUUID().slice(0, 8)}`;
  const award = (id: string) => `
    insert into app.awards (id, user_id, run_id, type, source_id, snapshot_name, awarded_at,
                            device_id, created_at, updated_at)
    values ('${id}', '${USER_A}', '${runId}', 'stamp', '${source}', 'S', now(), '${DEVICE}',
            now(), now());`;

  const first = psql(`begin;${award(crypto.randomUUID())} select pg_sleep(1); commit;`);
  const second = psql(`select pg_sleep(0.3);${award(crypto.randomUUID())}`);
  const [a, b] = await Promise.all([first, second]);

  assertEquals(a.err, "", "the first insert should have succeeded");
  // psql exits 0 unless ON_ERROR_STOP is set, so the loser is identified by what it reported.
  assertStringIncludes(b.err, "awards_one_per_source");

  assertEquals(
    await sql(`select count(*) from app.awards where source_id = '${source}'`),
    "1",
    "never two rows",
  );
  await dropRun(runId);
});

Deno.test("6.2 opposite row order deadlocks — the hazard §15.2 exists to prevent is real", async () => {
  // A test that only proves the good path would also pass if the deadlock risk were imaginary.
  // Proving the hazard is real is what justifies the rule.
  const runId = await freshRun();
  const ids = [crypto.randomUUID(), crypto.randomUUID()].sort();
  for (const [i, id] of ids.entries()) {
    await sql(`
      insert into app.checkpoint_results
        (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
         snapshot_place_name, snapshot_lore, snapshot_sources, snapshot_content_version,
         device_id, created_at, updated_at)
      values ('${id}', '${runId}', '${USER_A}', 'cp-${i}', ${i}, now(), 'gps', 'P', '[]', '[]',
              '1', '${DEVICE}', now(), now())
    `);
  }
  const bump = (id: string) =>
    `update app.checkpoint_results set order_index = order_index + 1, revision = revision + 1,
       updated_at = now() where id = '${id}';`;

  const s1 = psql(`begin;${bump(ids[0])} select pg_sleep(1);${bump(ids[1])} commit;`);
  const s2 = psql(`begin;${bump(ids[1])} select pg_sleep(1);${bump(ids[0])} commit;`);
  const [r1, r2] = await Promise.all([s1, s2]);

  const combined = `${r1.err}\n${r2.err}`;
  assertStringIncludes(combined, "deadlock detected");
  await dropRun(runId);
});

Deno.test("6.3 the same two sessions sorted by id complete without deadlocking", async () => {
  // "Sort every batch by id before sending" (§15.2). UUIDs are arbitrary but they are
  // CONSISTENTLY arbitrary, and any total order shared by all clients works.
  const runId = await freshRun();
  const ids = [crypto.randomUUID(), crypto.randomUUID()].sort();
  for (const [i, id] of ids.entries()) {
    await sql(`
      insert into app.checkpoint_results
        (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
         snapshot_place_name, snapshot_lore, snapshot_sources, snapshot_content_version,
         device_id, created_at, updated_at)
      values ('${id}', '${runId}', '${USER_A}', 'cp-${i}', ${i}, now(), 'gps', 'P', '[]', '[]',
              '1', '${DEVICE}', now(), now())
    `);
  }
  const bump = (id: string) =>
    `update app.checkpoint_results set order_index = order_index + 1, revision = revision + 1,
       updated_at = now() where id = '${id}';`;
  const ordered = `begin;${bump(ids[0])} select pg_sleep(0.5);${bump(ids[1])} commit;`;

  const [r1, r2] = await Promise.all([psql(ordered), psql(ordered)]);
  assertEquals(r1.code, 0, r1.err);
  assertEquals(r2.code, 0, r2.err);
  assert(!`${r1.err}${r2.err}`.includes("deadlock"), "no deadlock when the order is shared");
  await dropRun(runId);
});

Deno.test("6.5 a session idle in transaction past the timeout is terminated", async () => {
  // §15.7: a single long-lived transaction holds back the vacuum horizon for the ENTIRE database.
  // One hung mobile client with an open transaction is a cluster-wide bloat event, and this
  // timeout is what turns it into an error instead. It is also what makes §9.3's cursor overlap
  // sound (§15.4), so it is load-bearing twice.
  const r = await psql(`
    set idle_in_transaction_session_timeout = '300ms';
    begin;
    select 1;
    \\! sleep 1
    select 2;
  `);
  assert(
    /idle-in-transaction|terminating connection|server closed the connection/i.test(r.err),
    `expected an idle-in-transaction termination, got: ${r.err || r.out}`,
  );
});

Deno.test("6.5b the timeouts are configured on the roles that matter, not only in this test", async () => {
  // `ALTER ROLE … SET` applies at connection time for the CONNECTING role, and `authenticated` and
  // `anon` are NOLOGIN — PostgREST reaches them through SET ROLE. So what is asserted here is the
  // configuration itself; the mechanism is asserted above.
  const settings = await sql(`
    select r.rolname || '=' || array_to_string(s.setconfig, ',')
      from pg_db_role_setting s join pg_roles r on r.oid = s.setrole
     where r.rolname in ('authenticated','anon') order by r.rolname
  `);
  assertStringIncludes(settings, "anon=statement_timeout=10s");
  assertStringIncludes(settings, "authenticated=statement_timeout=30s");
  assertStringIncludes(settings, "idle_in_transaction_session_timeout=30s");
});

Deno.test("6.6 a query past statement_timeout is cancelled, not left hanging", async () => {
  const r = await psql(`
    set statement_timeout = '200ms';
    select pg_sleep(3);
  `);
  assertStringIncludes(r.err, "canceling statement due to statement timeout");
});

Deno.test("4.2.7 a transaction that commits behind the cursor is caught by the overlap", async () => {
  // §15.4, stated honestly: the overlap is a MITIGATION, not a proof. A sequence value is claimed
  // before commit, so a transaction that claims 500 and commits slowly can land behind a reader
  // that has already passed 500. This test builds exactly that situation.
  const runId = await freshRun();
  const slowId = crypto.randomUUID();

  const slow = psql(`
    begin;
    insert into app.checkpoint_results
      (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
       snapshot_place_name, snapshot_lore, snapshot_sources, snapshot_content_version,
       device_id, created_at, updated_at)
    values ('${slowId}', '${runId}', '${USER_A}', 'cp-slow', 0, now(), 'gps', 'P', '[]', '[]',
            '1', '${DEVICE}', now(), now());
    select pg_sleep(2);
    commit;
  `);

  // Let the slow transaction claim its server_seq, then commit five rows on top of it.
  await new Promise((r) => setTimeout(r, 600));
  const laterIds: string[] = [];
  for (let i = 0; i < 5; i++) {
    const id = crypto.randomUUID();
    laterIds.push(id);
    await sql(`
      insert into app.checkpoint_results
        (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
         snapshot_place_name, snapshot_lore, snapshot_sources, snapshot_content_version,
         device_id, created_at, updated_at)
      values ('${id}', '${runId}', '${USER_A}', 'cp-later-${i}', ${i + 1}, now(), 'gps', 'P',
              '[]', '[]', '1', '${DEVICE}', now(), now())
    `);
  }

  // A reader pulls now and its cursor moves past the uncommitted row's claimed value.
  const cursor = Number(
    await sql(
      `select max(server_seq) from app.checkpoint_results where user_id = '${USER_A}'`,
    ),
  );

  const r = await slow;
  assertEquals(r.code, 0, r.err);

  const slowSeq = Number(
    await sql(`select server_seq from app.checkpoint_results where id = '${slowId}'`),
  );
  assert(slowSeq < cursor, `the slow row (${slowSeq}) should sit behind the cursor (${cursor})`);

  // Without the overlap it is missed — permanently, and nothing anywhere reports it.
  assertEquals(
    await sql(
      `select count(*) from app.checkpoint_results
        where user_id = '${USER_A}' and server_seq > ${cursor} and id = '${slowId}'`,
    ),
    "0",
    "a plain `> cursor` pull misses the row, which is the hole the overlap exists to close",
  );

  // With it, the row arrives. The client dedupes by id and revision on receipt regardless, which
  // it must do for retries anyway, so the overlap costs a few extra rows per pull and nothing else.
  assertEquals(
    await sql(
      `select count(*) from app.checkpoint_results
        where user_id = '${USER_A}' and server_seq > ${cursor} - 100 and id = '${slowId}'`,
    ),
    "1",
  );

  await dropRun(runId);
  assertEquals(laterIds.length, 5);
});

Deno.test("9.3 a check-constraint change validates under a weak lock, not ACCESS EXCLUSIVE", async () => {
  // §15.8. `awards.type` and `suppressions.entity_type` will both grow again. Done naively that is
  // a drop and re-add, which takes ACCESS EXCLUSIVE and re-scans every row to validate: harmless
  // on an empty table, an outage on a live one.
  //
  // NOT VALID accepts the constraint for new rows immediately and defers the check of existing
  // ones to VALIDATE, which takes only SHARE UPDATE EXCLUSIVE and does not block reads or writes.
  const r = await psql(`
    alter table app.awards
      add constraint tmp_type_check check (type in ('stamp','badge','letter')) not valid;
    begin;
    alter table app.awards validate constraint tmp_type_check;
    select string_agg(distinct mode, ',' order by mode) from pg_locks
     where relation = 'app.awards'::regclass and pid = pg_backend_pid();
    commit;
    alter table app.awards drop constraint tmp_type_check;
  `);
  assertEquals(r.err, "", r.err);
  assertStringIncludes(r.out, "ShareUpdateExclusiveLock");
  assert(
    !r.out.includes("AccessExclusiveLock"),
    `VALIDATE must not hold ACCESS EXCLUSIVE; locks were: ${r.out}`,
  );
});
