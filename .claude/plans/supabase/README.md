# Supabase — implementation plan

**Status:** planned, nothing built.
**Owner:** unassigned.
**Design of record:** [`docs/backend-supabase.md`](../../../docs/backend-supabase.md). That document
decides *what* the server is; these plans decide *how it gets created*, in what order, and what
proves it. Where the two disagree, the design document wins and this folder is wrong.

## What this builds

A `supabase/` directory at the repository root — the standard Supabase CLI project layout, so that
`supabase db reset` reconstructs the entire backend from scratch on any machine, and
`supabase db push` deploys it.

```
/                              repo root
├── challange-5/               Xcode project (unchanged by this work)
├── docs/                      backend-supabase.md, schema.md, system-design.md
└── supabase/                  NEW — everything in this plan
    ├── config.toml            local stack + the PostgREST schema exposure that §8 relies on
    ├── migrations/            timestamped, forward-only SQL
    ├── functions/             Edge Functions (ingest, delete-account, merge-anonymous)
    ├── tests/                 pgTAP — the isolation proof from §8.2
    └── seed.sql               local development data only, never deployed
```

## Why the CLI layout rather than a hand-run SQL folder

Three properties, and the third is the one that matters here:

1. **`supabase db reset` is reproducible.** The database is rebuilt from migrations every time, so
   "works on my machine" is not reachable — either the migrations produce it or it does not exist.
2. **Migrations are forward-only and timestamped**, so two people working in parallel get a
   deterministic order rather than a merge conflict in one big file.
3. **`supabase test db` runs pgTAP against the freshly reset database.** `docs/backend-supabase.md`
   §8.2 specifies an isolation suite, and this repo's stated practice is that invariants are held by
   tests rather than review (`CLAUDE.md`). Without a test runner wired into the project layout, §8
   is a promise. With one, it is a build failure.

## Files in this folder

| File | What it decides |
|---|---|
| `b0-scope-and-decisions.plan.md` | what is in, what is out, and the decisions the migrations rest on |
| `b1-project-layout.plan.md` | `config.toml`, migration order and contents, tests, functions, CI |
| `b2-test-scenarios.plan.md` | every scenario, and where each one is proved. Gates every push |
| `b3-environments-and-deploy.plan.md` | dev and prod projects, the push sequence, rollback, monitoring |

## Local first — no hosted project is needed to finish `b1` or `b2`

`supabase start` runs the real services in Docker, not stand-ins: Postgres, PostgREST, GoTrue,
Storage API. RLS evaluation, storage authorization, constraints, triggers, the sync protocol and
anonymous sign-in all behave identically to hosted, and `config.toml` is applied locally too — so
even the "is `ops` exposed over PostgREST?" check is a valid local test.

So the entire test matrix in `b2` completes on a laptop, and CI runs the same commands on every pull
request. A hosted project is needed only when something requires a real endpoint — a TestFlight
build, or a demo.

**Supabase Branching is a Pro feature and this plan does not use it** (`b3` §1.3). The local stack
covers what a preview branch would, on every change, for free.

## The working shape

```
edit → supabase db reset && supabase test db → CI repeats it on the PR → push to prod
```

Two tiers, not three: **local is the development environment, and there is one hosted project.**
That makes prod the first hosted environment any migration touches, which is carried by three
things — additive-only migrations as the rollback strategy (`b0` D2), `--dry-run` before every push,
and `b3` §4's HTTP suite run against prod immediately after.

**Prod is not precious until the first real user signs in** (`b3` §1.1). Until then it can be pushed
to, tested against and reset freely — a genuine hosted-testing period, with an end date.

## Phasing

Follows `docs/backend-supabase.md` §12 exactly, because the rollout there is already ordered by what
is independently revertible.

| Phase | Migrations | Ships | Gate to next |
|---|---|---|---|
| **0** | `0001`–`0004` | schemas, roles, `ops` tables, `/ingest`, kill-switch file | Edge Services ownership decided (`system-design.md` §16) |
| **1** | `0005`–`0010` | auth, `app` tables, RLS, storage buckets, push-only sync | a privacy policy, a deletion path, and the §13.3 residency answer exist |
| **2** | `0011`–`0012` | pull sync, `sync_conflicts`, merge function | phase 1 stable for one content cycle |
| **3** | `0013` | journal, photo backup, share cards | photo activities actually shipped on device |
| **4** | — | `catalog` authoring — **and see `b0` D5, which recommends not building it** | — |

**Phase 0 needs no account and no `app` schema at all.** It is the tier v1 genuinely requires:
without ingest the release produces no verdict on its own hypothesis (`system-design.md` §1). It is
also the only phase that can ship before the legal questions in §13.3 are answered, which is why it
is first rather than merely early.
