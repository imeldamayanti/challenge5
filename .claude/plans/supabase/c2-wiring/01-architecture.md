# 01 — Architecture

Where sync sits, which seams it uses, and the four rules it is not allowed to break.

## 1. The shape

```
        Features/            view models. Learn nothing. No phase changes these
             │
        RunEngine            rules that write user data. Unchanged by C2 except phase 2's fields
             │
        RunStore  ◄── protocol seam, already exists
             │
    ┌────────┴─────────┐
FileRunStore      SyncCoordinator          NEW, phase 3
 (truth)          reads the store, pushes, marks
                         │
                  SupabaseClient           NEW, phase 1
                  session + transport
                         │
              https://ppwcxmvetmmwliusliac.supabase.co
```

Two things about that diagram are the whole design.

**`FileRunStore` stays the source of truth.** The server is a copy that a second
device can later read. A walk completes, a summary renders and a letter opens with
no network at any point. That is the product, and `AD-3` is why the seam was built
this way in the first place.

**`SyncCoordinator` reads the store; nothing reads the coordinator.** It is not a
decorator that view models call through, and it is not injected into `RunEngine`. It
observes and pushes. The consequence that matters: **deleting it removes syncing and
breaks nothing else.** If a change makes that untrue, the change is wrong.

## 2. Where each new type lives

The placement rule the feature-folder reorg established, applied:

| Type | Folder | Why |
|---|---|---|
| `SupabaseClient` / session | `challange-5/Services/` | A platform edge, like `LocationService` |
| `SyncCoordinator` | `challange-5/Services/` | Only a service uses it |
| `PhotoUploader` | `challange-5/Services/` | Beside `PhotoStore`, which it reads |
| Sync column types (`DeviceID`, `Revision`) | `Packages/Kultara/Sources/RunEngine/` | They are part of the record, and records live there |
| Accuracy bucketing | `Packages/Kultara/Sources/RunEngine/` | A pure value rule — testable in milliseconds with no simulator |
| Wire DTOs (`RunPayload` etc.) | `challange-5/Services/` | Not domain types. Do not put them in `RunEngine` |

**Do not put the wire format in `RunEngine`.** A `Codable` shaped for PostgREST is a
transport concern; putting it on `Run` makes the domain model's JSON encoding a
server contract, and the next schema change becomes a `FileRunStore` migration.

## 3. Composition

`App/KultaraEnvironment.swift` is the composition root and already holds every
service as an `any Protocol` with a default. C2 adds to it the same way:

```swift
let session: any SupabaseSessionProviding
let sync: any RunSyncing
```

Defaults construct the real ones; tests pass doubles. Nothing else changes — the
environment is already the one place that knows how the app is assembled.

`KultaraEnvironment` is `@MainActor`. The transport is not, and must not be: an
upload that hops to the main actor to serialise a photograph will be visible in the
scroll of whatever screen is up.

## 4. The rules

### R1 — No reachability checks, anywhere, in any phase

`AD-3`. The specific mistake this rule exists to prevent is a screen that asks the
network how it feels before deciding what to draw. There are none in this codebase
today and `ImportBoundaryTests.noModuleChecksReachability` keeps it that way.

Sync is attempted. It succeeds or it does not. A failure schedules a retry and tells
nobody.

### R2 — No screen waits on a network call

Not launch, not the quest list, not the summary. A cold launch in airplane mode
reaches the quest list with no session, no spinner and no error surface. The session
is an optimisation, not a precondition (`FR-OFF-01`, `FR-START-08`).

### R3 — `ContentKit` and `RunEngine` gain no network code

Those targets import Foundation and each other. They may not import a Supabase SDK,
`URLSession` usage in them is a smell, and `ImportBoundaryTests` scans the source
tree because on macOS everything compiles regardless of what the app target links.

Phase 2 adds **fields** to `RunEngine`, not transport.

### R4 — Failure is silent to the walker, loud to the log

A sync that cannot reach the server is the normal case, not an error state. It
produces no alert, no banner and no badge. It produces a telemetry event (phase 0 is
already shipping that pipe) and a retry.

The one exception is account deletion, which is a promise: `FR-SET-02` erasure has to
be able to tell the user whether the server copy is gone.

## 5. Transport choice — decided: `supabase-swift`

**Decided 2026-08-21 by the owner: the SDK.** `supabase-swift` **2.55.1**, pinned
`upToNextMinor`, linked to the **app target only** — `ContentKit`, `RunEngine` and
`DesignSystem` stay Foundation-and-each-other, which is what `ImportBoundaryTests`
holds and what keeps `swift test` a two-second macOS run.

What it buys is the part C2 would otherwise have to write and get wrong: auth token
refresh (phase 1, phase 6), storage upload (phase 4) and PostgREST query building
(phase 3).

Four things about how it is wired, each a decision rather than a default:

- **Four products are linked, not the umbrella**: `Auth`, `PostgREST`, `Storage`,
  `Functions`. **`Realtime` is deliberately absent.** It holds a WebSocket open, which
  is a battery cost on a walking app for a feature C2 has none of — and a client that
  keeps a socket up is one step from behaving like the reachability check `AD-3` bans.
  Linking the `Supabase` umbrella would pull it in, along with CryptoSwift and
  swift-secp256k1, neither of which is otherwise resolved.
- **Six transitive packages arrive with it**: swift-crypto, swift-asn1,
  swift-http-types, swift-concurrency-extras, swift-clocks, xctest-dynamic-overlay.
  That is the real price of this decision in a repo that had exactly zero third-party
  dependencies. It is not hidden by being conventional.
- **`Package.resolved` is now tracked** for the app project, and `.gitignore` carries a
  narrow negation to allow it. Ignoring it was harmless while every package was local;
  with a third-party graph it means every machine and every CI run is free to resolve
  something different, which is a supply-chain hole rather than a convenience.
- **The seam does not move.** `SupabaseClient` still lives in `challange-5/Services/`
  and everything above it is unaware, exactly as §2 says. If the SDK turns out to be
  the wrong call, replacing it is work inside one folder.

## 6. Ordering of a push

Fixed by foreign keys, and migration 0006 was written in this order deliberately:

```
runs → photos → checkpoint_results → task_results → awards
```

`task_results.photo_id` references `app.photos`, so a photo row must exist before the
task result that names it. `app.photos` is therefore created before
`checkpoint_results` in the migration, and pushed before it here.

`app.profiles` is **not in this sequence.** It carries no `server_seq` and is absent
from the design's push order. Its counts derive from `runs` and `awards`; do not add
denormalised counters that can drift.

## 7. What happens on a conflict

Nothing, in C2. Push-only means the device is the only writer, so
`resolve_sync_conflict` has nothing to arbitrate. The triggers stay armed because
they cost nothing and because pull sync is a later phase that will need them.

If a push is rejected as a conflict anyway, that is a bug in this plan's assumption,
not a case to handle silently — log it and stop pushing that row.
