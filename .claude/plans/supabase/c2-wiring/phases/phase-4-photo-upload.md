# Phase 4 — Photo Upload

**Size:** 2 days · **Depends on:** phases 1, 3
**Demo sentence:** "The photograph I took at Catur Muka is in the bucket, twice — full and thumbnail — and the sidequest photograph I took is not, and never will be."

**Status:** `NOT STARTED` · **Started:** — · **Completed:** —

<!-- MAINTAIN THIS FILE. See phase 0's header for the rules. -->

## Goal

Checkpoint photographs reach `app.photos` and the `trip-photos` bucket, linked to the
task result that produced them.

## Why this phase is after push sync

`task_results.photo_id` references `app.photos`, and a task result without its run is
an orphan. The whole ordering is a foreign-key chain and this is one link in it.

## Scope

### Derivatives

- [ ] **Two objects per photograph, not one.** `PhotoStore` writes one file today.
      - full: `{user_id}/{run_id}/{id}.heic` — 1600 px long edge
      - thumb: `{user_id}/{run_id}/{id}_t.heic` — 400 px long edge
- [ ] **No bucket prefix in the object name.** Supabase keeps the bucket in
      `storage.objects.bucket_id`, so `trip-photos/…` makes the policy compare
      `trip-photos` against `auth.uid()` and never match — and the upload fails for a
      reason the error does not name (§14 defect 13).
- [ ] Content type is `image/heic` or `image/jpeg`. The bucket rejects anything else.
- [ ] Under the 10 MiB per-object cap. A downscaled 1600 px HEIC is around 250 KB, so
      the cap exists to reject an un-downscaled original rather than to be approached.

### Row and bytes

- [ ] Row **first**, with `uploaded_at` null. Bytes second. Stamp `uploaded_at` only
      once both objects have landed.
- [ ] `width_px` / `height_px` are the **full derivative's**, so a grid can lay out
      before downloading.
- [ ] `byte_size` is full + thumb, for `FR-SET-03`'s storage report and for orphan
      detection.
- [ ] `captured_at` is the shutter time, not the upload time.

### Linking

- [ ] Resolve `TaskResult.photoRelativePath` to the uploaded `app.photos.id` and send
      it as `photo_id`.
- [ ] `on delete set null` is load-bearing: a photograph the user later removes must
      not take the record of the task with it.

### The sidequest exclusion

- [ ] **A sidequest photograph gets no row and no upload, ever** (`FR-SIDE-13`,
      `NFR-PRIV-01`). `app.photos` carries a comment saying so, with no opt-in that
      reverses it.
- [ ] Two capture paths exist and only one uploads: `QuestPhotoCaptureScreen` does,
      `CameraCaptureView` (the sidequest challenge) does not.
- [ ] Hold it with a **guard, not a comment** — a source-scanning test in the
      `PermissionCallBoundaryTests` family, which already does exactly this kind of
      check by naming the files allowed to do a thing.

### Deletion race

- [ ] `profiles.deleting_at` blocks the storage insert **in policy**, not in client
      code. A rejection during account deletion is an **expected outcome**, not an
      error to retry.
- [ ] The orphan sweeper stays the backstop. The policy narrows the race; the
      migration is explicit that it does not close it.

### Settings

- [ ] Deleting a photograph in Settings deletes both objects and tombstones the row.
- [ ] `FR-SET-03`'s storage report counts what is actually stored, including the thumb.

## Exit criteria

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
