# Consent log

One row per Place in the shipped content bundle. This file is the tracking record `NFR-GOV-01`
depends on: the JSON under `Content/consent/` is what the validator reads, and this is what a human
reads to find out whether that JSON describes a real permission or a placeholder.

**Current state: none of the five sites has been approached.** Every record below is a **D1-b
self-grant** — a written statement by the project team that the site is named in a non-public
academic prototype, with scope limited to inclusion and naming. It is not a permission from the
site. See `.claude/plans/Content/c1-badung-single-quest-content.plan.md` §E0 for the decision, and
`docs/consent/<placeId>-prototype-note.md` for each statement.

| Place id | Site | Approached? | Date | By whom | Reply | Record status | Scope | Expires |
|---|---|---|---|---|---|---|---|---|
| `badung-puri-agung-pemecutan` | Puri Agung Pemecutan | **No** | — | — | — | D1-b self-grant | inclusion, naming | 2028-12-31 |
| `badung-pura-maospahit` | Pura Maospahit (Grenceng) | **No** | — | — | — | D1-b self-grant | inclusion, naming | 2028-12-31 |
| `badung-pasar-badung` | Pasar Badung | **No** | — | — | — | D1-b self-grant | inclusion, naming | 2028-12-31 |
| `badung-catur-muka` | Catur Muka | **No** | — | — | — | D1-b self-grant | inclusion, naming, photography | 2028-12-31 |
| `badung-museum-bali` | Museum Bali | **No** | — | — | — | D1-b self-grant | inclusion, naming | 2028-12-31 |

## Open TODOs

1. **Team identity is unfilled.** Every consent record carries the literal placeholders
   `[NAMA TIM]`, `[NAMA ANGGOTA 1]`, `[PERAN ANGGOTA 1]` and `[NAMA ANGGOTA 2]`. Fill them before
   the build leaves the team.
2. **Five real approaches are outstanding.** Puri Agung Pemecutan and Pura Maospahit are working
   sites with custodians; Pasar Badung sits under a market authority (Perusahaan Daerah Pasar
   Kota Denpasar); Museum Bali is a UPTD of Dinas Kebudayaan Provinsi Bali; Catur Muka is a public
   monument at a public junction, where the question is the city rather than a private owner.
3. **When a reply arrives**, store the scan or photograph in `docs/consent/`, fill this table's row,
   and rewrite that place's `Content/consent/*.json` with the real granting body and signatory — or
   remove the place from `manifest.json`. A partial route is valid content; a fabricated grant is
   not.

## How to change a row

Nothing here is a permission until the "Reply" column names a person and a date, and
`docs/consent/` holds the artifact. Editing the JSON without editing this file is the failure mode
this file exists to catch.
