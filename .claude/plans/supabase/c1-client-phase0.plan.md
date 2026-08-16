# C1 — Edge Services phase 0: making the deployed backend do something

`b0`–`b3` built and deployed a backend. **Nothing in the app calls it.** Thirteen migrations, three
Edge Functions, 200 green assertions and a hosted project in `ap-southeast-1` — and an app that
would behave identically if the project were deleted tomorrow.

This plan closes the smallest useful part of that gap: the two services `system-design.md` §16 calls
"Edge Services phase 0", plus the publisher that migration 0004 was written to feed and that nobody
ever wrote.

`docs/backend-supabase.md` is the design of record and outranks this plan wherever they disagree.

## 1. In scope

| # | Deliverable | Where it lives | What it satisfies |
|---|---|---|---|
| 4a | `publish-suppressions` — a fourth Edge Function, service role, reads `ops.suppressions_document` and writes `suppressions.json` into the public `content` bucket | `supabase/functions/publish-suppressions/` | `AD-5`, `FR-ERR-09`, design §6.1 |
| — | A Deno suite asserting the published document is schema 2, carries all three arrays, and that a schema-1 consumer still validates it | `supabase/tests/functions/publish_suppressions.test.ts` | `b3` §4's rule: proved over HTTP, not inside the database |
| 4b | `GovernanceKit` — fetches one static schema-validated JSON file over TLS, keeps the last good copy, never blocks launch | `Packages/Kultara/Sources/GovernanceKit/` | `AD-5`, `NFR-SEC-02`, `FR-ERR-09` |
| 4c | `TelemetryKit` — durable local queue, opportunistic flush, `POST /functions/v1/ingest`, 200 marks sent | `Packages/Kultara/Sources/TelemetryKit/` | design §10, `NFR-OBS-01`, `FR-ERR-10` |
| — | `UUIDv7` in `RunEngine` | `Packages/Kultara/Sources/RunEngine/UUIDv7.swift` | design §2.3, `b0` D8 |

## 2. Deliberately not in it

Each of these is a decision, not an oversight.

- **No sync.** Migrations 0005–0012 build a whole sync sequence and conflict ledger. Wiring the app
  to it means auth, an account, a merge path and a conflict UI, and none of that is phase 0.
  `FileRunStore` stays the store; `RunStore` stays the seam it was designed to be.
- **No auth.** `TelemetryKit` posts to a deliberately unauthenticated function (`verify_jwt = false`,
  design §6.2) and `GovernanceKit` reads a public bucket. Neither needs a token, and giving them one
  would be the first thing in the app that asks a walker to have an account.
- **No photo upload, no share card.** Both need `trip-photos`, which needs auth.
- **No scheduler for the publisher.** `publish-suppressions` is invoked; nothing invokes it on a
  timer yet. See §6.
- **One migration, and it is purely additive.** `ops` is deliberately absent from
  `[api] schemas = ["app"]`, so *nothing* — including the service role — can read
  `ops.suppressions_document` over PostgREST. Migration 0014 adds one `security definer` accessor in
  `app`, granted to `service_role` alone. It creates a function; it alters no table, drops nothing,
  and changes no existing behaviour. A **non-additive** migration would have been a stop-and-ask,
  and this is not one. Exposing `ops` in `config.toml` instead was considered and rejected: that is
  a security control (`b0` D1), and widening it to publish one document would put the whole
  telemetry schema on the public API.

## 3. Decisions

### D1 — The publisher is an Edge Function because Postgres cannot write Storage bytes

Migration 0004 already states this and takes the first half of the split: the trigger derives the
document transactionally into `ops.suppressions_document`, and publication is "a read of one row by
a privileged caller". This plan writes that caller. It is the missing half of a design that was
already decided, not a new design.

The consequence 0004 left open is the one that matters: **without a publisher, `AD-5`'s kill-switch
is a release gate with no release.** A place can be withdrawn in the database and the app will never
hear about it.

### D2 — The published document is written whole, never patched

The function reads one row and PUTs one object. It does not merge, diff, or append. A partially
written suppressions file is a withdrawal that half-applies, which is worse than one that does not
apply at all — the client can detect "malformed, keep the last good copy" but cannot detect
"plausible but missing one id".

### D3 — `GovernanceKit` decodes the new array as `decodeIfPresent ?? []`, and this is load-bearing

The document is schema 2. A schema-1 document — a content rollback, an older publisher, a partially
migrated environment — must still validate and simply carry no sidequests.

If `suppressedSideQuestIds` were a required key, a schema-1 document would fail validation, the
client would fall back to its last good copy, and **a withdrawal would silently stop applying**.
That is precisely the failure `AD-5` exists to prevent, arriving through the mechanism meant to
prevent it. The test for this asserts a schema-1 document decodes, not merely that a schema-2 one
does.

### D4 — No reachability check, anywhere, in either service (`AD-3`)

Neither service asks whether the network is up. `GovernanceKit` attempts a fetch and keeps its last
good copy when the attempt does not produce a valid document — indistinguishably for a timeout, a
502, a truncated body or a malformed one. `TelemetryKit` attempts a flush and leaves rows queued on
anything that is not a 200.

This is not a stylistic preference. A reachability check is the specific mistake `AD-3` names, and
`PermissionCallBoundaryTests` fails the build if one appears. Both services also read as *optional*
at runtime: if either fails entirely, the app behaves exactly as it does today, because nothing in
the run flow, discovery, or the summary asks either of them a question it needs answered.

### D5 — No coordinate leaves the device, in any form

`TelemetryKit`'s event payloads carry a checkpoint id and an **accuracy band** — `lt20`, `b20_75`,
`gt75` — never a `CLLocation`, never a latitude, never a raw metre count. The bands are tokens, not
punctuation, so they survive a JSON round trip and a chart legend without quoting.

A raw accuracy figure is not a coordinate but it is a fingerprint: accuracy metres at a known
checkpoint at a known minute narrows a device considerably. Banding is what makes the claim in
`NFR-PRIV` true rather than approximately true.

### D6 — `run_key` is a per-Run random UUID that is never written to `app.runs`

Design §2.4. Events carry `run_key` so a walk's events can be grouped in analysis. It is minted per
Run, stored locally beside the Run, and **never** sent to `app.runs` or any table that holds a
`user_id`. `ops.events` has no `user_id` column and must never acquire one; `run_key` is what makes
that survivable rather than useless.

No other identifier of any kind travels: no device id, no advertising id, no install id, no IP the
function stores (design §14 defect 17 is the open question about the ones the platform logs).

### D7 — UUIDv7 lives in `RunEngine`, not in a dependency

`b0` D8 flagged this as a client-side change the backend plan depended on and did not make. RFC 9562
§5.7 is about twenty lines: 48 bits of Unix milliseconds, 4 bits of version, 12 bits of random, 2
bits of variant, 62 bits of random. iOS 18 ships no native generator.

It goes in `RunEngine` because `RunEngine` is what mints Run and checkpoint-result ids, and adding a
package dependency to generate 128 bits would be the wrong trade in both directions.

The server cannot hold this rule — a v4 id inserts and works — so the failure mode is index bloat
that grows with the table and never announces itself. That is why it is a test, not a convention.

### D8 — Both kits are new package targets, not app-target files

`ContentKit` and `RunEngine` must not import SwiftUI, UIKit, CoreLocation, MapKit or AppKit, and
`ImportBoundaryTests` enforces it by scanning the source tree. Both new kits are Foundation-only for
the same reason and are scanned by the same test: a telemetry kit that imports CoreLocation would be
the shortest possible route to D5 being false.

They sit at the platform layer, below the app target and beside `DesignSystem`, and the app target
composes them. Neither is imported by `ContentKit` or `RunEngine`.

## 4. What each deliverable has to be true

### 4a — `publish-suppressions`

- Service role, `verify_jwt = true` in `config.toml`. It is an operator tool, not a client endpoint.
- Reads exactly one row: `ops.suppressions_document`, through `app.published_suppressions()` — a
  `security definer` accessor added by migration 0014 and executable by `service_role` alone.
  `ops` stays off the public API.
- PUTs `suppressions.json` into `content` with `Cache-Control` short enough that a withdrawal
  applies within a release cycle, and `upsert: true` so republishing is idempotent.
- Returns the published document, so the caller can verify without a second round trip.

### 4b — `GovernanceKit`

- One entry point: fetch, validate, persist, return. No refresh policy, no timer, no observer.
- The last good copy is a file on disk. It survives a launch, a crash and an airplane-mode week.
- Validation is total: schema version, all three arrays present-or-defaulted, every element a
  non-empty string. Anything else is a discard.
- Never blocks launch. The app reads whatever copy is on disk synchronously and updates later.

### 4c — `TelemetryKit`

- The queue is durable before the flush is attempted, not after. An event that is lost because the
  process died between "recorded" and "written" is a bug the design's §10 wording rules out.
- A 200 marks rows sent. Anything else — any status, any thrown error — leaves them queued.
- Survey rows are never pruned (`FR-ERR-10`). Event rows may be, on a cap; survey rows may not.
- Ids are UUIDv7 (D7), so a retried flush hits `on conflict (id) do nothing` and is not a duplicate.

## 5. How it is verified

Backend, from the repository root with Docker running:

```bash
supabase db reset && supabase db lint -s app,ops,catalog,public --fail-on warning
supabase test db
deno test --allow-net --allow-env --allow-run supabase/tests/functions/
```

App, from `challange-5/Packages/Kultara` with `DEVELOPER_DIR` set:

```bash
swift test
```

The new Swift suites run under `swift test` on macOS with no simulator, like every other package
suite. Nothing here needs the simulator, which is the point of putting it below the app target.

## 6. Deliberate omissions, stated so they are not mistaken for oversights

- **Nothing invokes `publish-suppressions` on a schedule.** It is a function with a caller that does
  not exist yet. `pg_cron`, a GitHub Action, or an operator running it by hand are all viable and
  all need the ownership decision `system-design.md` §16 is still blocked on. Publishing on a timer
  before anyone owns the uptime would be worse than publishing on demand.
- **No signature on the published document** (design §14 defect 16). The bucket is public-read and
  the document's integrity rests on TLS and on who holds the service role. A detached signature is
  the right answer and it needs a key-management decision.
- **`GovernanceKit` is not wired into the app target by this plan.** The kit exists, is tested, and
  has an entry point. Deciding *when* the app fetches — launch, foreground, a schedule — is a
  product decision about how quickly a withdrawal must apply, and `AD-5`'s answer ("next launch") is
  a floor rather than a specification.
- **No retention job.** Design §15.7 describes deleting old `ops` rows. Nothing here does it.
- **Region and UU 27/2022** (`b3` §8) remain open and out of scope, as stated.

---

## Execution — 2026-08-16

**Status: all four deliverables built and green. Nothing is wired into the app target, which is
§6's stated omission rather than an unfinished step.**

### What was built

| Deliverable | Files | Tests |
|---|---|---|
| 0014, the accessor | `supabase/migrations/20260816120001_publish_suppressions_accessor.sql` | via the suite below |
| 4a `publish-suppressions` | `supabase/functions/publish-suppressions/index.ts`, `config.toml` entry | `supabase/tests/functions/publish_suppressions.test.ts` — 7 |
| 4b `GovernanceKit` | `SuppressionsDocument.swift`, `GovernanceService.swift` | `Tests/GovernanceKitTests/` — 12 |
| 4c `TelemetryKit` | `TelemetryEvent.swift`, `TelemetryQueue.swift`, `TelemetryService.swift` | `Tests/TelemetryKitTests/` — 12 |
| D7 UUIDv7 | `Sources/RunEngine/UUIDv7.swift` | `Tests/RunEngineTests/UUIDv7Tests.swift` — 6 |
| Boundaries | `ImportBoundaryTests` +2 cases, `PermissionCallBoundaryTests` scan widened | included above |

### Deviations

1. **§2 originally said "no new migration". It was wrong, and the plan was corrected before any
   code was written rather than after.** `ops` is deliberately absent from `[api] schemas = ["app"]`,
   so *nothing* can read `ops.suppressions_document` over PostgREST — service_role included, because
   the exposed-schema list is evaluated before the role is. Migration 0014 adds one `security
   definer` accessor, `app.published_suppressions()`, granted to `service_role` alone. **Additive**:
   it creates a function, alters no table, drops nothing, changes no existing behaviour — so it is
   not the non-additive migration the brief said to stop and ask about. The alternative, adding
   `ops` to the exposed schemas, was rejected: that setting is a security control (`b0` D1), and
   widening it to publish one document would put `ops.events` and `ops.survey_responses` on the
   public API.

2. **The function checks the bearer is the service role, on top of `verify_jwt = true`.** Without
   it a signed-in walker's JWT passes the outer gate, reaches Postgres, and fails there — a 502 with
   a permission error rather than a 403 with a reason. Test `c1.4` is that case.

3. **`TelemetryKitTests` depends on `RunEngine`; `TelemetryKit` does not.** The tests need
   `UUID.v7`; the service takes ids from its caller. Putting the dependency on the production target
   would have pointed a platform edge at the Run engine, which is the wrong direction.

4. **`GovernanceService` returns a document from `refresh()` rather than throwing.** A caller that
   has to handle an error is a caller that can handle it wrongly, and there is exactly one correct
   behaviour for every failure: keep the last good copy.

### Where the real risk was, and what holds it

Every `GovernanceKit` test is about a failure, deliberately — the happy path is one line and every
real risk is on the other side.

- **`aSchemaOneDocumentStillValidatesAndCarriesNoSideQuests`** is the load-bearing one (D3). If
  `suppressedSideQuestIds` were required, a rollback or an older publisher would fail validation,
  the app would fall back to its last good copy, and **a withdrawal would silently stop applying** —
  `AD-5`'s exact failure arriving through the mechanism meant to prevent it.
- **`aNewerSchemaIsAcceptedRatherThanRefused`** is the same rule pointed the other way. Refusing an
  unfamiliar newer schema turns a forward-compatible addition into a kill-switch outage.
- **`malformedBytesDoNotReplaceAGoodDocument`** — a *successful* fetch of rubbish (an HTML error
  page) is more dangerous than a failed one, because a service that adopted it would un-withdraw
  everything the moment a publisher misbehaved.
- The two arrays that predate schema 2 stay **required**: their absence is a malformed document, not
  an older one, and treating it as older would let a truncated file read as "nothing is withdrawn".

On the telemetry side, `anythingOtherThanTwoHundredLeavesRowsQueued` loops every status
(0/400/401/429/500/502/503) and `aThrownTransportErrorAlsoLeavesRowsQueued` covers the throw,
because distinguishing those two is where a reachability check would begin.

`anArrivalEventCarriesNoCoordinateAndNoRawAccuracy` asserts against the **encoded bytes**, not the
type — that is what actually travels — and checks the absence of `lat`, `lon`, `latitude`,
`longitude`, `coordinate`, `accuracyM` and the raw metre figure. `noEventFieldCanCarryAUserIdentifier`
does the same for `user_id`, `device`, `email`, `install`.

### Hard constraints, and how each is actually held

| Constraint | Held by |
|---|---|
| No reachability check, ever (`AD-3`) | `PermissionCallBoundaryTests.noModuleChecksReachability`, widened to scan `GovernanceKit` and `TelemetryKit` — the two targets that touch the network and therefore the only two where one would ever look reasonable |
| No coordinate leaves the device (D5) | `TelemetryKit` cannot import CoreLocation (`ImportBoundaryTests`), so it cannot name a `CLLocation`; the only arrival constructor takes a checkpoint id and an `AccuracyBand`; and the wire format is asserted |
| Both optional at runtime | Neither is referenced by the app target at all yet, and neither's failure path returns an error a caller must handle |
| `ContentKit`/`RunEngine` import no UI or location framework | unchanged, still scanned |
| Foreground location calls stay in four files | unchanged — nothing here touches location |
| Bands are tokens, not punctuation | `theBandsAreTokensRatherThanPunctuation` asserts the raw values are `[A-Za-z0-9_]` |

`AccuracyBand`'s boundaries belong to the *wider* band — 20 m is `b20_75`, not `lt20` — so a fix is
never described as better than it was.

### Verification

```
$ supabase db reset && supabase db lint -s app,ops,catalog,public --fail-on warning
Applying migration 20260816120001_publish_suppressions_accessor.sql...
No schema errors found
{"results":[],"message":"db lint"}

$ supabase test db
Files=6, Tests=148,  2 wallclock secs
Result: PASS

$ deno test --allow-net --allow-env --allow-run supabase/tests/functions/
c1.1 the publisher writes a schema-2 document carrying all three arrays ... ok (151ms)
c1.2 a released suppression leaves the document ... ok (171ms)
c1.3 a schema-1 consumer still validates the schema-2 document ... ok (107ms)
c1.4 a user token cannot publish ... ok (117ms)
c1.5 the anon key cannot publish ... ok (1ms)
c1.6 GET is refused ... ok (1ms)
c1.7 republishing is idempotent ... ok (191ms)
ok | 40 passed | 0 failed (9s)        (was 33)

$ deno test --allow-net --allow-env --allow-run supabase/tests/http/
ok | 11 passed | 0 failed (2s)

$ deno test --allow-net --allow-env --allow-run supabase/tests/concurrency/
ok | 8 passed | 0 failed (8s)

$ DEVELOPER_DIR=… swift test
􁁛  Test run with 375 tests in 44 suites passed after 0.131 seconds.     (was 342 in 39)
```

Local assertion count: 148 pgTAP + 40 + 11 + 8 Deno = **207**, from 200.

**`supabase functions serve` must be running for the Deno function suites.** This machine's
`supabase start` brings up no `supabase_edge_runtime_*` container, so the suites 503 with `{"message":
"name resolution failed"}` — which reads like a code failure and is not one. Worth knowing before
debugging the wrong thing.

### Not deployed

Nothing in this section has been pushed. The hosted project (`ppwcxmvetmmwliusliac`) still holds 13
migrations and three functions. Deploying this is `link → db push --dry-run → db push → functions
deploy publish-suppressions → config push → the HTTP suite against the prod URL` (`b3` §3), and
**`config push` is not optional** — the new `[functions.publish-suppressions] verify_jwt = true`
entry lives in `config.toml`, and a hosted function defaults differently.

### Deliberate omissions, restated as executed

- **Nothing invokes `publish-suppressions` on a schedule.** Still true, still blocked on the
  ownership decision `system-design.md` §16 names. The function is callable; nothing calls it.
- **`GovernanceKit` and `TelemetryKit` are not wired into the app target.** Both are library
  products with tests and no callers. Deciding *when* the app fetches, and *what* it records, are
  product decisions — and `AD-5`'s "next launch" is a floor, not a specification.
- **No signature on the published document** (design §14 defect 16).
- **No retention job** (design §15.7).
- **No sync, no auth, no photo upload, no share card.** Each needs an account.
- **Region / UU 27/2022** (`b3` §8) remains open and out of scope.

### New known gaps

1. **`app.published_suppressions()` is `security definer` and returns data.** It takes no arguments,
   so there is nothing to steer it with, and it returns a document that is public seconds later — but
   it is `§8.1` case 3's shape, and it is the second definer function in `app`. A third should be
   argued for rather than added.
2. **The publisher trusts the trigger.** `isPublishable` rejects a malformed document rather than
   publishing it, which is the safe failure — but it means a bug in
   `ops.rebuild_suppressions_document` surfaces as "publishing refuses" with no alert behind it.
   Nothing watches for that.
3. **`TelemetryService.maxQueuedEvents` (2 000) has no measurement behind it.** It is a
   disk-space guard chosen to be obviously large enough, not a tuned figure. Survey rows are
   correctly exempt (`FR-ERR-10`).
4. **UUIDv7 is not yet used by `RunEngine` itself.** The generator exists and is tested; `Run` and
   `CheckpointResult` ids are still minted wherever they were. Switching them is a one-line change
   per call site and was deliberately not bundled into this plan, because it changes ids on a
   persisted type and belongs with whoever owns the migration of existing local Runs.

## Execution — 2026-08-16, second entry: deployed

The §"Not deployed" note above is superseded. Migration 0014 and `publish-suppressions` are on
`ppwcxmvetmmwliusliac`. **`AD-5`'s kill-switch has a publisher and a published document for the
first time.**

### The sequence that was run

```
$ supabase db push --dry-run
Would push these migrations:
 • 20260816120001_publish_suppressions_accessor.sql

$ supabase db push
Applying migration 20260816120001_publish_suppressions_accessor.sql...

$ supabase config push
Remote API config is up to date.   Remote DB config is up to date.
Remote Auth config is up to date.  Remote Storage config is up to date.

$ supabase functions deploy publish-suppressions
Deploying Function: publish-suppressions (script size: 5.8 kB)

$ supabase functions list
delete-account       | verify_jwt=True  | ACTIVE
ingest               | verify_jwt=False | ACTIVE
merge-anonymous      | verify_jwt=True  | ACTIVE
publish-suppressions | verify_jwt=True  | ACTIVE
```

`config push` reported everything up to date, which is correct and worth stating so the next person
does not read it as a no-op that skipped something: `[functions.*] verify_jwt` is not part of the
API/DB/Auth/Storage config surface — it is applied by `functions deploy`, and the listing above is
where it is verified.

### A defect prod found and local tests could not

**The first deployed version refused the real service role.** `403 {"error":"service role
required"}` on the very first prod call.

The check was `auth.slice(7).trim() !== serviceKey()` — a string comparison against
`SUPABASE_SERVICE_ROLE_KEY`. This project carries **two credential generations at once**:

```
anon         | eyJhbGciOiJI… | 208 | jwt
service_role | eyJhbGciOiJI… | 219 | jwt
default      | sb_publishab… |  46 | opaque
default      | sb_secret_fd… |  41 | opaque
```

The key injected into the function's environment need not be the one an operator holds. Locally
both sides are the same well-known development string, so **equality passed all seven tests and was
wrong anyway** — the test and the code shared an assumption, which is the failure mode a test cannot
catch by construction.

**Fixed by authorising on the claim rather than the bytes.** `isServiceRole` accepts either the
opaque form by equality or a JWT whose `role` claim is `service_role`. Reading the claim without
re-verifying is sound *here specifically*: `verify_jwt = true` means the platform verified the
signature before the function ran, so an unsigned or wrongly signed token never reaches this code.

Two tests added, and the pair matters more than either alone:

- **c1.8** mints a `service_role` JWT with a different `iat`/`exp`, asserts it is **not equal** to
  `SERVICE_KEY`, and requires a 200. Under the old code this fails.
- **c1.9** requires an ordinary authenticated user's JWT to still get a 403 — so "read the claim"
  does not degrade into "any well-formed JWT gets in".

### Verification, prod

```
$ curl -X POST …/functions/v1/publish-suppressions  -H 'Authorization: Bearer <service_role>'
{"published":true,"bucket":"content","object":"suppressions.json",
 "document":{"updatedAt":"2026-08-15T13:09:32Z","schemaVersion":2,
             "suppressedPlaceIds":[],"suppressedQuestIds":[],"suppressedSideQuestIds":[]}}
HTTP 200

$ curl …/storage/v1/object/public/content/suppressions.json          # anon, no auth header
{"updatedAt":"2026-08-15T13:09:32Z","schemaVersion":2,
 "suppressedPlaceIds":[],"suppressedQuestIds":[],"suppressedSideQuestIds":[]}
HTTP 200

anon bearer -> 403      GET -> 405      no auth -> 401

$ deno test … supabase/tests/http/        # against https://ppwcxmvetmmwliusliac.supabase.co
ok | 11 passed | 0 failed (9s)

$ deno test … supabase/tests/functions/   # local
ok | 42 passed | 0 failed (10s)           (was 40)
```

`updatedAt` is 2026-08-15T13:09:32Z rather than today because it is migration 0004's **seed** row:
no suppression has ever been written on prod, so the trigger has never fired and the seeded empty
schema-2 document is what stands. That is the intended behaviour — a client fetching before the
first suppression gets a valid document rather than a 404.

The published object is **world-readable by design** (`content` is public-read, migration 0009) and
contains nothing but empty arrays. Its integrity still rests on TLS and on who holds the service
role; the detached signature (design §14 defect 16) remains unbuilt.

### Local assertion count

148 pgTAP + 42 + 11 + 8 Deno = **209**, from 207.

### Still not deployed, still deliberate

Nothing invokes `publish-suppressions` on a schedule. It is callable and was called by hand once.
`system-design.md` §16's ownership decision still gates putting it on a timer.

## Execution — 2026-08-16, third entry: migration 0015, two schema defects

Reading the deployed schema back raised three questions about table width. Two were real defects;
the third was taste and is closed as such. Both fixes are live — 15 migrations, local == remote.

### Not a defect: the four `snapshot_*` columns on `app.checkpoint_results`

Examined and left exactly as they are. `AD-4` requires a summary to render forever after content is
corrected or a place withdrawn, the columns are documented as "stored, never derived",
`snapshot_lore` carries an explicit never-index comment with its reason, and splitting them into a
1:1 table would buy a join on the one read path that always wants them. Width here is the cost of a
requirement, not an accident. Recorded so the next reader does not re-derive it.

The apparent width generally is mostly the six-column sync envelope — `device_id`, `revision`,
`created_at`, `updated_at`, `server_seq`, `deleted_at` — repeated per syncable table. Net of it the
tables are 5–15 columns. `user_id` denormalised onto child tables is deliberate too: the RLS policy
is `user_id = (select auth.uid())`, which evaluates with no join.

### Defect 1 — a per-user dwell measurement (`app.checkpoint_results.lore_dwell_ms`)

§2.4 is unambiguous: *"Signing in must not deanonymise the measurement apparatus… `NFR-PRIV-02`/`03`/
`05` are enforced by the ABSENCE OF COLUMNS, not by a policy somebody has to remember."*

`lore_dwell_ms` is a measurement, and it sat on a table whose every row carries `user_id not null` —
one `UPDATE` from being true. Nothing had ever written it and no client type had a field for it, but
"no writer yet" is a fact about today and that sentence is a promise about the design.

`NFR-OBS-06` (per-checkpoint dwell MUST be instrumented) is untouched: `schema.md` §B.7 already
specifies the `checkpoint_departed` event carrying `{checkpointID, dwellMs}` into `ops.events`,
which has no `user_id` column. The metric survives; the join back to a person does not exist.

`lore_first_opened_at` **stays** — it is the `FR-CP-04` fact that lore was opened, not a duration,
and `RunEngine.markLoreOpened` writes it.

The PRD specified this column (§6, CheckpointResult), so removing it is a spec change, not a
cleanup. Amended in place with **owner af (afindo.mi01@gmail.com), 2026-08-16**, same shape as
`FR-START-04a`.

### Defect 2 — nullable photo paths, and a design that contradicted itself

`docs/backend-supabase.md` §4.7's upload ordering says step 1 inserts the row *"`storage_path` and
`thumb_path` SET, `uploaded_at` NULL"*, and explains why: the paths are deterministic from `id`, so
a failure leaves a row that is "resumable and visible".

**The DDL in the same document left both nullable**, and the migration faithfully copied it. The
nullable half won. A row with a null `storage_path` is not resumable — there is no path to resume
to — and `FR-SET-02`'s deletion, which §4.7 requires to "delete by path unconditionally rather than
branching on `uploaded_at`", has nothing to delete by. §4.7 names that outcome itself: *"leaving one
behind is a privacy failure that passes every database test."*

Both columns are now `not null`, with comments saying why. The design's DDL was corrected so it no
longer disagrees with its own prose three paragraphs down.

Set directly rather than through §15.3's `not valid` → `validate` dance: both tables hold zero rows
on every environment. **The migration says in a comment that a populated table needs the two-step
pattern instead**, because a direct `SET NOT NULL` takes ACCESS EXCLUSIVE for a full scan.

### What the constraint caught immediately

Four existing fixtures were writing photo rows with **one path or none** — precisely the
half-deletable state the rule forbids. They failed the moment the constraint landed:

- `03_constraints` 3.15c (content_type check), and the 3.14 fixture
- `04_sync` 4.1.8 (documented push order)
- `functions/merge_anonymous` 5.11 — wrote `storage_path` and **no** `thumb_path`, so the thumb
  would have survived `FR-SET-02` erasure with nothing pointing at it. Fixed, and the test widened
  to upload both derivatives and assert **both** paths are rewritten by the merge.

That last one is the strongest evidence the constraint was worth adding: the defect was already
being modelled in a test that passed.

### New guards

`03_constraints` 3.17 / 3.18 (5 assertions): `hasnt_column` for `lore_dwell_ms`, `has_column` for
`lore_first_opened_at` so the distinction between a fact and a measurement is pinned, `col_not_null`
on both paths, and a `throws_ok` proving a pathless insert is refused rather than stored.

### Left alone, deliberately

`byte_size`, `width_px`, `height_px`, `content_type` stay nullable. A null `byte_size` does make
`FR-SET-03`'s storage report under-count silently (`SUM` skips nulls) — a real if smaller problem —
but no document establishes that the device knows these at INSERT time rather than after encoding,
and tightening on a guess would trade a quiet under-count for a hard failure on the capture path.
**Known gap**, stated rather than fixed on a guess.

### Verification

```
$ supabase db reset && supabase db lint -s app,ops,catalog,public --fail-on warning
No schema errors found

$ supabase test db
Files=6, Tests=153,  Result: PASS                      (was 148)

$ deno test … functions/   ok | 42 passed | 0 failed
$ deno test … http/        ok | 11 passed | 0 failed
$ deno test … concurrency/ ok |  8 passed | 0 failed
$ swift test               375 tests in 44 suites passed

$ supabase db push --dry-run
Would push these migrations:
 • 20260816160001_privacy_and_photo_path_integrity.sql

$ supabase db push
Applying migration 20260816160001_privacy_and_photo_path_integrity.sql...

$ deno test … http/   # against https://ppwcxmvetmmwliusliac.supabase.co
ok | 11 passed | 0 failed (12s)

$ supabase migration list --linked
migrations local==remote: True | count 15
```

Both target tables held **0 rows on prod** before the push, checked rather than assumed, so the drop
cost no data and both `SET NOT NULL` scans were instant.

Local assertion count: 153 pgTAP + 42 + 11 + 8 Deno = **214**, from 209.

## Execution — 2026-08-16, fourth entry: bug hunt and index dedup (migration 0016)

A pass with `postgres-patterns` and `backend-patterns`. **Three real defects, one real
optimisation, two items handed back.** All fixes are live — 16 migrations, local == remote.

### What was checked and came back CLEAN

Stated so the next pass does not repeat it:

| Check | Result |
|---|---|
| Unindexed foreign keys (skill anti-pattern #1) | none |
| RLS predicates not wrapping `auth.uid()` in a `SELECT` | none — all wrapped |
| `security definer` functions without a pinned `search_path` | none |
| `app`/`ops` tables without a primary key | none |
| RLS enabled but not **forced** | none — all forced |

### Advisors, triaged rather than pasted

- **17 × `unused_index` (INFO)** — every one on a table with no traffic. Acting on these would be
  optimising against an absence of data; the indexes exist for query shapes that have not run yet.
  Ignored deliberately.
- **10 × `auth_allow_anonymous_sign_ins` (WARN)** — already triaged in `b3`. Design §7 makes an
  anonymous walker `authenticated` as a Postgres role ("`is_anonymous` is a claim, not a role"),
  and migration 0013 scoped every policy `to authenticated`. Accepted, unchanged.
- **4 × `rls_enabled_no_policy` on `ops.*` (INFO)** — deliberate. Forced RLS with no policy is
  deny-all, and `ops` is service-role only.
- **`auth_leaked_password_protection` disabled (WARN)** — real, and **not fixable from this repo**:
  it is a dashboard toggle, not a `config.toml` key. Handed back.
- **`auth_insufficient_mfa_options` (WARN)** — real, and a product decision for an app whose
  design opens on an anonymous session. Handed back.

### Defect 3 — `service_role` had no timeouts

Migration 0002 set `statement_timeout` and `idle_in_transaction_session_timeout` on `authenticated`
and `anon` and said nothing about `service_role`. Nothing in 0002, §15 or test 6.5b explains the
exclusion, so it is an omission.

0002's own rationale applies to `service_role` *more*: it is the role all four Edge Functions run
as, the only one that bypasses RLS, and the only one that interleaves Postgres work with Storage
HTTP calls inside a transaction — which is exactly the unbounded idle-in-transaction that "holds
back the vacuum horizon for the ENTIRE database". Set to 60s/60s (generous for FR-SET-02's cascade,
still bounded). Guards 3.20 / 3.20b.

### Defect 4 — the rate limiter was a memory-exhaustion vector

`_shared/ratelimit.ts` expired entries **lazily, only when the same ip returned**. An ip that never
came back was never released.

`clientIp` reads `x-forwarded-for`, which the file's own comment notes is spoofable — so **the key
space belongs to the caller**. One client spraying unique values got a new map entry per request,
on the only unauthenticated endpoint in the system, and the worker grew until it was killed. The
limiter was a better DoS than the flood it was written to stop.

Fixed with a `MAX_TRACKED_KEYS` ceiling, a sweep of closed windows when the ceiling is hit, and
**fail-closed** if the map is still full afterwards — a dropped telemetry batch costs a row in a
chart; an OOM costs the endpoint for everyone. Five unit tests (`ratelimit.test.ts`); `r3` fails
against the old code, which is what makes it a regression test rather than a description.

The per-worker scope of this limiter is still a stated limitation (§14 defect 17), unchanged.

### Defect 5 — `ingest` parsed unbounded request bodies, and the obvious fix hangs

`MAX_BATCH_ROWS` protects the *database* and is checked **after** `req.json()` has materialised the
whole body. A multi-megabyte payload was fully parsed into worker memory before anything asked how
many rows it claimed.

**The first fix was wrong in an instructive way.** Checking `content-length` and returning 413
early — the version most people write — left the sender mid-upload and the connection hung instead
of receiving the response:

```
400 KB -> HTTP 200        (under the cap, fine)
520 KB -> TimeoutError    (first size over the cap — should have been 413)
  2 MB -> TimeoutError
```

`req.body?.cancel()` did not help. The body must be **drained to the end**. The shipped version
reads the stream with a byte budget: it stops *keeping* bytes past the cap but keeps *consuming*
them, so memory is bounded at roughly `MAX_BODY_BYTES` plus one chunk and the 413 actually arrives.

```
    10 B -> HTTP 200
  400 KB -> HTTP 200
  520 KB -> HTTP 413 {"error":"payload too large","maxBytes":524288}
    2 MB -> HTTP 413
```

A refusal nobody receives is worse than no check, because the caller retries forever.

### Optimisation — eight redundant indexes

Found with a prefix query, not by eye: eight indexes were strict **prefixes** of another index on
the same table. A B-tree on `(a, b)` serves `where a = ?` exactly as well as one on `(a)`, so the
shorter one earned nothing and cost a write on every insert and every update touching the column —
and these are the sync tables, where `revision`, `server_seq` and `updated_at` change on every push.

```
awards_user, checkpoint_results_user, photos_user, task_results_user,
share_cards_user, journal_entries_user   ->  covered by each table's _pull (user_id, server_seq)
runs_user                                ->  runs had FOUR indexes led by user_id
profiles_user                            ->  byte-for-byte duplicate of the primary key
```

`user_id = ?` is every RLS policy's predicate and is still served by the leading column of each
`_pull` index, which exists for the delta-sync cursor and is not optional.

Three guards, and the third matters most: 3.19 (no prefix-redundant index), 3.19b (none duplicates
a PK), and **3.19c — every foreign key still has a leading-column index**, asserted *after* the
drops, because "dropped a redundant index" and "dropped the FK support" look identical until
something does a cascading delete on a big table.

Plain `drop index`, not `concurrently`: CONCURRENTLY cannot run in a transaction and the CLI wraps
each migration in one. Every table is empty on every environment. **The migration says in a comment
to drop these one at a time, concurrently, outside a migration, on a populated database.**

### Verification

```
$ supabase db lint -s app,ops,catalog,public --fail-on warning
{"results":[],"message":"db lint"}

$ supabase test db
Files=6, Tests=158,  Result: PASS                      (was 153)

$ deno test … functions/   ok | 49 passed | 0 failed   (was 42)
$ deno test … http/        ok | 11 passed | 0 failed
$ deno test … concurrency/ ok |  8 passed | 0 failed

$ supabase db push  &&  supabase functions deploy ingest
Applying migration 20260816170001_index_dedup_and_service_role_timeouts.sql...
Deploying Function: ingest (script size: 8.0 kB)

# prod
small -> HTTP 200      2 MB -> HTTP 413 {"error":"payload too large","maxBytes":524288}
$ deno test … http/ against prod   ok | 11 passed | 0 failed
$ supabase migration list --linked  local==remote: True | count 16
```

Local assertion count: 158 pgTAP + 49 + 11 + 8 Deno = **226**, from 214.

### Handed back, not fixed

1. **Leaked-password protection** — dashboard toggle, one click, real security value.
2. **MFA options** — product decision.
3. **Prod test residue**: `app.runs` 16 rows, `ops.events` 3 rows, and `@example.test` users in
   `auth.users`, all from suites run against prod. Not real data, and it muddies `b3` §1.1's "prod
   holds no real users yet". Deleting it is a data change on prod and was not done unasked.
4. **`ops` retention** (design §15.7) — still nothing prunes old rows.

## Execution — 2026-08-16, fifth entry: the handed-back items, executed (migration 0017)

Everything the fourth entry handed back is now done, plus one defect found while doing it. Secret
key rotated by the owner beforehand; prod re-verified healthy afterwards.

### 1. Auth hardening — two of the three were config, not a dashboard

The fourth entry called leaked-password protection "a dashboard toggle, not a `config.toml` key".
**That was half wrong**, and worth correcting rather than quietly fixing: the CLI does not expose an
HIBP flag, but it does expose the two settings that were actually weak —

```toml
minimum_password_length = 6   ->  8
password_requirements   = ""  ->  "lower_upper_letters_digits"
[auth.mfa.totp] enroll/verify = false -> true
```

`config push` reported `auth: updated`, and **both WARNs are gone from the advisors** —
`auth_leaked_password_protection` and `auth_insufficient_mfa_options` no longer appear.

TOTP rather than phone: SMS needs a Twilio credential this project does not have, and SIM-swap
makes it the weakest second factor anyway. Enrolment is opt-in per user, so design §7's
anonymous-first flow is untouched — nobody is forced through any of this, because an account is
optional in the first place.

`lower_upper_letters_digits` rather than the symbols variant: symbol rules push people toward
`Password1!`, and the length floor does more work.

### 2. Retention — migration 0017, and something that runs it

Design §14 defect 18: *"`ops.events` has no server-side retention. The client prunes at 30 days
(`schema.md` §B.11); the server keeps forever. Correctly undeletable under `FR-SET-02` — which is
exactly why it needs a retention horizon of its own."*

The asymmetry is the whole point: `FR-SET-02` deletes a user's data on request, and telemetry sits
outside that promise because `ops.events` has **no `user_id` to match on** (§2.4). Data that cannot
be deleted per-person must be bounded per-age, or "we cannot identify it, so we keep it forever"
becomes the policy by default.

- `ops.prune_events(retain interval default '180 days')` — `security definer`, `search_path` pinned,
  `service_role` only. Deletes on `received_at`, not `occurred_at`: `occurred_at` is device
  wall-clock, so a device with a wrong date could otherwise age its rows out on arrival, or never.
- **180 days is a starting value, not a measurement.** It is a parameter so changing it is one call
  rather than a migration, and it belongs to whoever owns §13.1.
- **`ops.survey_responses` is deliberately NOT pruned.** It is not telemetry — it is the corpus
  `FR-SURV` exists to analyse, and `FR-ERR-10` already singles it out client-side as the one thing
  never dropped. A retention job that aged it out would delete the study while looking like hygiene.
  That leaves it unbounded, which is a cost, and it is written down rather than left to be found.
- **`pg_cron` installed and the job scheduled** (`17 3 * * *`, off the hour deliberately). A
  retention function nobody calls is the same gap `publish-suppressions` was written to close: a
  policy that exists in the schema and never executes. Guard 3.21f asserts the row in `cron.job`,
  not just the function.

### 3. Prod test residue — and the reason it kept coming back

Counted before touching anything: **64 users, every one `@example.test`; 32 runs, every one owned by
a test user; zero real users, zero anonymous users.** The entire auth population was residue.

Deleted through the GoTrue admin API — the supported path, and not the `execute_sql` data repair
`b0` D9 forbids — with the loop hard-scoped to `@example.test` and anything else reported rather
than removed. 64 deleted, 0 failed; the `on delete cascade` took the 32 runs with them. Every
`app` table is now 0 rows.

`ops.events` keeps 6 anonymous rows. Deliberate: they carry no user link by design, removing them
*would* be D9's data repair, and the horizon above ages them out on its own.

**The real defect was that this kept happening.** `b3` §4 says to run the HTTP suite against prod,
and every run called `createUser` and left the accounts behind — which is how 64 accumulated and
quietly falsified `b3` §1.1's "prod holds no real users yet". A test that dirties the environment it
validates is a test people stop running.

Fixed at the source: the suite now ends with a cleanup that removes only `@example.test` accounts,
named `zz` so it sorts last. Proved by running it against prod — created 16, removed 16, prod back
to **0 users / 0 runs**.

### 4. A warning I introduced, and the guard for it

Installing `pg_cron` added `cron.job` and `cron.job_run_details`, and the advisor immediately
flagged both under `auth_allow_anonymous_sign_ins` — pg_cron ships permissive policies of its own.

They are not reachable, for the same reason `ops` is not: `[api] schemas = ["app"]` is evaluated
**before** any policy, so a schema absent from that list has no HTTP surface. Verified rather than
argued:

```
GET /rest/v1/job  (Accept-Profile: cron, anon key)
-> 406 {"code":"PGRST106","message":"Invalid schema: cron"}
```

New HTTP guard asserts it, beside the existing `ops`/`catalog` ones. Installing an extension is
exactly the kind of change that widens an API surface without anyone noticing.

### Verification

```
$ supabase db lint -s app,ops,catalog,public --fail-on warning
{"results":[],"message":"db lint"}

$ supabase test db           Files=6, Tests=164, Result: PASS     (was 158)
$ deno test functions/       ok | 49 passed | 0 failed
$ deno test http/            ok | 13 passed | 0 failed            (was 11)
$ deno test concurrency/     ok |  8 passed | 0 failed
$ swift test                 375 tests in 44 suites passed

$ supabase config push       auth: updated
$ supabase db push           Applying 20260816190001_ops_retention.sql...
$ deno test http/ vs prod    ok | 13 passed | 0 failed
$ supabase migration list    local==remote: True | count 17

prod after everything: 0 users, 0 rows in every app table, retention job scheduled
```

Local assertion count: 164 pgTAP + 49 + 13 + 8 Deno = **234**, from 226.

### Advisors now

Everything remaining is accepted and explained:

- 10 × `auth_allow_anonymous_sign_ins` on `app.*` and `storage.objects` — design §7 makes an
  anonymous walker `authenticated` as a Postgres role; migration 0013 scoped every policy.
- 2 × the same on `cron.*` — §4 above, guarded.
- 4 × `rls_enabled_no_policy` on `ops.*` — forced RLS with no policy is deny-all, by design.
- `unused_index` × N — a database with no traffic. Acting on these optimises against absent data.

**No WARN remains that is not a stated, tested decision.**

### Still open

- `ops.survey_responses` has no horizon, on purpose (§2 above).
- §14 defect 17 — IP handling and log retention behind the Edge Functions.
- The per-worker rate limiter is still per-worker (§14 defect 17 again).
- Region / UU 27/2022 (`b3` §8).

## Execution — 2026-08-16, sixth entry: the erasure path, reviewed properly

The fourth and fifth passes reviewed `ingest`, `ratelimit` and `publish-suppressions` closely and
never gave the same attention to `delete-account` and `merge-anonymous` — the only multi-table write
paths in the system, and the ones carrying `FR-SET-02`. Four defects, all in the erasure path.

### Defect 6 — `listAll` never paged, and it is the sweep FR-SET-02 relies on

```ts
body: JSON.stringify({ prefix, limit: 1000, offset: 0 })   // once. per folder level.
```

Any folder holding more than 1000 entries was **silently truncated**. This is the prefix sweep that
exists specifically to find objects the database has lost track of, so a user with more than 1000
runs — or a run with more than 1000 objects — kept the remainder forever after asking for deletion.
§4.7's own sentence applies to its own helper: *"leaving one behind is a privacy failure that passes
every database test."*

Now pages until a short page. It also **throws** instead of `return out` on a failed list: a caller
erasing an account has to be able to distinguish "nothing there" from "could not look", and the old
early return made those identical.

### Defect 7 — the `photos` read was capped by `max_rows = 1000`

The same truncation on the database side, from a different cause: `config.toml` sets
`max_rows = 1000`, which caps *every* PostgREST response. `photos?user_id=eq.…` returned at most
1000 rows regardless of how many existed.

Both reads are now paged, and **both are kept**, because they fail in opposite directions: the table
knows about objects outside the uid prefix, and the sweep knows about objects the table has lost.

### Defect 8 — `removeObjects` swallowed failures, so deletion reported success

It logged and continued, returning `void`. `delete-account` then returned `{"deleted": true}`. **A
Storage outage produced a successful erasure response with every byte still in place** — the one
response in this system that must never be optimistic.

It now returns the paths it could not delete. `delete-account` returns **502 and deletes no rows**
when that list is non-empty: the rows are the only remaining record of which objects exist, so
destroying them would strand the bytes permanently. Enumeration failure is handled the same way and
for the same reason — stop *before* the rows.

### Defect 9 — the batch loop fell out into the giant cascade it exists to avoid

`for (let i = 0; i < 200; i++)` with `BATCH = 500` caps at 100 000 rows. Past that the loop simply
ended and step 4's `delete auth.users` finished the job **by one cascade across every table** —
exactly what §15.2 batches to prevent, taking every lock at once, silently.

Now returns `202 {more: true}` with the count, so a caller can re-invoke and each call clears
another 100 000. `merge-anonymous` got the matching treatment: leftover source objects are surfaced
rather than swallowed.

### The regression test, proved to fail without the fix

`6.9` uploads **1005 objects** under one run prefix — five past the page boundary — then deletes the
account and asserts zero remain.

Verified honestly rather than assumed: `listAll` was temporarily reverted to its unpaged form and
the test went red (`5 != 0`), then restored and it went green. A test that has never failed is a
description, not a guard.

### Verification

```
$ supabase test db          Files=6, Tests=164, Result: PASS
$ deno test functions/      ok | 50 passed | 0 failed          (was 49)
$ deno test http/           ok | 13 passed | 0 failed
$ deno test concurrency/    ok |  8 passed | 0 failed

$ supabase functions deploy delete-account && … merge-anonymous
delete-account | v4 | ACTIVE      ingest | v4 | ACTIVE
merge-anonymous | v4 | ACTIVE     publish-suppressions | v4 | ACTIVE

$ deno test http/ against prod    ok | 13 passed | 0 failed
```

Local assertion count: 164 pgTAP + 50 + 13 + 8 Deno = **235**.

### What this says about the earlier passes

Three of these four are the same mistake in different clothes: **a bounded API read treated as
complete.** `listAll`'s 1000, PostgREST's `max_rows` 1000, and the batch loop's 200 iterations were
all written as if the first page were the whole answer. Worth remembering the next time this
codebase reads from anything paginated — and worth noting that all three sat in the one function
whose correctness is a privacy promise rather than a feature.

## Execution — 2026-08-16, seventh entry: the sync cursor, and a premise I broke

Followed the lead the sixth entry left — that the sync path might hold the same "first page is the
whole answer" mistake. **It does not.** But checking it surfaced something else.

### Not a defect: the pull cursor

`app.stamp_server_seq` and the `server_seq` design are sound, and §15.4 already states the one real
hazard more honestly than most codebases would: a sequence value is claimed *before* commit, so a
slow transaction can land behind a reader that has already passed it, and the 100-value overlap "is
a mitigation, not a proof". It names its own failure condition — more than 100 values claimed inside
one transaction — and says the number should be revisited if the timeout or the write rate changes.

Nothing to fix. Recorded so a later pass does not re-derive it.

### But migration 0016 changed one of the two inputs, and I did not notice at the time

§15.4's soundness rests on `idle_in_transaction_session_timeout` bounding transaction lifetime.
Two things are now true that were not when it was written:

1. **Before 0016, `service_role` had no such timeout at all.** 0002 set it on `authenticated` and
   `anon` only — which the fourth pass found and fixed as defect 3, without connecting it to §15.4.
   For any service-role write the bound §15.4 depends on **did not exist**, so the overlap was
   unsound rather than generous, and had been since 0002.
2. **0016 set it to 60s** — restoring the bound, at twice `authenticated`'s 30s.

The concrete case is `merge-anonymous`: it rewrites `user_id` across a whole anonymous account's
history in one transaction, and every update fires `stamp_server_seq` and claims a sequence value.
An account with more than 100 rows claims more than 100 values inside one transaction — exactly the
condition §15.4 names as uncovered. A second device pulling concurrently during that merge can miss
rows.

**No code changed.** There is no client sync yet (§2), so the 100 is still only a number in a
document; the right moment to choose it is when the pull is built, with the 60s bound and the merge's
row count in hand. §15.4 now records the revisit rather than leaving the constant to be copied.

### The point worth keeping

Defect 3 was fixed as a vacuum-horizon problem. It was also a sync-correctness problem, and nothing
connected the two — the design said "revisit the overlap if the timeout changes", the timeout
changed, and the revisit did not happen because the person changing it was looking at §15.7 rather
than §15.4. **A cross-reference that only runs in one direction is not a cross-reference.**

### Verification

Nothing functional changed in this entry; the suites are unchanged from the sixth:

```
supabase test db   164 PASS
functions 50 · http 13 · concurrency 8       = 235 assertions
prod: 17 migrations local==remote, 4 functions ACTIVE at v4
```

## Execution — 2026-08-16, eighth entry: autovacuum arrears (migration 0018)

### The defect

Migration 0010 tuned autovacuum on the five syncable tables that existed when it was written.
Migration 0012 then added `app.journal_entries` and `app.share_cards` — both fully syncable, both
carrying `server_seq`, `revision` and `deleted_at` — and **did not tune them**. Six migrations
passed without anyone noticing.

§15.7's reasoning applies to them identically, and to `journal_entries` most of all:

- tombstones mean rows are never removed, so tables only grow;
- every sync update bumps the **indexed** `server_seq`, ruling out a HOT update and leaving a dead
  tuple plus fresh index entries per write;
- a journal entry is *edited* — title and body, repeatedly, by a walker writing up a trip — so it
  takes more updates per row than anything else in this schema. **It is the table that most needed
  the tuning and the one that went without it.**

Postgres' default `autovacuum_vacuum_scale_factor = 0.2` waits until a fifth of the table is dead.
On an append-and-update table with tombstones that is a lot of bloat held for a long time, index
entries included.

### The guard is the actual fix

This is the **second instance of one shape** found today:

| Migration | Enumerated what existed | Later migration added | Missed for |
|---|---|---|---|
| 0002 timeouts | `authenticated`, `anon` | `service_role` was never listed | until 0016 |
| 0010 autovacuum | 5 sync tables | `journal_entries`, `share_cards` (0012) | until 0018 |

Both are a tuning migration that enumerated the world at the time, and a later migration adding one
more member without knowing a list existed. The two ALTERs in 0018 are arrears; guard 3.22 is the
repair.

It keys on the **column**, never on table names: any table carrying `server_seq` is in the
delta-sync set and must have the tuning. A hand-maintained list is precisely what failed twice.
`app.profiles` and `app.sync_conflicts` are correctly ignored — neither has `server_seq`, because
neither is part of delta sync.

Proved by breaking it: `alter table app.journal_entries reset (…)` made the guard's query report
`journal_entries`, and restoring the options returned it to zero.

### Verification

```
$ supabase db lint …            {"results":[],"message":"db lint"}
$ supabase test db              Files=6, Tests=165, Result: PASS     (was 164)
$ deno functions/http/concurrency   50 / 13 / 8, 0 failed

$ supabase db push
Applying migration 20260816200001_autovacuum_for_late_sync_tables.sql...

# prod, every table carrying server_seq:
awards, checkpoint_results, journal_entries, photos, runs, share_cards, task_results
  -> all autovacuum_vacuum_scale_factor=0.05, autovacuum_analyze_scale_factor=0.02
```

Local assertion count: 165 pgTAP + 50 + 13 + 8 Deno = **236**.

### Where this leaves the hunt

Three shapes now account for every defect found today:

1. **A bounded read treated as complete** — `listAll`'s 1000, PostgREST's `max_rows`, the batch
   loop's 200 iterations, and `req.json()` with no ceiling.
2. **A list that enumerated the present** — 0002's roles, 0010's tables.
3. **A design that contradicted itself across sections** — §4.7's prose vs its own DDL, §2.4 vs the
   PRD's CheckpointResult, §15.4's revisit condition vs §15.7's timeout change.

Each now has a guard keyed on a property rather than on a name, which is the only form that
survives the next addition.
