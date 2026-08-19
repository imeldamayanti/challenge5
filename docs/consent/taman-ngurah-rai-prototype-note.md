# Prototype inclusion note — Taman Bundaran Ngurah Rai (dev test point)

**Place id:** `taman-ngurah-rai`
**Consent record:** `challange-5/Packages/Kultara/Sources/ContentKit/Content/consent/taman-ngurah-rai.json`
**Model:** D1-b — self-grant for an academic prototype (plan `c1-badung-single-quest-content.plan.md`, §E0)

## What this document is

An additional standalone Place, SideQuest (`sq-taman-ngurah-rai`) and slot in the `sidequest-test`
collection created purely for local proximity-notification testing, additive only — nothing in
`places/badung-catur-muka.json`, `sidequests/sq-badung-catur-muka.json`, or the `badung-jejak`
collection was touched to make this.

Taman Bundaran Ngurah Rai is a real, walkable location used as a stand-in coordinate. The sidequest
layered on top of it (`sq-taman-ngurah-rai`) still tells the Catur Muka story — the same "Empat
Arah" lore and photo challenge as `sq-badung-catur-muka` (and as `sq-park23`, the first test point
reusing this same story) — so a tester can trigger the flow near wherever they actually are, without
traveling to Bali.

## What must happen before anything public

- Removed from `manifest.json` entirely once device testing is done — this is not shipping content.

## Open TODO

- Delete `places/taman-ngurah-rai.json`, `consent/taman-ngurah-rai.json`, this note,
  `sidequests/sq-taman-ngurah-rai.json`, and their manifest/collection entries once the proximity
  flow has been verified on a device.
