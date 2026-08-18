# Prototype inclusion note — Park 23 XXI (dev test point)

**Place id:** `park23`
**Consent record:** `challange-5/Packages/Kultara/Sources/ContentKit/Content/consent/park23.json`
**Model:** D1-b — self-grant for an academic prototype (plan `c1-badung-single-quest-content.plan.md`, §E0)

## What this document is

A standalone Place, SideQuest (`sq-park23`) and collection (`sidequest-test`) created purely for
local proximity-notification testing, additive only — nothing in `places/badung-catur-muka.json`,
`sidequests/sq-badung-catur-muka.json`, or the `badung-jejak` collection was touched to make this.

Park 23 XXI is a real, walkable location used as a stand-in coordinate. The sidequest layered on
top of it (`sq-park23`) still tells the Catur Muka story — the same "Empat Arah" lore and photo
challenge as `sq-badung-catur-muka` — so a tester can trigger the whole flow (notice → arrival →
story → challenge → letter) near wherever they actually are, without traveling to Bali.

## What must happen before anything public

- Removed from `manifest.json` entirely once device testing is done — this is not shipping content.

## Open TODO

- Delete `places/park23.json`, `consent/park23.json`, this note, `sidequests/sq-park23.json`,
  `collections/sidequest-test.json`, and their manifest entries once the proximity flow has been
  verified on a device.
