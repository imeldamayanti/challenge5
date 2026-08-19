# Prototype inclusion note — Sovereign Bali Hotel (dev test point)

**Place id:** `sovereign-bali-hotel`
**Consent record:** `challange-5/Packages/Kultara/Sources/ContentKit/Content/consent/sovereign-bali-hotel.json`
**Model:** D1-b — self-grant for an academic prototype (plan `c1-badung-single-quest-content.plan.md`, §E0)

## What this document is

An additional standalone Place, SideQuest (`sq-sovereign-bali-hotel`) and slot in the
`sidequest-test` collection created purely for local proximity-notification testing, additive
only — nothing in `places/badung-pasar-kumbasari.json`, `sidequests/sq-badung-pasar-kumbasari.json`,
or the `badung-jejak` collection was touched to make this.

Sovereign Bali Hotel is a real, walkable location used as a stand-in coordinate. The sidequest
layered on top of it (`sq-sovereign-bali-hotel`) still tells the Pasar Kumbasari story — the same
"Alas Kaki yang Tepat" lore and quiz challenge as `sq-badung-pasar-kumbasari` — so a tester can
trigger the flow near wherever they actually are, without traveling to Bali.

## What must happen before anything public

- Removed from `manifest.json` entirely once device testing is done — this is not shipping content.

## Open TODO

- Delete `places/sovereign-bali-hotel.json`, `consent/sovereign-bali-hotel.json`, this note,
  `sidequests/sq-sovereign-bali-hotel.json`, and their manifest/collection entries once the
  proximity flow has been verified on a device.
