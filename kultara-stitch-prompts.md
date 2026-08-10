# Kultara — Google Stitch Prompts

How to use: paste **Prompt 0** first to set the design language, then paste screen prompts one at a time
in a new generation. Stitch handles one screen per prompt best — don't paste the whole list at once.
Mode: **Mobile**. If Stitch drifts off-style, re-paste the style block at the top of the screen prompt.

---

## Prompt 0 — Design system / style anchor

```
Design a mobile app called Kultara — a story-led cultural heritage exploration app for travellers in Bali.
Users discover heritage sites on a map, walk to them, and unlock narrative quests on arrival, collecting
story cards and site stamps in a personal journal.

Visual direction:
- Warm, earthy, editorial. Background sandstone off-white (#F7F3EC), deep volcanic charcoal text (#1E1B18),
  single accent of temple gold (#C08A2E). Subtle terracotta secondary (#A9552F).
- Typography: an elegant serif for story/headline text, a clean geometric sans for UI labels and buttons.
- Generous whitespace, 16px screen padding, 16px rounded corners, soft shadows, thin 1px hairline dividers.
- Photography-forward: large edge-to-edge images of temples, stone carvings, and rice-terrace paths.
- Iconography: thin line icons, 24px.
- Feels like a beautifully printed travel journal, NOT a gamified arcade UI. No neon, no cartoon badges.

Persistent bottom tab bar with 3 tabs: Map, Journal, Profile.
```

---

## 01 — Splash

```
Mobile splash screen for Kultara. Centered circular monogram logo mark, wordmark "KULTARA" in serif caps
below it, and the tagline "Walk the story of a place" in small sans caps. Full-bleed warm sandstone
background with a very faint watermark of a Balinese temple gate silhouette. A thin loading bar near the
bottom. Nothing else.
```

## 02 — Onboarding

```
Mobile onboarding screen, slide 1 of 3, for Kultara. A "Skip" text button top right. A large rounded
photograph of a Balinese temple gate filling the top 45% of the screen. Below it, a serif headline
"Every place has a story" and two lines of supporting body text. Below that, a bordered permission card
with a small location-pin icon, the title "Allow location", and one line of body text explaining it is
needed to unlock quests when you arrive at a site. Then a full-width primary "Continue" button in temple
gold, and a 3-dot page indicator at the very bottom with the first dot active as a pill.
```

## 03 — Login

```
Mobile sign-in screen for Kultara. Back arrow top left. Serif headline "Welcome back" and one line of
supporting text. Two outlined text fields: Email, and Password with a show/hide eye icon. A right-aligned
"Forgot password?" link. A full-width primary "Sign in" button. An "or" divider with hairlines on both
sides. A full-width outlined "Continue with Google" button with the Google logo. Pushed to the bottom of
the screen: a full-width outlined "Explore as guest" button, and centered small text "No account? Register"
with Register emphasised. Warm sandstone background.
```

## 04 — Register

```
Mobile sign-up screen for Kultara. Back arrow top left, serif headline "Create your explorer".
Three outlined fields stacked: Display name, Email, Password. Below the password field, a small checkbox
row with helper text "8+ characters, 1 number". A small uppercase label "Pick your interests" followed by
a wrapping row of selectable pill chips: Temples, Craft, Folklore, Food, Dance, Colonial — with Temples and
Folklore shown selected in temple gold. At the bottom, a checkbox row "I agree to Terms & Privacy" and a
full-width primary "Create account" button.
```

## 05 — Map (home)

```
Mobile map home screen for Kultara. Full-screen stylised map of Bali terrain with roads and greenery.
Floating at the top: a rounded white search bar "Search a place or quest" with a search icon on the left
and a bell notification icon on the right; directly under it a horizontal scrolling row of white filter
chips — Nearby (selected, gold), Temples, Folklore, 30 min.
On the map: four custom teardrop location pins, two of them filled gold to show an available quest, plus a
blue dot with a white ring for the user's current position. A circular white "recenter" button floats above
the bottom sheet on the right.
A draggable bottom sheet with a grab handle shows "Nearest to you" with a "See all" link, and one horizontal
place card: square thumbnail photo of a temple, title "Pura Taman Ayun", subtitle "420 m · 45 min quest ·
4 stops", and two small chips "Folklore" and "Easy".
Bottom tab bar with Map selected, plus Journal and Profile.
```

## 06 — Place detail / quest preview

```
Mobile place detail screen for Kultara. Full-bleed hero photograph of a Balinese water temple occupying the
top third, with circular white back and share buttons overlaid in the corners.
Below: serif title "Pura Taman Ayun" with a small outlined "EASY" badge on the right, then grey metadata
"Mengwi, Badung · 420 m away · open 08:00–18:00".
A bordered quest card with a small uppercase label "THE QUEST", a serif title "The Garden That Answered a
King", two lines of atmospheric description, and three chips: 4 stops, ~45 min, Walking.
A section labelled "YOU'LL COLLECT" showing three circular collectible tokens in a row with the caption
"3 story cards + 1 site stamp".
A section labelled "ROUTE PREVIEW" showing a small rounded map thumbnail with a dotted walking path.
A sticky bottom bar with an outlined square heart button and a full-width primary "Start quest" button.
```

## 07 — Start confirmation sheet

```
Mobile screen for Kultara showing a modal bottom sheet over a dimmed, blurred place detail page.
The sheet has a grab handle, a serif headline "Ready to start?", one line of body text explaining that the
quest unlocks step by step as you reach each stop and can be paused any time.
Inside the sheet, a bordered summary card with three label/value rows: Stops — 4, Walking distance — 1.2 km,
Estimated time — 45 min. Below it a checkbox row, checked, reading "Keep location on so stops unlock
automatically". Then a full-width primary "Begin quest" button and an outlined "Not now" button.
```

## 08 — Travelling / location check

```
Mobile active-quest navigation screen for Kultara. Stylised map background with a dotted walking route.
A floating card at the top shows "STOP 1 OF 4" on the left and "Pause" on the right, a thin gold progress
bar, and the instruction "Head to the outer moat gate".
Centered on the map, a set of three concentric dashed proximity rings with a solid gold dot at the middle,
under it a large serif "120 m away" and one line of grey text "Walk closer to unlock the story. We'll buzz
you when you arrive."
A small bottom sheet contains a full-width outlined button "I'm here — unlock manually" with tiny helper
text under it: "GPS weak indoors? Use manual check-in."
```

## 09 — Story step

```
Mobile story screen for Kultara. Full-bleed photograph of carved temple stonework across the top 35%, with
a circular white back button top left and a small "ARRIVED" pill badge top right.
Below the image: a thin gold progress bar, a small uppercase label "STOP 1 OF 4 · THE OUTER MOAT", then a
large serif pull-quote headline: "Do not drain it," the king said. Then four to five lines of body copy in
a comfortable reading serif.
Under the text, a bordered audio player card with a circular play button, the label "Listen (2:10)", and a
thin scrub bar. A full-width primary "Continue" button pinned at the bottom.
```

## 10 — Task / proof

```
Mobile quest task screen for Kultara. Top bar with back arrow, centered title "Stop 1 · Task", and a "Skip"
text button on the right. A thin gold progress bar beneath.
Serif headline "Find the guardian with the broken tusk" and two lines of instruction text.
A large rounded camera viewfinder area filling the middle of the screen with a circular shutter button
centered in it and faint corner framing marks.
Below it, a row with a wide outlined "Take photo" button and a small square outlined hint button with a
lightbulb icon, plus centered tiny text "Hint costs nothing — this isn't a test."
A full-width "Submit" button at the bottom, shown disabled in grey.
```

## 11 — Quest complete

```
Mobile reward screen for Kultara. Centered at the top, a large circular double-ruled souvenir stamp graphic
in temple gold reading "TAMAN AYUN 2026", with faint confetti or ink-splatter texture behind it. Under it a
serif headline "Quest complete" and the quest name "The Garden That Answered a King" in grey.
A bordered card labelled "YOU COLLECTED" containing a row of three square collectible story cards and the
caption "3 story cards · 1 site stamp · 4/4 stops".
Below, a horizontal suggestion card with a thumbnail photo, the label "NEXT NEARBY" and the title
"Pura Ulun Danu · 3.1 km".
At the bottom: a full-width primary "Add to journal" button, and beneath it a row of two outlined buttons,
"Share" and "Back to map".
```

## 12 — Journal

```
Mobile journal screen for Kultara. Header row with the serif title "Journal" on the left and two toggle
chips on the right, "Timeline" selected and "Stamps".
A summary card: "Bali · 2026" with subtitle "4 sites · 12 story cards · 3 stamps" and a small circular
progress ring on the right.
A "TODAY" section label, then a journal entry card containing two square photo thumbnails side by side, the
title "Pura Taman Ayun", subtitle "45 min · 4/4 stops", a small green "Completed" chip, and two lines of
auto-written summary text.
A "YESTERDAY" section label, then a second, shorter entry card: one photo thumbnail, title "Tirta Empul",
subtitle "2/5 stops", and an amber "In progress" chip.
Bottom tab bar with Journal selected.
```

## 13 — Journal entry detail

```
Mobile journal entry detail screen for Kultara. Full-bleed hero photograph across the top with a circular
white back button. Serif title "Pura Taman Ayun" and grey metadata "6 Aug 2026 · 09:12–09:57 · 1.2 km
walked".
A "YOUR PHOTOS" label with a 3-column grid of square photo thumbnails.
A "STORY CARDS EARNED" label with a bordered card showing the title "The Garden That Answered a King" and
two lines of excerpt text.
A "YOUR NOTE" label with a large empty outlined text area showing the placeholder "Add a memory…".
A sticky bottom bar with an outlined "Export" button and a primary "Share" button side by side.
```

## 14 — Profile

```
Mobile profile screen for Kultara. Top row: circular avatar photo, serif name "Ayu W." with subtitle
"Explorer · Level 3", and a small outlined "Edit" chip on the right.
A row of three equal stat cards showing large serif numbers with small uppercase labels: 4 Sites,
12 Cards, 3 Stamps.
A "BADGES" label with a 4-column grid of circular badge medallions — the first two illustrated and earned,
the last two greyed out with a hatched locked pattern.
A "SETTINGS" label followed by a plain list with hairline dividers and chevrons: Notifications,
Location & privacy, Language · English, Offline maps.
Bottom tab bar with Profile selected.
```

## 15 — Notifications

```
Mobile notifications screen for Kultara, shown over a dimmed map background. At the very top, a floating
push-notification banner card with an app icon, the bold title "You're 200 m from Pura Desa" and the line
"A 20-min quest starts here. Tap to preview."
Below it, a large bottom sheet with a grab handle, serif title "Notifications", and a row of filter chips:
All (selected), Nearby, Quests.
Inside, three notification rows, each with a circular icon on the left, a bold title, and a grey meta line:
"Historical site nearby — Pura Desa · 200 m · now"; "Quest paused — Tirta Empul · 2/5 stops · 1d";
and a dimmed, already-read "New stamp unlocked — Taman Ayun · 2d".
```

---

## Refinement prompts (after generation)

Stitch responds well to short, single-change edits. Useful ones for this app:

```
Make the story text serif and larger, with more line spacing — it should read like a printed book.
```
```
Reduce the accent colour to one element per screen. Everything else charcoal on sandstone.
```
```
Replace all illustrated icons with 1.5px line icons at 24px.
```
```
Add a dark mode variant of this screen using volcanic charcoal background and warm off-white text.
```
```
Show this screen in an empty state: no quests completed yet.
```
