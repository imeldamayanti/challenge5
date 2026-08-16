# Consent request pack — the five Badung sites

**Produced 2026-08-16 as desk work.** It invents nothing. Every claim about who to approach comes
from `docs/consent-log.md` and `docs/consent/*-prototype-note.md`; where those documents do not name
a person, this one does not either.

**Nothing here is a consent record and nothing here may be copied into one.** A consent record is
rewritten only when a reply exists and is stored in `docs/consent/`. See "How to change a row" in
`docs/consent-log.md` — editing the JSON without editing the log is the failure that file exists to
catch.

---

## 0. Where this stands, in one paragraph

Five real places ship in `badung-empat-wajah`. **None of the five has been approached.** Every
`Content/consent/badung-*.json` names the *project team* as `grantingBody` under model D1-b — a
self-grant, written so the build-time validator (V4, V5, `NFR-GOV-01/02/03/07`) has a resolvable,
non-fabricated record to check, and written so it can never be mistaken for a permission. All five
records still carry literal placeholders where a signatory belongs. The build is green. It is not
cleared.

## 1. Blockers, listed first because they block all five approaches equally

| # | Blocker | Why it blocks | Who resolves it |
|---|---|---|---|
| B1 | `[NAMA TIM]` — the project/team name is unfilled in all five consent records | An approach cannot say who is asking. A letter from an unnamed team is not answerable | the team |
| B2 | `[NAMA ANGGOTA 1]`, `[PERAN ANGGOTA 1]`, `[NAMA ANGGOTA 2]` — signatories unfilled | `NFR-GOV-07` wants a named individual because "the team" owning a relationship means nobody does | the team |
| B3 | The app has no name (`CLAUDE.md`, Known state). "Kultara" is a research partner's name, not a brand; "Hisplora" is a Figma file | An approach has to name the thing the site would appear in. Using "Kultara" would imply a partnership that has not been agreed | product |
| B4 | No decision on whether the build stays non-public | Every record's scope is written for "a non-public academic prototype". A public release is a different ask and needs a different letter | product |

**B1–B3 must be resolved before any of the five approaches below is made.** They are not
per-site problems; they are the same problem five times.

## 2. What is being asked for, in every case

Identical across all five, and deliberately minimal:

| Scope | What it means concretely | Currently self-granted? |
|---|---|---|
| **inclusion** | The place appears as a checkpoint on a walking route in the app | Yes, all five |
| **naming** | The place is referred to by its real official name | Yes, all five |
| **photography** | The app offers the walker a photo task at the site | Yes, **`badung-catur-muka` only** |

Not asked for, and it matters that this is said explicitly when approaching: **no imagery of any
site is bundled with the app**, and no site's imagery is reproduced anywhere. The app ships type on
paper, not photographs of these places.

Also worth stating in any approach, because it is unusual enough to be reassuring: the app collects
no user identifier, sends no coordinates off the device, and works entirely offline. A custodian
asking "what are you doing with data about visitors to my site" has a short and true answer: nothing.

## 3. Per site

Each block states: who to approach (as far as the existing documents establish it), what the
self-grant currently claims, and what changes if they decline. The "who" column is a **starting
point derived from the consent log**, not a contact list — no names, no phone numbers and no email
addresses are invented here.

---

### 3.1 Puri Agung Pemecutan — `badung-puri-agung-pemecutan`

- **Role on the route:** checkpoint 1, the start. `FR-START-08` means the walk cannot begin
  anywhere else, so a decline here does not shorten the quest — it ends it in its current form.
- **Who to approach:** the puri's custodians. `docs/consent-log.md` §2 records this as "a working
  site with custodians" and names no individual. A working puri is a family seat as well as a
  heritage site; the approach is to the household that holds it, in person, not by form.
- **Self-grant currently claims:** inclusion and naming, scope-limited, expiring 2028-12-31,
  `grantingBody` = the team.
- **Additional exposure here:** this is the only site whose lore is *also* unsourced — both of its
  `sources` entries begin `BELUM DIVERIFIKASI` (§5 below). An approach to the custodians is
  simultaneously the most likely route to a real source for the puri's history. **Those are two
  different asks and should not be collapsed into one**: permission to include is not permission to
  publish whatever the household says about its own ancestry, and a history given verbally becomes
  an `oral` lore block with its own consent trail (plan D2).
- **If they decline:** the quest cannot start here. Either the route is re-authored from checkpoint
  2 onwards with a new start — which changes `hardLatestStart` (V16), the route geometry, the
  distance, and the clue text of every checkpoint before it — or the quest is withdrawn. The quest
  id is pinned into `Run.questID`, so it is not renamable (`CLAUDE.md`, Known state).

### 3.2 Pura Maospahit (Grenceng) — `badung-pura-maospahit`

- **Role on the route:** checkpoint 2. `isSacred: true`.
- **Who to approach:** the pura's custodians (*pemangku* / the banjar that maintains it).
  `docs/consent-log.md` §2 records this as "a working site with custodians" and names no individual.
- **Self-grant currently claims:** inclusion and naming. Photography is **not** in scope here, and
  the photo policy in the content is `restricted` rather than `prohibited` — authored conservatively
  because a guessed prohibition would be as wrong as a guessed permission (plan §11.0).
- **The question to actually ask:** an active temple's answer is likely to be conditional rather
  than yes or no — dress code, ceremony days, which courtyards. Those conditions are *content*
  (`dressCode`, `visitingHours`, `photoPolicy.notes`), so the approach should be prepared to
  record them, not just to collect a signature.
- **If they decline:** checkpoint 2 is removed. The route re-orders (checkpoints are ordered and
  `orderIndex` is contiguous), the geometry and distance are re-measured, and checkpoint 1's
  `clueToNext` is rewritten. A four-stop quest is valid content; the four-faces reading the quest is
  *about* survives, since it is a reading of the city rather than a count of stops.

### 3.3 Pasar Kumbasari — `badung-pasar-kumbasari`

- **Role on the route:** checkpoint 3.
- **Who to approach:** the market authority. `docs/consent-log.md` §2 names it:
  **Perusahaan Daerah Pasar Kota Denpasar**. This is the one site whose owner is an institution with
  an office rather than a household — an approach here is a letter, and it is the approach most
  likely to want B3 (a product name) answered first.
- **Self-grant currently claims:** inclusion and naming.
- **Worth raising in the same conversation:** the market is covered, and `FR-ARR-01`'s accuracy
  condition will legitimately fail inside it (plan §11, item 3). That is a walker-experience problem
  the manual override already answers (`FR-START-10`) — it is not a consent question, but the market
  authority is the party who would notice people standing in the aisles tapping at phones.
- **If they decline:** checkpoint 3 is removed, same consequences as §3.2. Kumbasari is also the
  only site whose accessibility data is verified (four storeys, stairs only), so the route loses its
  one confirmed `NFR-A11Y-07` disclosure.

### 3.4 Catur Muka — `badung-catur-muka`

- **Role on the route:** checkpoint 4. The monument the quest's four-faces reading is named for.
- **Who to approach:** `docs/consent-log.md` §2 is explicit that this one is different — "a public
  monument at a public junction, where the question is the city rather than a private owner". So the
  approach is to the municipal authority for public monuments in Denpasar, and the question is
  narrower: not *may we include it*, but *is there a permission needed to direct people to
  photograph it*.
- **Self-grant currently claims:** inclusion, naming **and photography** — the only one of the five
  with photography in scope, because the quest offers a photo task here.
- **If they decline the photography scope only:** the photo task is removed from checkpoint 4 and
  the place's `photoPolicy.level` becomes `prohibited`. `FR-TASK-06` and validator rule V9 then do
  the rest automatically — the runtime filter in `QuestRunViewModel.presentation(forOrderIndex:)`
  will not offer the task, and the validator rejects content that tries. **Nothing else about the
  route changes**, because `AD-2` means tasks never gate progression.
- **If they decline inclusion entirely:** unlikely for a public monument on a public junction, and
  it would remove the checkpoint the quest's title imagery rests on.

### 3.5 Museum Bali — `badung-museum-bali`

- **Role on the route:** checkpoint 5, the finish. Its hours are the only *verified* hours on the
  route, and V16 binds `hardLatestStart` to them — so this site's data is load-bearing for the whole
  quest's late-start warning (`FR-DISC-06`).
- **Who to approach:** `docs/consent-log.md` §2 names the chain: Museum Bali is a **UPTD of Dinas
  Kebudayaan Provinsi Bali**. A provincial cultural-affairs department, not the museum desk.
- **Self-grant currently claims:** inclusion and naming.
- **The other thing to resolve in the same approach:** the museum **sells a ticket**, and the
  content ships `entryCost: 0` because the price is not verified (plan §11.0). That is a placeholder
  that will actively misinform a walker about money. The ticket price is the single highest-value
  unverified value on the whole route, and this is the approach that gets it.
- **If they decline:** the quest loses its finish. Consequences as §3.2, plus `hardLatestStart` must
  be recomputed against whatever the new earliest-closing site is — which, given every other site's
  hours are unverified (§5), means the late-start warning would be resting on a guess.

## 4. What a reply has to contain before any record changes

From `docs/consent-log.md`, restated so an approach knows what to come back with:

1. A named person and their role — `grantedByName`, `grantedByRole`.
2. The granting body, as the institution's own name — `grantingBody`.
3. A date — `grantedAt` — and an expiry the body is willing to state — `expiresAt`.
4. The scope actually agreed, from {inclusion, naming, photography, imagery}.
5. An artifact: a scan, a photograph, a signed letter, an email. Stored in `docs/consent/`.

Then, and only then: fill the row in `docs/consent-log.md`, rewrite that place's
`Content/consent/*.json`, and bump `contentBundleVersion` in `manifest.json` — every content change
must (`CLAUDE.md`).

**A partial route is valid content. A fabricated grant is not.**

## 5. The relationship to the content verification checklist

`docs/field-verification-checklist.md` is the other half of this. Several items overlap on purpose —
the ticket price at Museum Bali, the temple's real dress code, the market's hours — because the same
visit that asks for permission is the visit that can capture them. They are kept in separate
documents because they fail differently: an unverified opening time makes the app wrong, and a
missing consent record makes the project's claim to be a heritage project untrue.
