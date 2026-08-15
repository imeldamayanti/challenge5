# S5 — The content, and why it is the hard part

Phase E. Runs in parallel with A–D and is the thing most likely to stop this shipping.

## 1. The governance problem, stated plainly

A 15-letter phrase means 15 places. Every one of them needs, before it can ship:

| Needed | Rule that enforces it | Today, for the five existing places |
|---|---|---|
| A consent record, granted and unexpired | V4, `NFR-GOV-01/03` — **build failure**, not review | present, but a **self-grant**: the project team named itself `grantingBody`; none of the five sites has been approached |
| A named grantor, their role, a named region owner | V5, `NFR-GOV-02/07` | literal placeholders — `[NAMA TIM]`, `[NAMA ANGGOTA 1]` |
| At least one source per place | V2, `NFR-CONT-02` | present |
| A resolvable source per claim | V3, `NFR-CONT-01` | present, but many citations begin `BELUM DIVERIFIKASI` |
| Verified coordinates | none — the validator checks range, not geography | **every coordinate is an unwalked seed value** |

So the honest position is: the app cannot today ship five places' worth of verified, consented content,
and this feature asks for fifteen. That is not an argument against the feature; it is the sequencing
constraint, and pretending otherwise produces a demo that cannot become a release.

## 2. The recommendation: start with a shorter phrase

Ship the mechanic on a phrase the content team can actually stand behind, and grow it later.

| Phrase | Letters | Places | Verdict |
|---|---|---|---|
| `BADUNG` | 6 | 6 | achievable — the five existing places plus one |
| `BALI THE EXPLORER` | 15 | 15 | the target, once consent scales |
| anything longer | — | — | not before a second region owner exists |

Growing the phrase later is a content change and a `contentBundleVersion` bump. It is **not**
backward-compatible for people mid-collection: `BADUNG` completed and then extended to
`BALI THE EXPLORER` either reopens a finished collection or strands a badge.

Resolve it by authoring the long collection as a **new collection id** and leaving the old one
complete. Records point at `collectionID`, so an old record keeps its old collection and the new one
starts empty. Never edit a shipped collection's `phrase` or `slots`.

## 3. Place selection criteria

For each candidate place, in this order:

1. **Consent is obtainable.** A named person at the site or its managing body who can grant inclusion
   and naming, with a document reference. If this fails, stop — the rest is wasted work.
2. **At least two openable citations** for the claims the story makes. `documented` claims need a
   written source; `oral` claims need an attributable telling, and `SourceKind.interview` exists for
   exactly that.
3. **A public standing point** where a walker can hold a phone for two minutes without being in the
   way, in traffic, or inside a ceremony. `NFR-SAFE` and `FR-TASK-05` both bear on this.
4. **A coordinate someone has stood on**, with the radius chosen there. 30–250 m (V20); a wide-open
   square takes 150 m, a specific gateway takes 50 m.
5. **A photo policy and a dress code that were asked about**, not assumed. Four of the five existing
   places carry unverified answers to both.

## 4. Per-sidequest authoring checklist

```
sidequests/sq-<place-id>.json
├── placeId ─────────── an existing places/<id>.json, listed in the manifest
├── title ───────────── both languages
├── synopsis ────────── ≤ 140 characters; it is read on a lock screen while walking
├── lore ────────────── 2–4 LoreBlocks, each with accuracy and sourceRefs into the Place's sources
├── challenge
│   ├── quiz ────────── question answerable *from the lore just read*, 3–4 distinct options,
│   │                   one correct, explanation that adds a fact rather than repeating one
│   └── photo ───────── only where photoPolicy is allowed or restricted-with-a-note (V23)
├── triggerRadiusM ──── measured on site
├── noticeRadiusM ───── > triggerRadiusM; 200 m is the placeholder the PRD already flags as unvalidated
└── heroImageAsset ──── optional; a photograph with a known provenance, never a generated likeness
```

**The quiz must be answerable from the story.** A question requiring outside knowledge turns a walk
into a quiz show and, at a temple, turns a visitor into someone who failed. The explanation is where
the extra fact goes.

**No generated portraits of named historical figures.** This was already refused once, in the Hisplora
frames, for the reason that a likeness of a real person is a `FR-CP-05` claim with no source and no
consent record. It applies here identically.

## 5. Collection authoring

- The letter-to-place assignment is arbitrary and should stay arbitrary — do not order places so the
  phrase spells out geographically, because a walker who finds `B`, `A`, `L` in sequence learns the
  route and stops being surprised.
- Slot 0's place should be an easy, public, high-traffic one. It is the first letter most people ever
  see.
- The last letter's place should not be the hardest to reach. A collection that ends in a place with
  restricted access ends unfinished.

## 6. Interaction with the existing quest

Three of the five existing places (`badung-pura-maospahit`, `badung-pasar-kumbasari`,
`badung-catur-muka`) are checkpoints of `badung-empat-wajah`. A sidequest may sit at the same place.

What happens if someone walks the quest through a place that also has a sidequest: nothing. Alerts do
not fire during an active Run (`FR-PROX-08`), and the sidequest stays available afterwards. The story
texts must not be identical, though — reading the same three paragraphs twice, once as a checkpoint and
once as a sidequest, reads as a bug. Author the sidequest lore as a **different angle on the same
place**, and say so in the plan file for that place.

## 7. Files

```
Content/sidequests/sq-badung-puri-agung-pemecutan.json
Content/sidequests/sq-badung-pura-maospahit.json
Content/sidequests/sq-badung-pasar-kumbasari.json
Content/sidequests/sq-badung-catur-muka.json
Content/sidequests/sq-badung-museum-bali.json
Content/sidequests/sq-<new-place>.json                  × as many as the phrase needs
Content/places/<new-place>.json                         one per new place
Content/consent/<new-place>.json                        one per new place — build input
Content/collections/badung.json
Content/manifest.json                                   lists them, version bumped
docs/consent-log.md                                     a row per new place
docs/consent/<new-place>-prototype-note.md              until a real grant exists
```

## 8. What must not survive into anything public

The existing self-granted consent notes are explicit that they are for a non-public academic
prototype. Adding ten more places on the same basis multiplies that exposure. Before any public
release — TestFlight beyond the team included — every place in every shipped collection needs a real
grant from the site, or the place comes out of the collection and the phrase gets shorter.

That is a hard gate, and it is the one to put in front of the product owner early rather than at
submission.
