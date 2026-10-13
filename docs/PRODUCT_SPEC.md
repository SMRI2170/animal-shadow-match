# Product specification v1.0 — Animal Shadow Match

## 0. Product decision

One visual task per screen: identify a full-color animal and tap its matching dark silhouette. The app must remain playable by a child who cannot read. No text-based onboarding or online inference.

**Primary audience:** ages 2–5, with parents as store-searchers and installation decision-makers. Device: Android phones/tablets, portrait. Priority: search discovery from specific queries such as “animal shadow matching for kids”. This keyword ranking is a **hypothesis**, not validated search-volume data.

## 1. Single-screen UX

```text
┌─────────────────────────┐
│        ☆ ☆ ☆ ☆ ☆        │  five-step *visual* progress indicator
│                         │
│        FULL-COLOR       │  transparent animal with ample margin
│          ANIMAL         │
│                         │
│    ┌────┐  ┌────┐       │
│    │shadow│ │shadow│     │  level 1: 2 large choices
│    └────┘  └────┘       │
│                         │
└─────────────────────────┘
```

- Child taps one silhouette; avoid drag, complex gesture, and typing.
- Correct: green-tinted selected tile, target bounce/sparkle ~850ms, new round.
- Incorrect: short peach tint ~500ms, unchanged task, no score penalty or negative voice.
- No forced timer, lives, login, blocking reward video, or text tutorial.
- Parents can use the Android system back behavior to leave; avoid a confusing exit UI.

## 2. Difficulty

| Correct rounds completed | Choices | Source set | Goal |
|---|---:|---|---|
| 0–4 | 2 | distinct animal shapes | Learn tapping and silhouette matching |
| 5–14 | 3 | varied silhouettes | Practice differentiation |
| 15+ | 4 | curated distractors | Sustain engagement |

This is the initial implementation heuristic, not a validated developmental milestone. Change only after child playtests. The target animal should never immediately repeat; distractors are manually curated and verified to differ meaningfully.

## 3. Visual design

- **Theme:** warm pastel clay-toy 3D style, softly lit, recognizably rounded shapes, simple single-animal compositions.
- Colors: off-white `#FFF9F0`, mint `#83BBAF`, warm gold `#E3B95B`, muted dark `#253134` for silhouettes.
- Source images: square RGBA, one whole animal, no ground shadow and no intersecting props. The true silhouette is always generated from the extracted alpha mask.
- Give each choice ≥96dp visual container on common phones; actual touch surface should remain comfortable even at the smallest tested size.
- Avoid color-only instructions: color differentiates feedback, but target-to-silhouette shape is the primary information.

## 4. MVP acceptance

1. App can be played from startup to 20 consecutive correct rounds without encountering textual instructions.
2. All rounds contain exactly one answer matching the target and no duplicate choices.
3. 2 → 3 → 4 choice transitions occur at the specified thresholds.
4. A wrong answer never loses progress or ends play; a rapid double-tap never advances twice.
5. Every image and shadow mask correspond pixel-for-pixel in alpha; no clipped ears, tails, legs, trunks, or antennae.
6. App launches offline after installation, requires no account, and makes no runtime MiniMax calls.
7. On a small Android phone, all choices are accessible without sideways scrolling.
8. No child tracking, ad network, or external links in MVP.

## 5. Content strategy

Launch goal: **100–200 unique, hand-reviewed animal images** divided into farm, forest, savanna, sea, birds, insects, and similar groups. This is an aspiration; quality takes precedence over raw count. The app combines one image with 2–4 silhouettes selected from the catalog, so art scales without authoring screenshots or bespoke level images.

Reject images with ambiguous/identical silhouette, multiple subjects, transparent holes incorrectly extracted, missing appendages, uncanny detail, inappropriate imagery, or subtle colored cast shadow merged into silhouette.

## 6. Explicitly out of scope

- Generating AI images on a child's phone or transmitting children's data to AI providers.
- Scoreboards, time pressure, online multiplayer, social sharing, leaderboards.
- Advertising, subscription, paywalls, loot boxes in initial release.
- Speech, camera access, location, user accounts, third-party analytics in MVP.

## 7. Release evidence to collect

- Local device playtesting at 360dp wide, 393dp wide, and tablet portrait; assess reachability and size.
- Observe at least a small, guardian-consented sample of target-age children: do they infer the task within 10 seconds? Number of adult hints? Time spent interacting? No covert analytics.
- Manual review checklist signed for all shipping assets.
- After store launch: Play Console native acquisition metrics and organic search terms; avoid adding SDK tracking only for growth measurement.
