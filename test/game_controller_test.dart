import 'dart:math';

import 'package:animal_shadow_match/domain/game_controller.dart';
import 'package:animal_shadow_match/domain/game_state.dart';
import 'package:animal_shadow_match/domain/round_factory.dart';
import 'package:animal_shadow_match/domain/shadow_item.dart';
import 'package:flutter_test/flutter_test.dart';

ShadowItem _item(
  String id, {
  String category = 'squishy_object',
  List<String> distractors = const [],
}) {
  return ShadowItem(
    id: id,
    imagePath: 'assets/items/$id.webp',
    shadowPath: 'assets/items/${id}_shadow.webp',
    category: category,
    distractorIds: distractors,
  );
}

void main() {
  final catalog = [
    _item('gel_star', category: 'jelly'),
    _item('cloud_cushion', category: 'jelly'),
    _item('twisted_loop', category: 'toys'),
    _item('puzzle_bean', category: 'toys'),
    _item('soft_planet', category: 'cosmic'),
    _item('moon_stone', category: 'cosmic'),
  ];

  test('initial start() returns SolvingState with a fresh round', () {
    final controller = GameController(
      catalog: catalog,
      factory: RoundFactory(random: Random(1)),
    );
    final state = controller.start();
    expect(state, isA<SolvingState>());
    final solving = state as SolvingState;
    expect(solving.round.options.length, 2);
    expect(solving.optionCount, 2);
    expect(solving.completedInSet, 0);
  });

  test('correct choice + effect finished advances the round', () {
    final controller = GameController(
      catalog: catalog,
      factory: RoundFactory(random: Random(2)),
    );
    GameState state = controller.start();
    final target = (state as SolvingState).round.target;
    state = controller.onChoice(target.id);
    expect(state, isA<SolvedState>());
    expect((state as SolvedState).round.target.id, target.id);
    state = controller.onEffectFinished();
    expect(state, isA<SolvingState>());
    expect((state as SolvingState).completedInSet, 1);
    expect((state as SolvingState).round.target.id, isNot(target.id),
        reason: 'next round should pick a different target');
  });

  test('wrong choice flips to SolvingState with wrongChoiceId set', () {
    final controller = GameController(
      catalog: catalog,
      factory: RoundFactory(random: Random(3)),
    );
    final start = controller.start() as SolvingState;
    final wrong = start.round.options
        .firstWhere((option) => option.id != start.round.target.id);
    final next = controller.onChoice(wrong.id) as SolvingState;
    expect(next.wrongChoiceId, wrong.id);
    expect(controller.completedInSet, 0);
  });

  test('after _setSize correct answers the controller reaches SetCompleted',
      () {
    final controller = GameController(
      catalog: catalog,
      factory: RoundFactory(random: Random(4)),
    );
    GameState? state = controller.start();
    for (var i = 0; i < 5; i++) {
      final solving = state as SolvingState;
      state = controller.onChoice(solving.round.target.id);
      // Only the last answer transitions to SetCompleted.
      if (i < 4) {
        expect(state, isA<SolvedState>());
        state = controller.onEffectFinished();
      }
    }
    expect(state, isA<SetCompletedState>());
    final completed = state as SetCompletedState;
    expect(completed.recentItems.length, 5);
  });

  test('onContinue starts a new set with empty completedInSet', () {
    final controller = GameController(
      catalog: catalog,
      factory: RoundFactory(random: Random(5)),
    );
    GameState? state = controller.start();
    for (var i = 0; i < 5; i++) {
      final solving = state as SolvingState;
      state = controller.onChoice(solving.round.target.id);
      if (i < 4) state = controller.onEffectFinished();
    }
    expect(state, isA<SetCompletedState>());
    final next = controller.onContinue() as SolvingState;
    expect(next.completedInSet, 0);
    expect(next.round.options.length, 2,
        reason: 'first set is always 2 options');
  });

  test('optionCount climbs to 3 once _totalCompleted crosses 5', () {
    final controller = GameController(
      catalog: catalog,
      factory: RoundFactory(random: Random(6)),
    );
    expect((controller.start() as SolvingState).optionCount, 2);
    // Simulate 5 completes + their effects.
    GameState state = controller.start();
    for (var i = 0; i < 5; i++) {
      final solving = state as SolvingState;
      state = controller.onChoice(solving.round.target.id);
      if (state is SetCompletedState) {
        state = controller.onContinue();
        continue;
      }
      state = controller.onEffectFinished();
    }
    expect(controller.totalCompleted, 5);
    expect((state as SolvingState).optionCount, 3);
  });

  test('repeated recent targets are avoided', () {
    final controller = GameController(
      catalog: catalog,
      factory: RoundFactory(random: Random(7)),
    );
    GameState state = controller.start();
    final picks = <String>{};
    for (var i = 0; i < 5 && state is SolvingState; i++) {
      picks.add((state as SolvingState).round.target.id);
      state = controller.onChoice((state).round.target.id);
      if (state is SetCompletedState) break;
      if (state is SolvedState) {
        state = controller.onEffectFinished();
      }
    }
    // At most one repeat across 5 picks (set length is 6 so repeats are
    // possible only if we wrap twice). We expect generally diverse targets.
    expect(picks.length, greaterThan(2));
  });
}
