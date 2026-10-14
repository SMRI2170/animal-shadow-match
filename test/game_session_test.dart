import 'dart:math';

import 'package:animal_shadow_match/domain/game_session.dart';
import 'package:animal_shadow_match/domain/round_factory.dart';
import 'package:animal_shadow_match/domain/shadow_item.dart';
import 'package:flutter_test/flutter_test.dart';

List<ShadowItem> makeCatalog(int count) {
  return List.generate(count, (i) {
    final id = 'item_$i';
    return ShadowItem(
      id: id,
      imagePath: 'assets/animals/cat.webp',
      shadowPath: 'assets/animals/cat_shadow.webp',
      category: 'demo',
      distractorIds: const [],
    );
  });
}

void main() {
  test('wrong answer does not advance; rapid double answer is ignored', () {
    final session = GameSession(
      catalog: makeCatalog(8),
      roundFactory: RoundFactory(random: Random(7)),
    );
    final target = session.round.target;
    final wrong = session.round.options.firstWhere((v) => v.id != target.id);
    expect(session.choose(wrong.id), isFalse);
    expect(session.round.target.id, target.id);
    expect(session.choose(target.id), isTrue);
    expect(session.awaitingReaction, isTrue);
    expect(session.choose(target.id), isFalse);
    session.finishReaction();
    session.finishReaction();
    expect(session.totalCompleted, 1);
    expect(session.setItems, hasLength(1));
  });

  test('five unique matches unlock a touch playground', () {
    final session = GameSession(
      catalog: makeCatalog(8),
      roundFactory: RoundFactory(random: Random(2)),
    );
    final seen = <String>{};
    for (var i = 0; i < 5; i++) {
      expect(session.phase, GamePhase.matching);
      expect(session.optionCount, 2);
      final round = session.round;
      expect(round.options, hasLength(2));
      expect(round.options.where((v) => v.id == round.target.id), hasLength(1));
      expect(seen.add(round.target.id), isTrue,
          reason: 'no repeat in a set when enough items exist');
      expect(session.choose(round.target.id), isTrue);
      session.finishReaction();
    }
    expect(session.phase, GamePhase.playground);
    expect(session.setItems, hasLength(5));
    expect(session.totalCompleted, 5);
    expect(session.choose(session.setItems.last.id), isFalse);
    session.continuePlaying();
    expect(session.phase, GamePhase.matching);
    expect(session.setItems, isEmpty);
    expect(session.optionCount, 3);
    expect(session.round.options, hasLength(3));
  });

  test('break and return retain the five toy items', () {
    final session = GameSession(
      catalog: makeCatalog(6),
      roundFactory: RoundFactory(random: Random(3)),
    );
    for (var i = 0; i < 5; i++) {
      expect(session.choose(session.round.target.id), isTrue);
      session.finishReaction();
    }
    final saved = session.setItems.map((v) => v.id).toList();
    session.takeBreak();
    expect(session.phase, GamePhase.resting);
    session.continuePlaying(); // must not bypass the break
    expect(session.phase, GamePhase.resting);
    session.resume();
    expect(session.phase, GamePhase.playground);
    expect(session.setItems.map((v) => v.id), saved);
  });

  test('a small four-item catalog still completes five matches', () {
    final session = GameSession(
      catalog: makeCatalog(4),
      roundFactory: RoundFactory(random: Random(5)),
    );
    for (var i = 0; i < 5; i++) {
      expect(session.choose(session.round.target.id), isTrue);
      session.finishReaction();
    }
    expect(session.phase, GamePhase.playground);
  });

  test('choice difficulty grows from 2 to 3 to 4', () {
    final session = GameSession(
      catalog: makeCatalog(9),
      roundFactory: RoundFactory(random: Random(13)),
    );
    for (var i = 0; i < 16; i++) {
      expect(session.optionCount, i < 5 ? 2 : (i < 15 ? 3 : 4));
      expect(session.choose(session.round.target.id), isTrue);
      session.finishReaction();
      if (session.phase == GamePhase.playground) session.continuePlaying();
    }
  });
}
