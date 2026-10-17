// ignore_for_file: prefer_const_constructors

import 'dart:math';

import 'package:animal_shadow_match/data/catalog_repository.dart';
import 'package:animal_shadow_match/data/game_progress_store.dart';
import 'package:animal_shadow_match/domain/effect_preset.dart';
import 'package:animal_shadow_match/domain/game_controller.dart';
import 'package:animal_shadow_match/domain/game_progress_phase.dart';
import 'package:animal_shadow_match/domain/game_state.dart';
import 'package:animal_shadow_match/domain/round_factory.dart';
import 'package:animal_shadow_match/domain/shadow_item.dart';
import 'package:animal_shadow_match/ui/game_page.dart';
import 'package:animal_shadow_match/ui/play_area.dart';
import 'package:animal_shadow_match/ui/resting_screen.dart';
import 'package:animal_shadow_match/ui/single_asset_effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_assets.dart';

/// Five unique catalog items with distinct categories; mirrors the
/// standard test catalog across this PR.
List<ShadowItem> _catalog() => [
      ShadowItem(
        id: 'gel_star',
        imagePath: 'assets/test/gel_star.webp',
        shadowPath: 'assets/test/gel_star_shadow.webp',
        category: 'jelly',
        distractorIds: const [],
        effectPreset: EffectPreset.squish,
      ),
      ShadowItem(
        id: 'cloud_cushion',
        imagePath: 'assets/test/cloud_cushion.webp',
        shadowPath: 'assets/test/cloud_cushion_shadow.webp',
        category: 'jelly',
        distractorIds: const [],
        effectPreset: EffectPreset.wobble,
      ),
      ShadowItem(
        id: 'teardrop_gummy',
        imagePath: 'assets/test/teardrop_gummy.webp',
        shadowPath: 'assets/test/teardrop_gummy_shadow.webp',
        category: 'jelly',
        distractorIds: const [],
        effectPreset: EffectPreset.bounce,
      ),
      ShadowItem(
        id: 'twist_gummy',
        imagePath: 'assets/test/twist_gummy.webp',
        shadowPath: 'assets/test/twist_gummy_shadow.webp',
        category: 'toys',
        distractorIds: const [],
        effectPreset: EffectPreset.inflate,
      ),
      ShadowItem(
        id: 'soft_planet',
        imagePath: 'assets/test/soft_planet.webp',
        shadowPath: 'assets/test/soft_planet_shadow.webp',
        category: 'cosmic',
        distractorIds: const [],
        effectPreset: EffectPreset.squish,
      ),
    ];

Future<void> _pump(
  WidgetTester tester, {
  required GameProgressStore store,
  bool tearDown = false,
}) async {
  // Real cold restart: replace the current widget tree with an empty
  // placeholder first so Flutter actually disposes the previous
  // _PlayBoardState (and its GameController / timers). Without this,
  // pumpWidget(MaterialApp(home: GamePage(...))) reuses the existing
  // State because the runtime type and position are identical, which
  // would mean the "cold restart" path is never actually exercised
  // (Issue #22 review follow-up).
  if (tearDown) {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }
  final items = _catalog();
  final bundle = bundleForItems(
    items,
    catalogJson: itemsJson(items),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: GamePage(
        repository: CatalogRepository.test(bundle),
        progressStore: store,
        disableHandGuide: true,
        imageBundle: bundle,
      ),
    ),
  );
  // Bounded pumps (not pumpAndSettle): let the catalog FutureBuilder
  // resolve and the post-frame _persistProgress / _maybeResume run,
  // but never let a restored SingleAssetEffect's 850ms FX animation
  // fire its onCompleted callback before the assertion runs (Issue #22).
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Lift the private _OptionTile via a public API. The tile factory uses
/// `ValueKey<String>('option-${item.id}')` so we can match by key.
String _optionKey(String id) => 'option-$id';

List<String> _optionIds(WidgetTester tester) {
  return tester
      .widgetList<KeyedSubtree>(find.byType(KeyedSubtree))
      .where((k) =>
          (k.key is ValueKey<String>) &&
          (k.key as ValueKey<String>).value.startsWith('option-'))
      .map((k) =>
          (k.key as ValueKey<String>).value.substring('option-'.length))
      .toList();
}

String _pickWrongId(WidgetTester tester, String targetId) {
  final options = _optionIds(tester);
  for (final id in options) {
    if (id != targetId) return id;
  }
  throw StateError('round has no option distinct from $targetId');
}

String _headlineSemanticLabel(WidgetTester tester) {
  // The headline Image is keyed in SolvingState; in SolvedState the same
  // image is rendered inside SingleAssetEffect. Search both sites.
  final candidates = [
    find.descendant(
      of: find.byKey(const ValueKey('headline-image')),
      matching: find.byType(Image),
    ),
    find.descendant(
      of: find.byType(SingleAssetEffect),
      matching: find.byType(Image),
    ),
  ];
  for (final finder in candidates) {
    final matches = tester.widgetList<Image>(finder).toList();
    if (matches.isNotEmpty) {
      final label = matches.first.semanticLabel;
      if (label != null) return label;
    }
  }
  // SolvedState: the SingleAssetEffect's key encodes the target id and
  // completed-in-set count as `solved-<targetId>-<n>`. Pull the target id
  // out by stripping the `solved-` prefix and the trailing `-<n>`.
  final fx = tester.widgetList<SingleAssetEffect>(find.byType(SingleAssetEffect));
  if (fx.isNotEmpty) {
    final key = fx.first.key;
    if (key is ValueKey<String> && key.value.startsWith('solved-')) {
      final stripped = key.value.substring('solved-'.length);
      final lastDash = stripped.lastIndexOf('-');
      if (lastDash >= 0) {
        return 'Find the matching silhouette for ${stripped.substring(0, lastDash)}';
      }
    }
  }
  throw StateError('no Image widget found for the headline or Solved FX');
}

void main() {
  // -------- Issue #22 strict resume integration --------

  testWidgets('GamePage shows the same round + same option order after '
      'cold restart (Solving)', (tester) async {
    final store = InMemoryGameProgressStore();
    await _pump(tester, store: store);
    // Capture the live first-round ids + target id.
    final firstSemantics = _headlineSemanticLabel(tester);
    final firstTargetId = firstSemantics.split(' ').last;
    final firstOptions = tester
        .widgetList<KeyedSubtree>(find.byType(KeyedSubtree))
        .where((k) =>
            (k.key is ValueKey<String>) &&
            (k.key as ValueKey<String>).value.startsWith('option-'))
        .map((k) => (k.key as ValueKey<String>).value
            .substring('option-'.length))
        .toList();
    expect(firstOptions, hasLength(2));

    // Recreate GamePage from scratch with the same store, simulating a
    // cold launch with the persisted snapshot on disk.
    await _pump(tester, store: store, tearDown: true);
    final secondSemantics = _headlineSemanticLabel(tester);
    final secondTargetId = secondSemantics.split(' ').last;
    expect(secondTargetId, firstTargetId,
        reason: 'target id must survive a cold restart');
    final secondOptions = tester
        .widgetList<KeyedSubtree>(find.byType(KeyedSubtree))
        .where((k) =>
            (k.key is ValueKey<String>) &&
            (k.key as ValueKey<String>).value.startsWith('option-'))
        .map((k) => (k.key as ValueKey<String>).value
            .substring('option-'.length))
        .toList();
    expect(secondOptions, equals(firstOptions),
        reason: 'option tile order must survive a cold restart');
    expect(find.byType(GamePage), findsOneWidget);
  });

  testWidgets('GamePage restores the in-flight FX after cold restart '
      '(Solved)', (tester) async {
    final store = InMemoryGameProgressStore();
    await _pump(tester, store: store);
    // Solve the first round.
    final solving = tester.widget<GamePage>(find.byType(GamePage));
    expect(solving, isNotNull);
    final firstHeadline = _headlineSemanticLabel(tester);
    final firstTargetId = firstHeadline.split(' ').last;
    await tester.tap(find.byKey(ValueKey<String>(_optionKey(firstTargetId))));
    await tester.pump();
    // The post-correct snapshot is Solved (FX playing). Recreate.
    await _pump(tester, store: store, tearDown: true);
    expect(find.byType(GamePage), findsOneWidget);
    // We can't observe GameController.state directly from the widget
    // tree, but the FX widget (SingleAssetEffect) being on screen with
    // the same headline image proves we re-hydrated the SolvedState.
    expect(find.byType(SingleAssetEffect), findsOneWidget);
    final reHeadline = _headlineSemanticLabel(tester);
    expect(reHeadline.split(' ').last, firstTargetId);
  });

  testWidgets('GamePage resumes on the review screen after the set completes',
      (tester) async {
    final store = InMemoryGameProgressStore();
    await _pump(tester, store: store);
    // Burn through 5 correct answers.
    for (var i = 0; i < 5; i++) {
      final sem = _headlineSemanticLabel(tester);
      final tid = sem.split(' ').last;
      await tester.tap(find.byKey(ValueKey<String>(_optionKey(tid))));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
    expect(find.byType(ReviewPlayArea), findsOneWidget,
        reason: '5 correct answers should land on the review screen');
    // Cold restart.
    await _pump(tester, store: store, tearDown: true);
    expect(find.byType(ReviewPlayArea), findsOneWidget,
        reason: 'after cold restart the review screen must be visible');
  });

  testWidgets('GamePage resumes on the resting screen after the child taps '
      'Rest', (tester) async {
    final store = InMemoryGameProgressStore();
    await _pump(tester, store: store);
    for (var i = 0; i < 5; i++) {
      final sem = _headlineSemanticLabel(tester);
      final tid = sem.split(' ').last;
      await tester.tap(find.byKey(ValueKey<String>(_optionKey(tid))));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
    await tester.tap(find.byTooltip('Rest'));
    await tester.pump();
    expect(find.byType(RestingScreen), findsOneWidget);
    // Cold restart.
    await _pump(tester, store: store, tearDown: true);
    expect(find.byType(RestingScreen), findsOneWidget,
        reason: 'RestingScreen must survive a cold restart');
  });

  testWidgets('GamePage resumes mid-set on the third question', (tester) async {
    final store = InMemoryGameProgressStore();
    await _pump(tester, store: store);
    // Solve 2 questions then drop into a cold restart.
    for (var i = 0; i < 2; i++) {
      final sem = _headlineSemanticLabel(tester);
      final tid = sem.split(' ').last;
      await tester.tap(find.byKey(ValueKey<String>(_optionKey(tid))));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
    // Snapshot now: solving, roundIndex 2, totalCompleted 2.
    final preSaveSem = _headlineSemanticLabel(tester);
    final preSaveTargetId = preSaveSem.split(' ').last;

    await _pump(tester, store: store, tearDown: true);
    final postSem = _headlineSemanticLabel(tester);
    final postTargetId = postSem.split(' ').last;
    expect(postTargetId, preSaveTargetId,
        reason: 'mid-set restart must keep the player on the same round');
    // The set indicator should show 2 dots lit (out of 5): see
    // _SetIndicator in GamePage. The image carries the target id.
    expect(find.byKey(const ValueKey('headline-image')), findsOneWidget);
  });

  testWidgets('GamePage falls back to a fresh start when the persisted '
      'snapshot is unreadable (old format)', (tester) async {
    // Synthesize an "old-format" snapshot: phase + roundIndex are
    // persisted but currentRoundOptionIds is empty. restoreFrom
    // throws StateError because optionIds is empty; the GamePage
    // catches that, clears the store, and starts fresh.
    final store = InMemoryGameProgressStore();
    // Stomp in a snapshot whose option list is empty.
    final broken = GameProgress(
      totalCompleted: 3,
      lastRecentItemIds: const ['a'],
      lastPlayedAt: DateTime.now(),
      currentSetIndex: 0,
      phase: SessionPhase.solving,
      roundIndex: 0,
      currentRoundOptionIds: const <String>[],
    );
    await store.save(broken);

    await _pump(tester, store: store);
    // The catch path ran: no exception, the GamePage is happily showing
    // its first question, and the broken snapshot is replaced by a
    // fresh one (not the original — totalCompleted must drop from 3
    // back to 0, and the bogus recent item id 'a' must be gone).
    expect(find.byType(GamePage), findsOneWidget);
    expect(find.byKey(const ValueKey('headline-image')), findsOneWidget);
    final restored = await store.load();
    expect(restored, isNotNull,
        reason: 'the postFrame _persistProgress writes the fresh state');
    expect(restored!.totalCompleted, 0,
        reason: 'broken totalCompleted=3 must not survive the fallback');
    expect(restored.lastRecentItemIds, isNot(contains('a')),
        reason: 'bogus recent item id from the broken snapshot must be gone');
  });

  test('Restoring twice does not duplicate a previously played target '
      'inside the same set', () {
    // Pure-domain guard (no widget pumping). The strict-resume snapshot
    // already records the target in lastRecentItemIds; restoreFrom
    // must not append it again or the next _freshRound in the same
    // set will ban a target the controller already "remembers".
    final items = _catalog();
    final controller = GameController(
      catalog: items,
      factory: RoundFactory(random: Random(70)),
    );
    controller.start();
    final solving = controller.current! as SolvingState;
    controller.onChoice(solving.round.target.id); // Solved
    final snapshot = controller.snapshot();
    expect(snapshot.phase, SessionPhase.solved);
    expect(
      snapshot.lastRecentItemIds,
      equals([solving.round.target.id]),
    );

    final fresh = GameController(
      catalog: items,
      factory: RoundFactory(random: Random(71)),
    );
    fresh.restoreFrom(snapshot);
    expect(fresh.completedInSet, 1);
    expect(fresh.recentItems.length, 1,
        reason: 'restoreFrom must not double-add the just-played target');
    // Finishing the FX and starting the next round must not pick
    // the same target again.
    final s = fresh.current! as SolvedState;
    fresh.onEffectFinished();
    expect(fresh.current, isA<SolvingState>());
    final next = fresh.current! as SolvingState;
    expect(next.round.target.id, isNot(s.round.target.id));
  });

  testWidgets('GamePage restores the very first question (totalCompleted==0) '
      'after a cold restart with tear-down', (tester) async {
    // Issue #22 review follow-up: previously the resume path skipped
    // every snapshot with totalCompleted == 0, which silently bypassed
    // a fresh-install child who quits on the very first question.
    final store = InMemoryGameProgressStore();
    await _pump(tester, store: store);
    // Capture the live first round layout.
    final firstHeadline = _headlineSemanticLabel(tester);
    final firstTargetId = firstHeadline.split(' ').last;
    final firstOptions = _optionIds(tester);

    // Real cold restart: tear the widget tree down first.
    await _pump(tester, store: store, tearDown: true);

    final secondHeadline = _headlineSemanticLabel(tester);
    final secondTargetId = secondHeadline.split(' ').last;
    expect(secondTargetId, firstTargetId,
        reason: 'first-round target id must survive a cold restart '
            'even when totalCompleted is still 0');
    expect(_optionIds(tester), equals(firstOptions),
        reason: 'first-round option order must survive a cold restart');
  });

  testWidgets('GamePage restores the wrong-tile highlight across cold '
      'restart and clears it on the timer', (tester) async {
    // Issue #22 review follow-up: the wrongChoiceId is now part of
    // the persisted snapshot. After a cold restart the highlight
    // must come back; once the red-tint timer fires in the live UI
    // it must drop out of the persisted snapshot too so the next
    // cold restart does not paint the highlight again.
    final store = InMemoryGameProgressStore();
    await _pump(tester, store: store);
    final firstHeadline = _headlineSemanticLabel(tester);
    final firstTargetId = firstHeadline.split(' ').last;
    final wrongId = _pickWrongId(tester, firstTargetId);
    await tester.tap(find.byKey(ValueKey<String>(_optionKey(wrongId))));
    // Advance enough time for _wrongChoice to be set but not yet for
    // the 500ms clear timer to fire.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final wrongBefore = await store.load();
    expect(wrongBefore?.wrongChoiceId, equals(wrongId),
        reason: 'wrongChoiceId must reach the snapshot immediately');

    // Cold restart with teardown — highlight must come back.
    await _pump(tester, store: store, tearDown: true);
    final afterRestart = await store.load();
    expect(afterRestart?.wrongChoiceId, equals(wrongId),
        reason: 'wrongChoiceId must survive a cold restart');

    // Wait out the 500ms clear timer in the new GamePage's wrongReset
    // path. The clear must drop the wrongChoiceId from the snapshot
    // so the next cold restart shows a clean board.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final afterClear = await store.load();
    expect(afterClear?.wrongChoiceId, isNull,
        reason: 'wrongChoiceId must clear from the snapshot once the '
            'red-tint timer fires');
  });
}
