// ignore_for_file: prefer_const_constructors

import 'dart:math';

import 'package:animal_shadow_match/data/game_progress_store.dart';
import 'package:animal_shadow_match/domain/game_controller.dart';
import 'package:animal_shadow_match/domain/game_state.dart';
import 'package:animal_shadow_match/domain/round_factory.dart';
import 'package:animal_shadow_match/domain/shadow_item.dart';
import 'package:flutter_test/flutter_test.dart';

ShadowItem _item(String id, {String category = 'squishy_object'}) {
  return ShadowItem(
    id: id,
    imagePath: 'assets/items/$id.webp',
    shadowPath: 'assets/items/${id}_shadow.webp',
    category: category,
    distractorIds: const [],
  );
}

/// Mirrors the sequence of events the GamePage widget issues to the
/// controller (onChoice, onEffectFinished, onContinue).  Used as a regression
/// harness for the 5-question -> review-area -> next-set flow.
Future<void> _playCorrectlyThrough(GameController controller) async {
  controller.start();
  for (var i = 0; i < 5; i++) {
    final solving = controller.current! as SolvingState;
    final next = controller.onChoice(solving.round.target.id);
    // Every correct answer lands on SolvedState (so the FX plays); the
    // final answer's onEffectFinished returns SetCompletedState.
    expect(next, isA<SolvedState>(),
        reason: 'round $i should reach SolvedState');
    final after = controller.onEffectFinished();
    if (after is SetCompletedState) return;
  }
  // Defensive: if for any reason the loop above exited without returning,
  // we must have ended on SetCompletedState.
  expect(controller.current, isA<SetCompletedState>());
}

void main() {
  final catalog = <ShadowItem>[
    _item('gel_star', category: 'jelly'),
    _item('cloud_cushion', category: 'jelly'),
    _item('twisted_loop', category: 'toys'),
    _item('puzzle_bean', category: 'toys'),
    _item('soft_planet', category: 'cosmic'),
    _item('moon_stone', category: 'cosmic'),
  ];

  test('a full set of five correct answers reaches SetCompletedState', () {
    final controller = GameController(
      catalog: catalog,
      factory: RoundFactory(random: Random(1)),
    );
    _playCorrectlyThrough(controller);
    final completed = controller.current!;
    expect(completed, isA<SetCompletedState>());
    final setCompleted = completed as SetCompletedState;
    expect(setCompleted.recentItems, hasLength(5));
    expect(setCompleted.totalCompletedToday, 5);
  });

  test('a wrong answer is recoverable: progress only counts correct ones',
      () {
    final controller = GameController(
      catalog: catalog,
      factory: RoundFactory(random: Random(2)),
    );
    controller.start();
    final first = controller.current! as SolvingState;
    final wrong = first.round.options
        .firstWhere((o) => o.id != first.round.target.id);
    final afterWrong = controller.onChoice(wrong.id) as SolvingState;
    expect(afterWrong.wrongChoiceId, wrong.id);
    expect(controller.completedInSet, 0);

    final next = controller.onChoice(first.round.target.id);
    expect(next, isA<SolvedState>());
    expect(controller.completedInSet, 1);
  });

  test('after SetCompleted, onContinue restarts with completedInSet = 0', () {
    final controller = GameController(
      catalog: catalog,
      factory: RoundFactory(random: Random(3)),
    );
    _playCorrectlyThrough(controller);
    expect(controller.current, isA<SetCompletedState>());

    final next = controller.onContinue();
    expect(next, isA<SolvingState>());
    final solving = next as SolvingState;
    expect(solving.completedInSet, 0);
    // 5 questions already answered; the next set uses 3 options per the
    // _totalCompleted-based escalation in GameController.
    expect(solving.optionCount, 3,
        reason: 'after 5 completions, the next set uses 3 options');
  });

  test('GameProgressStore receives the expected snapshot at each checkpoint',
      () async {
    final store = InMemoryGameProgressStore();
    Future<void> persist(GameController controller) async {
      await store.save(
        GameProgress(
          totalCompleted: controller.totalCompleted,
          lastRecentItemIds: controller.recentItems
              .map((e) => e.id)
              .toList(growable: false),
          lastPlayedAt: DateTime.now(),
          currentSetIndex: controller.totalCompleted,
        ),
      );
    }

    final controller = GameController(
      catalog: catalog,
      factory: RoundFactory(random: Random(4)),
    );
    controller.start();
    for (var i = 0; i < 4; i++) {
      final solving = controller.current! as SolvingState;
      controller.onChoice(solving.round.target.id);
      controller.onEffectFinished();
      await persist(controller);
    }
    // The fifth tap closes the set: answer -> SolvedState -> onEffectFinished
    // -> SetCompletedState.
    final solving = controller.current! as SolvingState;
    controller.onChoice(solving.round.target.id);
    controller.onEffectFinished();
    await persist(controller);
    expect(controller.current, isA<SetCompletedState>());

    final saved = await store.load();
    expect(saved, isNotNull);
    expect(saved!.totalCompleted, 5);
    expect(saved.lastRecentItemIds, hasLength(5));
    expect(saved.currentSetIndex, 5);
  });
}
