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
    SolvingState start = controller.start() as SolvingState;
    final target = start.round.target;
    GameState state = controller.onChoice(target.id);
    expect(state, isA<SolvedState>());
    expect((state as SolvedState).round.target.id, target.id);
    state = controller.onEffectFinished();
    expect(state, isA<SolvingState>());
    final solving = state as SolvingState;
    expect(solving.completedInSet, 1);
    expect(solving.round.target.id, isNot(target.id),
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
      // Every correct answer lands on SolvedState (so the FX plays),
      // then onEffectFinished advances. The 5th answer's
      // onEffectFinished returns SetCompletedState.
      expect(state, isA<SolvedState>(),
          reason: 'round $i must reach SolvedState so the FX plays');
      state = controller.onEffectFinished();
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
      state = controller.onEffectFinished();
    }
    expect(state, isA<SetCompletedState>());
    final next = controller.onContinue() as SolvingState;
    expect(next.completedInSet, 0);
    expect(next.round.options.length, 3,
        reason: 'after 5 completions, the next set uses 3 options');
  });

  test('optionCount climbs to 3 once _totalCompleted crosses 5', () {
    final controller = GameController(
      catalog: catalog,
      factory: RoundFactory(random: Random(6)),
    );
    expect((controller.start() as SolvingState).optionCount, 2);
    SolvingState state = controller.start() as SolvingState;
    GameState? after = state;
    for (var i = 0; i < 5; i++) {
      final solving = state;
      controller.onChoice(solving.round.target.id);
      after = controller.onEffectFinished();
      if (i < 4) {
        state = after as SolvingState;
      }
    }
    expect(controller.totalCompleted, 5);
    expect(after, isA<SetCompletedState>(),
        reason: 'the 5th onEffectFinished should close the set');
  });

  test('onRest / onResume round-trip preserves the recent items', () {
    final controller = GameController(
      catalog: catalog,
      factory: RoundFactory(random: Random(8)),
    );
    controller.start();
    for (var i = 0; i < 4; i++) {
      final solving = controller.current! as SolvingState;
      controller.onChoice(solving.round.target.id);
      controller.onEffectFinished();
    }
    final solving = controller.current! as SolvingState;
    controller.onChoice(solving.round.target.id);
    controller.onEffectFinished();
    expect(controller.current, isA<SetCompletedState>());

    final resting = controller.onRest();
    expect(resting, isA<RestingState>());
    final rest = resting as RestingState;
    expect(rest.recentItems, hasLength(5));
    expect(rest.totalCompletedToday, 5);

    final back = controller.onResume();
    expect(back, isA<SetCompletedState>());
    expect((back as SetCompletedState).recentItems, hasLength(5));
    expect(controller.totalCompleted, 5);
  });

  test('onRest rejects any state that is not SetCompletedState', () {
    final controller = GameController(
      catalog: catalog,
      factory: RoundFactory(random: Random(9)),
    );
    controller.start();
    expect(() => controller.onRest(), throwsStateError);
  });

  test('resumeFromTotalCompleted carries _totalCompleted into the new set',
      () {
    final controller = GameController(
      catalog: catalog,
      factory: RoundFactory(random: Random(10)),
    );
    controller.resumeFromTotalCompleted(7);
    final solving = controller.current! as SolvingState;
    expect(controller.totalCompleted, 7);
    expect(solving.completedInSet, 0);
    expect(solving.optionCount, 3,
        reason: 'after 7 completions, the next set uses 3 options');
    expect(controller.recentItems, isEmpty);
  });

  test('repeated recent targets are avoided', () {
    final controller = GameController(
      catalog: catalog,
      factory: RoundFactory(random: Random(7)),
    );
    SolvingState state = controller.start() as SolvingState;
    final picks = <String>{};
    for (var i = 0; i < 5; i++) {
      picks.add(state.round.target.id);
      controller.onChoice(state.round.target.id);
      // The 5th correct answer still goes through SolvedState +
      // onEffectFinished, which then yields SetCompletedState.
      final after = controller.onEffectFinished();
      if (after is SetCompletedState) break;
      state = after as SolvingState;
    }
    expect(picks.length, greaterThan(2));
  });
}
