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

  // -------- Issue #20 acceptance tests --------

  group('Issue #20 acceptance: 5 unique targets per set', () {
    test('a full 5-correct set ends with 5 unique recentItems', () {
      final controller = GameController(
        catalog: catalog,
        factory: RoundFactory(random: Random(20)),
      );
      GameState? state = controller.start();
      for (var i = 0; i < 5; i++) {
        final solving = state! as SolvingState;
        controller.onChoice(solving.round.target.id);
        state = controller.onEffectFinished();
      }
      expect(state, isA<SetCompletedState>());
      final completed = state as SetCompletedState;
      expect(completed.recentItems, hasLength(5));
      expect(
        completed.recentItems.map((e) => e.id).toSet(),
        hasLength(5),
        reason: 'every correct answer in a set must hit a unique target',
      );
    });

    test('1000 random sets each produce 5 unique targets', () {
      for (var seed = 1; seed <= 1000; seed++) {
        final controller = GameController(
          catalog: catalog,
          factory: RoundFactory(random: Random(seed)),
        );
        GameState? state = controller.start();
        final ids = <String>{};
        for (var i = 0; i < 5; i++) {
          final solving = state! as SolvingState;
          ids.add(solving.round.target.id);
          controller.onChoice(solving.round.target.id);
          state = controller.onEffectFinished();
        }
        expect(
          ids,
          hasLength(5),
          reason: 'seed $seed produced a duplicate target in one set',
        );
        expect(state, isA<SetCompletedState>(),
            reason: 'seed $seed did not close the set');
      }
    });

    test('6th question is never auto-generated after a 5-correct set', () {
      // After SetCompletedState the controller must NOT silently roll a
      // 6th round; only onContinue (or onRest) may advance.
      final controller = GameController(
        catalog: catalog,
        factory: RoundFactory(random: Random(21)),
      );
      GameState? state = controller.start();
      for (var i = 0; i < 5; i++) {
        final solving = state! as SolvingState;
        controller.onChoice(solving.round.target.id);
        state = controller.onEffectFinished();
      }
      expect(state, isA<SetCompletedState>());
      // Calling onChoice on a SetCompletedState must NOT advance. The
      // controller surfaces a hard StateError so the GamePage (which
      // already guards on `current is! SolvingState`) can never silently
      // trigger a 6th round.
      expect(() => controller.onChoice('gel_star'), throwsStateError,
          reason: 'onChoice after set completion must not advance');
    });

    test('wrong answers do not advance the round and do not consume a target',
        () {
      final controller = GameController(
        catalog: catalog,
        factory: RoundFactory(random: Random(22)),
      );
      GameState? state = controller.start();
      for (var wrongAttempt = 0; wrongAttempt < 10; wrongAttempt++) {
        final solving = state! as SolvingState;
        final wrong = solving.round.options
            .firstWhere((o) => o.id != solving.round.target.id);
        final after = controller.onChoice(wrong.id);
        expect(after, isA<SolvingState>(),
            reason: 'a wrong answer must keep the round open');
        expect((after as SolvingState).wrongChoiceId, wrong.id);
        expect(controller.completedInSet, 0,
            reason: 'wrong answers must not increment completedInSet');
        state = after;
      }
      // Now finish correctly; the set still closes at 5.
      final picks = <String>{};
      for (var i = 0; i < 5; i++) {
        final solving = state! as SolvingState;
        picks.add(solving.round.target.id);
        controller.onChoice(solving.round.target.id);
        state = controller.onEffectFinished();
      }
      expect(state, isA<SetCompletedState>());
      expect(picks, hasLength(5));
    });
  });

  group('Issue #20 acceptance: option-count ladder 2/3/4 by totalCompleted', () {
    test('set 1 (total 0-4) uses 2 options', () {
      final controller = GameController(
        catalog: catalog,
        factory: RoundFactory(random: Random(30)),
      );
      for (var i = 0; i < 4; i++) {
        final state = controller.start() as SolvingState;
        expect(state.optionCount, 2,
            reason: 'set $i should use 2 options (total < 5)');
        controller.onChoice(state.round.target.id);
        controller.onEffectFinished();
        controller.onContinue();
      }
    });

    test('sets 2..4 (total 5..14) use 3 options', () {
      // Total after 5 set completions: 25. Walk the 2nd, 3rd, 4th sets
      // individually.
      final controller = GameController(
        catalog: catalog,
        factory: RoundFactory(random: Random(31)),
      );
      controller.start();
      for (var i = 0; i < 5; i++) {
        final s = controller.current! as SolvingState;
        controller.onChoice(s.round.target.id);
        controller.onEffectFinished();
      }
      controller.onContinue();
      // First set of the 5..14 range.
      expect(
        (controller.current! as SolvingState).optionCount,
        3,
        reason: 'after 5 completions, optionCount climbs to 3',
      );
    });

    test('sets 5+ (total >= 15) use 4 options', () {
      // 6-item catalog supports optionCount=4 cleanly. Resume to 15 to
      // verify the ladder (Issue #20: 0-4 -> 2, 5-14 -> 3, 15+ -> 4).
      final controller = GameController(
        catalog: catalog,
        factory: RoundFactory(random: Random(32)),
      );
      controller.resumeFromTotalCompleted(15);
      final s15 = controller.current! as SolvingState;
      expect(s15.optionCount, 4,
          reason: 'after 15 completions, the next set uses 4 options');
      // 14 completions still uses 3 options.
      final controller14 = GameController(
        catalog: catalog,
        factory: RoundFactory(random: Random(33)),
      );
      controller14.resumeFromTotalCompleted(14);
      expect(
        (controller14.current! as SolvingState).optionCount,
        3,
        reason: 'after 14 completions, the next set still uses 3 options',
      );
    });
  });

  group(
      'Issue #20 follow-up: 5-item catalog plays multiple sets in a row',
      () {
    // Five items is the smallest catalog that satisfies the playability
    // gate. The pre-fix controller kept the previous set's full
    // _recentItems history around, so the second set's 5th round had
    // no eligible target and StateError'd. The fix splits in-set
    // history (cleared on onContinue) from the across-sets last target
    // (passed via previousTargetId).
    final five = <ShadowItem>[
      _item('a', category: 'x'),
      _item('b', category: 'x'),
      _item('c', category: 'x'),
      _item('d', category: 'x'),
      _item('e', category: 'x'),
    ];

    test('5 items, 3 sets, 15 questions in a row (correct-only path)', () {
      final controller = GameController(
        catalog: five,
        factory: RoundFactory(random: Random(50)),
        setSize: 5,
      );
      controller.start();
      final allTargets = <String>[];
      for (var set = 0; set < 3; set++) {
        final ids = <String>{};
        for (var i = 0; i < 5; i++) {
          final solving = controller.current! as SolvingState;
          ids.add(solving.round.target.id);
          allTargets.add(solving.round.target.id);
          controller.onChoice(solving.round.target.id);
          controller.onEffectFinished();
        }
        expect(
          ids,
          hasLength(5),
          reason: 'set $set must contain 5 unique targets',
        );
        expect(controller.current, isA<SetCompletedState>(),
            reason: 'set $set must reach SetCompletedState');
        controller.onContinue();
      }
      expect(controller.totalCompleted, 15);
      // Across all 15 questions the same id should appear at most
      // 3 times (once per set) since onContinue clears the in-set
      // history. The across-sets last target carries over, so each
      // set's first question must avoid the previous set's last
      // target — that's still consistent with 3x repetition of a
      // single id across 3 sets.
      final counts = <String, int>{};
      for (final id in allTargets) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
      for (final entry in counts.entries) {
        expect(
          entry.value,
          lessThanOrEqualTo(3),
          reason:
              'id ${entry.key} appeared ${entry.value} times in 15 questions',
        );
      }
    });

    test('set 2 first-round avoids the previous set\'s last target', () {
      // Regression: the in-set history is cleared on onContinue, but
      // the across-sets last target must still dodge the previous
      // set's last target (just on the first round of the new set).
      final controller = GameController(
        catalog: five,
        factory: RoundFactory(random: Random(51)),
        setSize: 5,
      );
      controller.start();
      for (var i = 0; i < 5; i++) {
        final solving = controller.current! as SolvingState;
        controller.onChoice(solving.round.target.id);
        controller.onEffectFinished();
      }
      final lastOfSet1 =
          (controller.current! as SetCompletedState).recentItems.last.id;
      controller.onContinue();
      // Set 2's first round must NOT target lastOfSet1.
      final firstOfSet2 =
          (controller.current! as SolvingState).round.target.id;
      expect(firstOfSet2, isNot(lastOfSet1),
          reason: 'set 2 first round must avoid set 1 last target');
    });

    test('a wrong answer does not break the 5-item multi-set run', () {
      // Mix in some wrong answers to make sure the recovery path
      // does not poison _lastTargetAcrossSets.
      final controller = GameController(
        catalog: five,
        factory: RoundFactory(random: Random(52)),
        setSize: 5,
      );
      controller.start();
      // 5 correct answers in set 1.
      for (var i = 0; i < 5; i++) {
        final solving = controller.current! as SolvingState;
        controller.onChoice(solving.round.target.id);
        controller.onEffectFinished();
      }
      controller.onContinue();
      // Set 2, round 1: 3 wrong taps, then the correct one.
      var solving = controller.current! as SolvingState;
      for (var i = 0; i < 3; i++) {
        final wrong = solving.round.options
            .firstWhere((o) => o.id != solving.round.target.id);
        controller.onChoice(wrong.id);
        solving = controller.current! as SolvingState;
      }
      controller.onChoice(solving.round.target.id);
      controller.onEffectFinished();
      // Finish set 2 with 4 more correct.
      for (var i = 0; i < 4; i++) {
        final s = controller.current! as SolvingState;
        controller.onChoice(s.round.target.id);
        controller.onEffectFinished();
      }
      expect(controller.current, isA<SetCompletedState>(),
          reason: 'set 2 with 3 wrong taps + 5 correct must still close');
      expect(controller.totalCompleted, 10);
    });
  });
}
