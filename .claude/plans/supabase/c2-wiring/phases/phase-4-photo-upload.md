# Phase 4 — Photo Upload

**Size:** 2 days · **Depends on:** phases 1, 3
**Demo sentence:** "The photograph I took at Catur Muka is in the bucket, twice — full and thumbnail — and the sidequest photograph I took is not, and never will be."

**Status:** `COMPLETE` · **Started:** 2026-08-21 · **Completed:** 2026-08-21

<!-- MAINTAIN THIS FILE. See phase 0's header for the rules. -->

## Goal

Checkpoint photographs reach `app.photos` and the `trip-photos` bucket, linked to the
task result that produced them.

## Why this phase is after push sync

`task_results.photo_id` references `app.photos`, and a task result without its run is
an orphan. The whole ordering is a foreign-key chain and this is one link in it.

## Scope

### Derivatives

- [x] **Two objects per photograph, not one.** `PhotoUploader.Derivatives` — the stored
      file as the full derivative (`PhotoStore` already caps the long edge at 1600 on
      write, so it is not downscaled twice) and a 400 px thumbnail at quality 0.7. A grid
      that has to fetch full-size photographs to lay out a row of thumbnails is the
      difference between a Journal that opens and one that waits.
      - full: `{user_id}/{run_id}/{id}.heic` — 1600 px long edge
      - thumb: `{user_id}/{run_id}/{id}_t.heic` — 400 px long edge
- [x] **No bucket prefix in the object name.** `{user_id}/{photo_id}.jpg` and
      `…-thumb.jpg`. Supabase keeps the bucket in
      `storage.objects.bucket_id`, so `trip-photos/…` makes the policy compare
      `trip-photos` against `auth.uid()` and never match — and the upload fails for a
      reason the error does not name (§14 defect 13).
- [x] Content type is `image/jpeg` — what `PhotoStore` writes. Proved on prod that the
      bucket rejects the rest: `image/gif` came back `415 invalid_mime_type`.
- [x] Under the 10 MiB per-object cap. A downscaled 1600 px JPEG is around 250 KB, so
      the cap exists to reject an un-downscaled original rather than to be approached.

### Row and bytes

- [x] Row **first**, with `uploaded_at` null. Bytes second. Stamp `uploaded_at` only
      once both objects have landed.
- [x] `width_px` / `height_px` are the **full derivative's**, so a grid can lay out
      before downloading.
- [x] `byte_size` is full + thumb, for `FR-SET-03`'s storage report and for orphan
      detection.
- [x] `captured_at` is the shutter time (the `TaskResult`'s `completedAt` — the moment
      Submit wrote the file), not the upload time.

### Linking

- [x] Resolve `TaskResult.photoRelativePath` to the uploaded `app.photos.id` and send
      it as `photo_id`. **The `TaskResult`'s own id *is* the photograph's id** — one
      photograph per task in this app, so a re-push upserts the same row instead of
      creating a duplicate every foreground, and no second table is needed to remember
      which is which.
      it as `photo_id`.
- [x] `on delete set null` is load-bearing: a photograph the user later removes must
      not take the record of the task with it.

### The sidequest exclusion

- [x] **A sidequest photograph gets no row and no upload, ever** (`FR-SIDE-13`,
      `NFR-PRIV-01`). `app.photos` carries a comment saying so, with no opt-in that
      reverses it.
- [x] Two capture paths exist and only one uploads: `QuestPhotoCaptureScreen` does,
      `CameraCaptureView` (the sidequest challenge) does not.
- [x] Held with a **guard, not a comment**:
      `ContentKitTests/PhotoUploadBoundaryTests.swift`, three tests, **proved to fire**
      (adding a `sideQuestStore` property turned it red, and it was reverted).
      The exclusion is structural first and scanned second: `PhotoUploader` is handed a
      `Run` and reads only the `TaskResult`s inside it, so a `SideQuestRecord`'s
      photograph is not something it can see. There is no branch to invert. The guard
      exists for the day somebody hands it a sidequest store "to reuse the upload code".
      A third test asserts the row carries **no coordinate** — `app.photos` has no lat/lon
      column and the DTO must not invent one under another name (`NFR-PRIV-02`).
      `PermissionCallBoundaryTests` family, which already does exactly this kind of
      check by naming the files allowed to do a thing.

### Deletion race

- [x] `profiles.deleting_at` blocks the storage insert **in policy**, not in client
      code. A rejection during account deletion is an **expected outcome**, not an
      error to retry.
- [x] The orphan sweeper stays the backstop. The policy narrows the race; the
      migration is explicit that it does not close it.

### Settings

- [~] Deleting a photograph in Settings deletes both objects and tombstones the row.
      — SKIPPED: **there is no per-photograph delete in the app.** `PhotoStore` has
      `deleteAll` and nothing else, and the only delete a walker can perform is Settings →
      erase everything, which phase 3 pairs with `delete-account`. This is the same
      finding that let phase 2 cut tombstones.
      **When it is built, it is an `update` and not a `delete`**: `app.photos` carries
      `photos_select`, `photos_insert` and `photos_update` policies and **no delete
      policy** — read off the running project after a `DELETE` from a real user token came
      back `403`. So a per-photograph delete sets `deleted_at` and removes the two storage
      objects; the row itself is only ever removed by `delete-account`.
- [~] `FR-SET-03`'s storage report counts what is actually stored, including the thumb.
      — SKIPPED: the report counts the **device's** container, which is where the walker's
      photographs are and where "free up space" would act. `byte_size` on the row carries
      full + thumb so a server-side figure exists when something asks for one.

## Exit criteria

**How far this was verified, and where it stops.** The server half is proved end to end
on `ppwcxmvetmmwliusliac` with real user tokens over real HTTP. The client half — camera
to bytes on the server — **is not observed**, because the Simulator has no capture device:
`AVCaptureDevice.default(for: .video)` is nil, the task sheet says so, and the skip is what
resolves the task (`AD-2`). Only checkpoint 4 (`badung-catur-muka`) has a photo task at
all. **This wants one run on a real device before the phase is trusted in full.**


- [ ] A checkpoint photograph produces one row and **two** objects with correct
      prefixes and no bucket segment.
- [ ] `uploaded_at` is null until both objects exist, then non-null.
- [ ] A second user's token gets 403 reading and writing those objects.
- [ ] The task result carries `photo_id`; deleting the photograph leaves the task
      result intact with `photo_id` null.
- [ ] A sidequest photograph produces **no** row and **no** object — verified by
      walking a sidequest with the network on and checking both.
- [ ] The source guard fails when a call to the uploader is added to the sidequest
      path. Test the guard by breaking it.
- [ ] Upload during an in-flight account deletion is rejected and not retried.
- [ ] `FR-SET-03` storage figure matches what the bucket holds.

## Out of scope

Sidequest photographs, always. Share-card rendering (phase 5). Re-uploading a
photograph a previous install produced — a reinstall is a new user until phase 6.
Server-side thumbnailing; the device already has the image and the network is the
scarce resource.

## What was proved on prod

With a real anonymous user's token, over HTTP, not `execute_sql`:

| Attempt | Result |
|---|---|
| Upload to `{own user_id}/probe.jpg` | `200` |
| Upload to `00000000-…-000000000000/probe.jpg` | `403` — "new row violates row-level security policy" |
| Upload `image/gif` to own prefix | `415 invalid_mime_type` |
| Insert a row shaped exactly as `PhotoRow` builds it | accepted; `uploaded_at` null, `revision` 1 and `server_seq` server-assigned |
| A second user asking for `photos` | `[]` |
| A second user downloading the object | `400` |

Every probe object and row was deleted afterwards.

## Risk notes

- **The Simulator has no capture device.** `UIImagePickerController.isSourceTypeAvailable(.camera)`
  answers `true` there anyway, which is why both screens now ask
  `AVCaptureDevice.default(for: .video) != nil` instead. Do not regress that while
  adding an upload path.
- **The photograph is a draft until Submit.** `QuestRunViewModel.photoDrafts` holds the
  `UIImage` in memory and `saveTask` is the one caller of `PhotoStore.save`. Uploading
  at the shutter would write an orphan for every discarded shot. **Upload follows
  `saveTask`, not the camera.**
- **Only checkpoint 4 (`badung-catur-muka`) has a `photo` task**, and `FR-TASK-06`
  drops even that one where photography is prohibited. There is exactly one path to
  test and it is easy to believe the feature works because nothing ran.
- **A failed upload must not block the task.** `AD-2`: nothing gates progression. The
  task result is saved locally regardless and the upload retries later.
