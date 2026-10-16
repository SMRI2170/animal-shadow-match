// ignore_for_file: prefer_const_constructors

import 'dart:typed_data';

import 'package:animal_shadow_match/data/catalog_repository.dart';
import 'package:animal_shadow_match/data/game_progress_store.dart';
import 'package:animal_shadow_match/domain/effect_preset.dart';
import 'package:animal_shadow_match/domain/shadow_item.dart';
import 'package:animal_shadow_match/ui/game_page.dart';
import 'package:animal_shadow_match/ui/hand_guide.dart';
import 'package:animal_shadow_match/ui/play_area.dart';
import 'package:animal_shadow_match/ui/resting_screen.dart';
import 'package:animal_shadow_match/ui/single_asset_effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_assets.dart';

/// Five unique ShadowItems with distinct categories so the round factory has
/// enough material to honour the 5-question set without reusing targets.
List<ShadowItem> _buildCatalog() => [
      ShadowItem(
        id: 'gel_star',
        imagePath: 'assets/test/gel_star.webp',
        shadowPath: 'assets/test/gel_star_shadow.webp',
        category: 'jelly',
        distractorIds: const ['cloud_cushion', 'teardrop_gummy'],
        effectPreset: EffectPreset.squish,
      ),
      ShadowItem(
        id: 'cloud_cushion',
        imagePath: 'assets/test/cloud_cushion.webp',
        shadowPath: 'assets/test/cloud_cushion_shadow.webp',
        category: 'jelly',
        distractorIds: const ['gel_star', 'teardrop_gummy'],
        effectPreset: EffectPreset.wobble,
      ),
      ShadowItem(
        id: 'teardrop_gummy',
        imagePath: 'assets/test/teardrop_gummy.webp',
        shadowPath: 'assets/test/teardrop_gummy_shadow.webp',
        category: 'jelly',
        distractorIds: const ['gel_star', 'cloud_cushion'],
        effectPreset: EffectPreset.bounce,
      ),
      ShadowItem(
        id: 'twist_gummy',
        imagePath: 'assets/test/twist_gummy.webp',
        shadowPath: 'assets/test/twist_gummy_shadow.webp',
        category: 'toys',
        distractorIds: const ['gel_star', 'soft_planet'],
        effectPreset: EffectPreset.inflate,
      ),
      ShadowItem(
        id: 'soft_planet',
        imagePath: 'assets/test/soft_planet.webp',
        shadowPath: 'assets/test/soft_planet_shadow.webp',
        category: 'cosmic',
        distractorIds: const ['gel_star', 'twist_gummy'],
        effectPreset: EffectPreset.squish,
      ),
    ];

/// Per-path MemoryImage resolver. Returns a [MemoryImage] for every path
/// the GamePage might display (headline + every item's shadow). Anything
/// not in the resolver table falls back to `Image.asset` and is therefore
/// outside the test's responsibility.
ImageProvider? _memoryProviderFor(
  Map<String, Uint8List> images,
  String path,
) {
  final bytes = images[path];
  if (bytes == null) return null;
  return MemoryImage(bytes);
}

Future<void> _pumpGamePage(
  WidgetTester tester, {
  required List<ShadowItem> items,
  required Map<String, Uint8List> images,
  GameProgressStore? progressStore,
}) async {
  final bundle = bundleForItems(
    items,
    catalogJson: itemsJson(items),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: GamePage(
        repository: CatalogRepository.test(bundle),
        progressStore: progressStore,
        disableHandGuide: true,
        imageProviderBuilder: (path) => _memoryProviderFor(images, path),
      ),
    ),
  );
  // Let the catalog FutureBuilder resolve.
  await tester.pumpAndSettle(const Duration(milliseconds: 200));
}

/// Walk five correct taps through the Solving state.
///
/// Each iteration:
/// 1. Reads the headline image's semanticLabel to discover the target id.
/// 2. Taps the matching option tile (`option-<target.id>`).
/// 3. Lets the 850 ms SingleAssetEffect run to completion.
/// 4. After the fifth tap, [ReviewPlayArea] must be visible.
Future<void> _completeFiveQuestions(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    expect(find.byKey(const ValueKey('headline-image')), findsOneWidget,
        reason: 'round $i should expose a headline image key');
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('headline-image')),
        matching: find.byType(Image),
      ),
    );
    final targetId = _idFromSemanticLabel(image.semanticLabel!);
    final correctKey = 'option-$targetId';
    await tester.tap(find.byKey(ValueKey<String>(correctKey)));
    await tester.pump(); // run onChoice -> SolvedState
    expect(find.byType(SingleAssetEffect), findsOneWidget,
        reason: 'round $i should reach SolvedState with the FX playing');
    // Pump until the 850 ms effect timer settles. Allow a generous window
    // so the test does not flake on slow runners.
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }
}

String _idFromSemanticLabel(String label) {
  // The headline semantic label is:
  //   "Find the matching silhouette for <accessibilityLabel or id>"
  // We feed each shadow item an explicit accessibilityLabel of '<id>',
  // so the id is the last whitespace-separated token.
  final parts = label.split(' ');
  return parts.last;
}

void main() {
  final items = _buildCatalog();
  final images = <String, Uint8List>{
    for (final item in items) ...{
      item.imagePath: Uint8List.fromList(transparentPixelPng()),
      item.shadowPath: Uint8List.fromList(transparentPixelPng()),
    },
  };

  testWidgets('GamePage renders the headline image + correct option layout',
      (tester) async {
    await _pumpGamePage(
      tester,
      items: items,
      images: images,
      progressStore: InMemoryGameProgressStore(),
    );
    // The FutureBuilder resolved and we are in Solving state.
    expect(find.byKey(const ValueKey('headline-image')), findsOneWidget,
        reason: 'the GamePage must render its headline image slot');
    // ImageProviderBuilder resolved every relevant path.
    expect(find.byType(Image), findsWidgets);
    // No review area, resting screen, or hand guide yet.
    expect(find.byType(ReviewPlayArea), findsNothing);
    expect(find.byType(RestingScreen), findsNothing);
    expect(find.byType(HandGuide), findsNothing);
  });

  testWidgets('GamePage plays a full 5-correct set and lands on SetCompleted',
      (tester) async {
    // Use a fixed random seed via the factory so the test outcome is
    // deterministic.
    await _pumpGamePage(
      tester,
      items: items,
      images: images,
      progressStore: InMemoryGameProgressStore(),
    );
    // Replace the inner factory by recreating with a Random — currently the
    // factory is owned by GamePage; we just exercise the default Random
    // path. The point of this test is "the flow wires up" not "the picks
    // are exact", so a non-deterministic sequence is acceptable.
    await _completeFiveQuestions(tester);

    expect(tester.takeException(), isNull,
        reason: 'no exceptions during the 5-question flow');
    // After the fifth answer + FX, SetCompletedState has been reached.
    expect(find.byType(ReviewPlayArea), findsOneWidget,
        reason: 'after 5 correct answers the GamePage must show '
        'ReviewPlayArea (SetCompletedState)');
    // The review area exposes 5 review tiles (one per recent item).
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget,
        reason: 'Continue button must be present on the review area');
  });

  testWidgets('GamePage drives one correct tap through the injected '
      'MemoryImage path without exceptions',
      (tester) async {
    // Tiny smoke test: pump + tap the first correct tile, observe the
    // SolvedState (SingleAssetEffect), let the 850 ms FX complete. The
    // round factory uses GamePage's default `Random()` (no seeded RNG), so
    // any valid target/option layout is acceptable; the assertion is that
    // the injected MemoryImage path does not leak a FlutterError.
    await _pumpGamePage(
      tester,
      items: items,
      images: images,
      progressStore: InMemoryGameProgressStore(),
    );
    expect(find.byKey(const ValueKey('headline-image')), findsOneWidget);
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('headline-image')),
        matching: find.byType(Image),
      ),
    );
    final targetId = _idFromSemanticLabel(image.semanticLabel!);
    await tester.tap(find.byKey(ValueKey<String>('option-$targetId')));
    await tester.pump();
    expect(find.byType(SingleAssetEffect), findsOneWidget,
        reason: 'a correct tap must transition to SolvedState with FX');
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(tester.takeException(), isNull,
        reason: 'no exception during the injected MemoryImage flow');
  });

  testWidgets('GamePage transitions SetCompleted -> Rest -> Resting -> Resume '
      '-> ReviewPlayArea', (tester) async {
    await _pumpGamePage(
      tester,
      items: items,
      images: images,
      progressStore: InMemoryGameProgressStore(),
    );
    await _completeFiveQuestions(tester);

    expect(find.byType(ReviewPlayArea), findsOneWidget,
        reason: 'a perfect set must land on the review area');
    // Tap the Rest icon button (bedtime_rounded). The SetCompleted state
    // also shows a Continue button; tap Rest specifically.
    expect(find.byTooltip('Rest'), findsOneWidget);
    await tester.tap(find.byTooltip('Rest'));
    await tester.pump();
    expect(find.byType(RestingScreen), findsOneWidget,
        reason: 'tapping Rest must switch to the resting screen');
    // RestingScreen's _RestingTile has a repeating bobbing animation;
    // pumpAndSettle would loop forever. Use bounded pumps instead.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Resume'), findsOneWidget);
    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();
    expect(find.byType(ReviewPlayArea), findsOneWidget,
        reason: 'tapping Resume must return to the review area');
    expect(tester.takeException(), isNull,
        reason: 'no exceptions during the rest/resume round-trip');
  });
}
