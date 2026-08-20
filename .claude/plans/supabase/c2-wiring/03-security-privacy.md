# 03 — Security, privacy, and the blockers that are not engineering

## 1. Keys

| Key | Where it may live | Where it may never live |
|---|---|---|
| **Publishable / anon** | in the app binary | — |
| **Service role** | Edge Functions, CI secrets | **the app, in any build configuration, ever** |

The publishable key is designed to be public. RLS is what protects the data, which is
why `b3` §4 proves isolation with real user tokens over HTTP rather than with
`execute_sql`.

The service-role key **bypasses RLS entirely**. In the app it would read every user's
rows from any installed copy, and an installed copy is a file somebody can open. This
project has already had one production key exposure and rotation — that is the
precedent, not a hypothetical.

If something in a phase seems to need elevated access, it belongs in an Edge
Function. `publish-suppressions` already is one, and its own code refuses any bearer
that is not the service role so a valid user JWT gets a 403 rather than a Postgres
permission error.

**Do not disable RLS locally to make a write work.** `db reset` restores it, and a
client that only works with RLS off has never exercised the real policy. The failure
then arrives at the end, on every table at once.

## 2. What the server is allowed to know

Three rules, each from a requirement, each easy to break by being helpful.

### `ops.events` has no `user_id` and must never acquire one

Design §2.4. The `ingest` function additionally never learns who the caller is — a
`user_id` field in the payload is ignored because the insert names its columns.

Phase 0 must not pass an identifier that would make the table want one. If a
telemetry question can only be answered by knowing which user did something, the
answer is that the question is not asked.

### Accuracy is bucketed before it leaves the device

`NFR-PRIV-02`. `lt20` / `b20_75` / `gt75`, never the metre figure. A precise accuracy
reading beside a checkpoint id and a timestamp is a location trace by another name.

There are no coordinates in any `app.*` table at all. Do not add one, do not put one
in a snapshot, and do not put one in a telemetry parameter.

### Sidequest photographs never leave the device

`FR-SIDE-13`, `NFR-PRIV-01`. `app.photos` carries a comment saying a sidequest
photograph has **no row here at all**, with no opt-in that reverses it.

Two capture paths exist and only one uploads: `QuestPhotoCaptureScreen` (checkpoint
tasks) does, `CameraCaptureView` (the sidequest challenge) does not. That difference
is a requirement, and phase 4 should hold it with a guard rather than a comment —
`PermissionCallBoundaryTests` is the family of test that already does this kind of
thing by scanning source.

## 3. Deletion

`FR-SET-02` and the `delete-account` function.

`profiles.deleting_at` is a flag the upload path checks, and migration 0009 enforces
it in the **storage insert policy** rather than trusting the client — because the
failure it prevents is an object landing after the row that described it was deleted:
unreachable, undeletable personal data on the one path where that is least
acceptable.

Two consequences for phase 4:

- A rejected upload during deletion is an **expected outcome**, not an error to
  retry.
- The orphan sweeper remains the backstop. The policy narrows the race; it does not
  close it, and the migration says so.

`DataEraser` in the app currently erases locally. Once phase 3 ships, local erasure is
no longer the whole promise — it has to call `delete-account` too, or Settings tells
the user something that is not true.

## 4. The blockers that are not engineering

Phase 5 cannot publish, and no build can go public, until these move. They are listed
so that a phase is not called finished while one is open.

| # | Blocker | Detail |
|---|---|---|
| **B1** | **Consent is a self-grant** | Every `consent/badung-*.json` names the project team as `grantingBody`, scoped to inclusion and naming, for a non-public academic prototype. **None of the five sites has been approached.** Signatory fields are literal placeholders (`[NAMA TIM]`, `[NAMA ANGGOTA 1]`). `docs/consent-request-pack.md` sets out per site who to approach, what is being asked, and what changes if they decline |
| **B2** | **The app has no name** | Blocks all five consent approaches equally. "Kultara" is a real community storyteller organization in Sanur — a research partner, not a brand. "Hisplora" is a Figma file name |
| **B3** | **Uncited History page** | Nine paragraphs with no citations and a portrait with no provenance, breaking `FR-CP-05` and `FR-CP-06` by an explicit owner decision of 2026-08-20. Publishing a share card carrying that content turns an internal prototype into a public claim |
| **B4** | **Unsigned amendments** | `FR-MAP-01`'s discovery-basemap amendment is drafted with no owner named; `FR-CP-05`'s Story Reveal exception is undocumented in the PRD. Neither blocks wiring; both block a release |

**B1 and B2 are the same problem wearing two hats.** The four cross-cutting blockers
in `docs/consent-log.md` — team name, signatories, the app's name, and whether the
build stays non-public — block every site equally and are not per-site work.

## 5. Content integrity

The published bundle is world-readable and its integrity rests on a checksum. §14
defect 16 says it ought to rest on a **detached signature** as well, and it does not.

C2 does not ship remote content, so this is not in scope — but phase 0 reads
`suppressions.json` from that same public bucket, and `GovernanceKit` validates its
schema rather than its authorship. Worth knowing that the kill-switch's trust model
is TLS plus schema validation, and nothing else.

## 6. Rate limits already set

From `config.toml`, relevant to phases 0, 1 and 6:

| Limit | Value |
|---|---|
| anonymous sign-ins | 30 / hour / IP |
| sign in + sign up | 30 / 5 min / IP |
| token refresh | 150 / 5 min / IP |
| `ingest` body | 512 KiB, checked **before** parsing |
| `ingest` batch | 200 rows |

The `ingest` body ceiling is checked as a bounded stream before `req.json()`, because
on the one deliberately unauthenticated endpoint a multi-megabyte payload was
otherwise fully materialised in worker memory before anything asked how many rows it
claimed. Phase 0's client must respect the row cap or it will be told to.
