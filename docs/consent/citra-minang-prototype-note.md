# Prototype inclusion note — WR Padang Citra Minang (dev test point)

**Place id:** `citra-minang`
**Consent record:** `challange-5/Packages/Kultara/Sources/ContentKit/Content/consent/citra-minang.json`
**Model:** D1-b — self-grant for an academic prototype (plan `c1-badung-single-quest-content.plan.md`, §E0)

## What this document is

A second standalone Place, SideQuest (`sq-citra-minang`) and slot in the `sidequest-test`
collection created purely for local proximity-notification testing, additive only — nothing in
`places/badung-museum-bali.json`, `sidequests/sq-badung-museum-bali.json`, or the `badung-jejak`
collection was touched to make this.

WR Padang Citra Minang is a real, walkable location used as a stand-in coordinate, distinct from
the first test point (`park23`), so a tester can trigger two separate sidequest notices from the
same general area. The sidequest layered on top of it (`sq-citra-minang`) still tells the Museum
Bali story — the same "Arsitektur yang Dipinjam" lore and quiz challenge as
`sq-badung-museum-bali` — so a tester can exercise the quiz-flavoured challenge (as opposed to the
photo challenge `sq-park23` already covers) without traveling to Bali.

## What must happen before anything public

- Removed from `manifest.json` entirely once device testing is done — this is not shipping content.

## Open TODO

- Delete `places/citra-minang.json`, `consent/citra-minang.json`, this note,
  `sidequests/sq-citra-minang.json`, and their manifest/collection entries once the proximity flow
  has been verified on a device.
