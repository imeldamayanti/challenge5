# Prototype inclusion note — Mahen Living (dev test point)

**Place id:** `mahen-living`
**Consent record:** `challange-5/Packages/Kultara/Sources/ContentKit/Content/consent/mahen-living.json`
**Model:** D1-b — self-grant for an academic prototype (plan `c1-badung-single-quest-content.plan.md`, §E0)

## What this document is

An additional standalone Place, SideQuest (`sq-mahen-living`) and slot in the `sidequest-test`
collection created purely for local proximity-notification testing, additive only — nothing in
`places/badung-puri-agung-pemecutan.json`, `sidequests/sq-badung-puri-agung-pemecutan.json`, or the
`badung-jejak` collection was touched to make this.

Mahen Living is a real, walkable location used as a stand-in coordinate. The sidequest layered on
top of it (`sq-mahen-living`) still tells the Puri Agung Pemecutan story — the same "Rumah yang
Masih Dihuni" lore and quiz challenge as `sq-badung-puri-agung-pemecutan` — so a tester can trigger
the flow near wherever they actually are, without traveling to Bali.

## What must happen before anything public

- Removed from `manifest.json` entirely once device testing is done — this is not shipping content.

## Open TODO

- Delete `places/mahen-living.json`, `consent/mahen-living.json`, this note,
  `sidequests/sq-mahen-living.json`, and their manifest/collection entries once the proximity flow
  has been verified on a device.
