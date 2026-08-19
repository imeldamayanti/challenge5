# Prototype inclusion note — Bebek Tepi Sawah (dev test point)

**Place id:** `bebek-tepi-sawah`
**Consent record:** `challange-5/Packages/Kultara/Sources/ContentKit/Content/consent/bebek-tepi-sawah.json`
**Model:** D1-b — self-grant for an academic prototype (plan `c1-badung-single-quest-content.plan.md`, §E0)

## What this document is

An additional standalone Place, SideQuest (`sq-bebek-tepi-sawah`) and slot in the `sidequest-test`
collection created purely for local proximity-notification testing, additive only — nothing in
`places/badung-pura-maospahit.json`, `sidequests/sq-badung-pura-maospahit.json`, or the
`badung-jejak` collection was touched to make this.

Bebek Tepi Sawah is a real, walkable location used as a stand-in coordinate. The sidequest layered
on top of it (`sq-bebek-tepi-sawah`) still tells the Pura Maospahit story — the same "Halaman
Berjenjang" lore and quiz challenge as `sq-badung-pura-maospahit` — so a tester can trigger the flow
near wherever they actually are, without traveling to Bali.

## What must happen before anything public

- Removed from `manifest.json` entirely once device testing is done — this is not shipping content.

## Open TODO

- Delete `places/bebek-tepi-sawah.json`, `consent/bebek-tepi-sawah.json`, this note,
  `sidequests/sq-bebek-tepi-sawah.json`, and their manifest/collection entries once the proximity
  flow has been verified on a device.
