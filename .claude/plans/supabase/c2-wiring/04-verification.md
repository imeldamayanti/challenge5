# 04 — Verification

How each phase is proved. None of it is "it looked right on device".

## 1. The rule that matters most

**Isolation is proved over HTTP with a real user token.**

`execute_sql` and the Supabase MCP run elevated and bypass RLS. They can tell you
what a table contains. They can tell you nothing about who is allowed to read it, and
a test written with them will pass against a completely open database.

`b3` §4 established this and `supabase/tests/http/` is where those suites live.

## 2. Where each kind of test goes

| Kind | Home | Needs a simulator |
|---|---|---|
| Pure value rules — accuracy bucketing, revision arithmetic, path construction | `Packages/Kultara/Tests/RunEngineTests` | no |
| Source-scanning guards — "no sidequest photo is uploaded", "no module checks reachability" | `Packages/Kultara/Tests/ContentKitTests` (`ImportBoundaryTests`, `PermissionCallBoundaryTests`) | no |
| View models, presentation | `challange-5Tests` | yes |
| RLS, isolation, storage authorization | `supabase/tests/http/` (Deno) | no, but needs `functions serve` |
| Structure, constraints, triggers | `supabase/tests/*` (pgTAP) | no |

**Prefer the package.** A rule pushed down as a pure value runs in milliseconds on
macOS. The arrival countdown, the map-marker tap threshold and the route maths all
went that way for reasons that have not changed.

**A guard that can be checked by reading source belongs in `ContentKitTests`**, which
links nothing and scans the tree by walking out from `#filePath`. That is why guards
about the *app* target run in two seconds without Xcode.

## 3. Per-phase proof

| Phase | Proof |
|---|---|
| **0** | A place suppressed in `ops.suppressions`, published, then observed disappearing from the app after a foreground. A walked checkpoint produces rows in `ops.events`, queried back. The app still launches with the document unreachable |
| **1** | Cold install produces a JWT. **Airplane-mode cold launch reaches the quest list** with no session, no spinner, no error. Relaunch reuses the session rather than making a second user |
| **2** | Package suite green. A `Run` written by the **pre-C2** shape still decodes. A deleted run is a tombstone, not an absence. Bucketing: 19.9 → `lt20`, 20 → `b20_75`, 75 → `b20_75`, 75.1 → `gt75` |
| **3** | Complete a walk with the network off, relaunch with it on, read the rows back over HTTP **with the walker's own token**. A second user's token gets zero rows for the same ids. Push twice — the second is a no-op, not a duplicate |
| **4** | Two objects per photograph with correct prefixes and no bucket segment. `uploaded_at` non-null only after both land. A second user's token gets 403 on read and on write. A photograph deleted in Settings leaves the task result intact with `photo_id` null |
| **5** | A **signed-out** client opens a minted link. After `revoked_at`, the same link fails. After `expires_at`, the same link fails. A slug that was never minted 404s rather than erroring |
| **6** | Walk anonymously, link Apple, the walk is still there and under the same `user_id`. Link Google to a **different** anonymous user, and the two do not merge into each other |

## 4. Running things

From `challange-5/Packages/Kultara`:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

From `challange-5/`:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export PATH="$DEVELOPER_DIR/usr/bin:$PATH"
"$DEVELOPER_DIR/usr/bin/xcodebuild" test -project challange-5.xcodeproj -scheme challange-5 \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

Pin `OS=`. Four runtimes are installed and one carries no devices at all, so an
unpinned destination can resolve onto the empty one and fail for a reason that has
nothing to do with the code.

From the repository root, with Docker running:

```bash
supabase start
supabase db reset && supabase db lint -s app,ops,catalog,public --fail-on warning && supabase test db
deno test --allow-net --allow-env --allow-run supabase/tests/http/
```

**`supabase functions serve` must be running** for any Deno suite that touches a
function. On this machine `supabase start` brings up no edge-runtime container, so
without it every function test fails with `503 {"message":"name resolution failed"}`
— which reads like a code failure and is not one.

## 5. Four pre-existing package failures are not yours

Do not chase these while working on C2. All four predate it:

- `PlaqueGeometryTests.theCornerIsAScoopArcedAboutTheCornerPointItself`
- `PermissionCallBoundaryTests.theAppUsesNoBackgroundLocationAndNoTrackingPrompt` — a
  real finding about `SideQuestProximityService`, unrelated to wiring
- `BundledContentRepositoryTests` × 2 — stale expectations about content counts and
  the bundle version

Three XCUITests are also red and pre-existing, re-verified 2026-08-20 in a clean
worktree at `65f9465`.

**If C2 makes a fifth thing red, it is yours.** Know the baseline before you start.

## 6. Prod is not precious yet, and phase 1 ends that

`b3` §1.1: prod holds no real users, which is the only reason a `db reset` on it would
still be survivable.

**Phase 1 is the phase that stops being true.** The moment the app creates anonymous
sessions in the field, there is user data in that project, and every later phase is
working against a database that cannot be reset. Ship phase 1 to a build that reaches
people only when that is understood.
