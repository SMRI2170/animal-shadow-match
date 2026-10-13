# Animal Shadow Match 🐾

An offline, text-free animal silhouette matching game for children ages 2–5. Built with Flutter. All animal art is prepared **before release**; the app has no runtime generative-AI API calls.

> **STATUS:** Design + initial playable Flutter prototype. All 8 bundled animal images are obvious **DEVELOPMENT PLACEHOLDERS**, not MiniMax-produced launch artwork. Target OS: Android first. No store release or policy approval has occurred.

## Product at a glance

- **One action:** look at a colorful animal, then **tap** its matching silhouette.
- **UX v3 target (design, not implemented):** direct play, 5 questions per set (about 1–2 minutes as a hypothesis), 5-animal completion screen, clear continue/rest choices, and resume from interruption. MVP has zero ads/SDK; monetization is for separate parental review. See [Session v3](docs/SESSION_AND_MONETIZATION_JA.md). See [UI/UX v2](docs/UI_UX_SPEC_JA.md).
- **Progressive difficulty:** 2 choices (first 5 correct), 3 choices (next 10), then 4 choices.
- **No reading required:** no in-game instructional text or language selection.
- **Gentle feedback:** success animation; wrong answers have no penalty, timer, or loud buzzer.
- **Offline by default:** no ads, analytics, account, networking, or in-app purchases in MVP.
- **Deterministic content:** each shadow is created from the exact same transparent animal image, never independently generated.

> **Game design v4 (planned, not yet implemented):** correct silhouette → animal-specific gentle motion → after five matches, an interactive five-animal parade; the child may continue or rest. No random rewards, loot boxes, score pressure, ads or forced watch-time.

## Project setup

Requires a current stable Flutter SDK with Dart >=3.6. The checked-in repository contains shared Flutter source and demo assets; platform-specific folders are generated locally to avoid checking in untested native configurations.

```bash
# In the unpacked repository root:
flutter create --project-name animal_shadow_match --platforms=android .
flutter pub get
flutter analyze
flutter test
flutter run
```

On a Mac, add iOS scaffolding later with `flutter create --platforms=ios .`. Do **not** run `flutter create --overwrite` or overwrite the checked-in lib/ files.

- [**Game value and intrinsic play v4.0 (日本語)**](docs/GAME_VALUE_AND_ENGAGEMENT_JA.md) — animal-specific reactions, interactive five-animal parade, content freshness, age-appropriate playtesting

## MiniMax art workflow

1. Generate a **single full-body animal** per image (soft 3D clay toy style, no labels, no other objects).
2. Remove its background and review the edges manually. Place transparent 512px+ PNGs at `assets/source/<id>.png`.
3. Process them: `python -m pip install -r scripts/requirements.txt && python scripts/prepare_assets.py`.
4. Update `assets/catalog/animals.json` with the ID, paths, category, and carefully reviewed distractor IDs.
5. Check masks: `python scripts/validate_catalog.py`.
6. Playtest each question with children before release. Reject ambiguous shadow pairs.

`assets/source` is ignored by Git to avoid checking in heavy raw outputs; review and back up originals separately. The small, optimized WebP files under `assets/animals` are tracked.

## Project layout

```text
lib/
  main.dart                    # Flutter app entry point
  domain/animal.dart           # Immutable catalog entity
  domain/round_factory.dart    # Tested offline round selection logic
  data/catalog_repository.dart # JSON asset loading
  ui/game_page.dart            # Text-free responsive play board
assets/
  catalog/animals.json        # Reviewed game assets and distractors
  animals/*.webp              # Color originals + matching silhouettes
scripts/
  prepare_assets.py           # Transparent image -> WebP + silhouette
  validate_catalog.py         # Manifest and mask checks
  generate_demo_assets.py     # Development placeholders only
test/round_factory_test.dart
.github/workflows/ci.yml
.github/ISSUE_TEMPLATE/task.yml
docs/                          # Product, art, QA, app store, backlog
```

## Documentation

- [設計書（日本語）](docs/DESIGN_JA.md)
- [**Child-first UI/UX detailed spec v2.0 (日本語)**](docs/UI_UX_SPEC_JA.md) — per-round screen, hints, animations, accessibility
- [**5-question session & monetization v3.0 (日本語)**](docs/SESSION_AND_MONETIZATION_JA.md) — launch journey, five-round set, completion/rest, offline resume and ad-free MVP
- [Product requirements](docs/PRODUCT_SPEC.md)
- [Architecture and decisions](docs/ARCHITECTURE.md)
- [MiniMax asset pipeline](docs/ASSET_PIPELINE.md)
- [Quality, tests and child safety](docs/QUALITY_AND_LAUNCH.md)
- [App Store Optimization](docs/ASO.md)
- [Sequenced implementation issues](docs/BACKLOG.md)
- [GitHub setup (Windows and Mac)](docs/GITHUB_SETUP.md)

## Privacy / safety baseline

Child-directed release requires accurate target-age, data safety, privacy-policy, and (if introduced later) advertising disclosures under Google Play's Families policy. The MVP deliberately adds no tracking and no advertising SDK. See [Quality and launch](docs/QUALITY_AND_LAUNCH.md) for a verification checklist; this repository is not a legal compliance certification.

## Current limitations

- Bundled art is prototype-only; real MiniMax generation is not performed by this repository.
- No music/sound, persistent unlocks, localization of store listing, or actual store publication yet.
- UI and Dart tests are **not yet executed against Flutter** in this preparation environment (Flutter SDK unavailable). Image/catalog validator has been executed successfully.
- Native `android/` and `ios/` project files are intentionally not included yet.
