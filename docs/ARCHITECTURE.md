# Technical architecture and decisions

## Decision record

| Decision | Why | Alternative deferred |
|---|---|---|
| Flutter + Material widgets | Single codebase, fast Android MVP | Flame (unnecessary for 2D tap UI) |
| Local JSON + bundled WebP | Offline, zero backend, deterministic app | Supabase/Firebase unnecessary |
| Tap instead of drag | Suitable for smaller children; fewer accidental gesture failures | Drag matching after user testing |
| Hand-reviewed distractors | Random pairing may produce indistinguishable silhouettes | Automatic similarity engine after catalog grows |
| Image-01 pre-generation only | No runtime image latency, API spending, or children's data transfer | Dynamic generation explicitly excluded |
| No analytics/ads | Privacy baseline and smallest dependency footprint | Policy-reviewed later, not in MVP |

## Data flow

1. `CatalogRepository.load()` loads JSON from Flutter bundle.
2. `Animal.fromJson()` maps raw entries to immutable animal data.
3. `RoundFactory.create()` selects a target, hand-curated distractors, and shuffles options.
4. `GamePage` renders the target as full color, options as matching shadow assets.
5. The UI checks `round.isCorrect()` without contacting a backend.
6. In-memory count determines 2, 3, 4 options; local persistent progress is an optional future feature.

## Stable catalog schema

```json
{
  "version": 1,
  "animals": [
    {
      "id": "giraffe",
      "name": "Giraffe",
      "image": "assets/animals/giraffe.webp",
      "shadow": "assets/animals/giraffe_shadow.webp",
      "category": "savanna",
      "distractors": ["elephant", "rabbit", "duck"]
    }
  ]
}
```

`name` is accessibility metadata, **not displayed** as text in the child-facing UI. `distractors` are chosen so the question has clear visual distinctions. Every referenced id and file must exist.

## Development policies

- No `dynamic` content fetch and no asset generation inside child-facing code.
- Avoid introducing third-party packages unless they produce a clearly defined improvement.
- Use strong typing and pure functions for content/round logic.
- Build separate app variants only after Android quality targets are met.
- Profile image decode and memory when the catalog exceeds 100 assets. Flutter loads images on demand; do not preload all high-resolution images into RAM.

## Observed gaps in initial scaffold

Native Android/iOS folders require `flutter create`. Add integration/widget tests, sound toggles, settings access gate, local persistent unlocks, and screenshots in later issues. No network instrumentation or child identifiers should be added without a separate privacy assessment.
