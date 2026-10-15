import 'dart:math';

import 'package:animal_shadow_match/domain/animal.dart';
import 'package:animal_shadow_match/domain/round_factory.dart';
import 'package:flutter_test/flutter_test.dart';

Animal animal(String id, {List<String> distractors = const []}) => Animal(
      id: id,
      name: id,
      imagePath: 'assets/animals/$id.webp',
      shadowPath: 'assets/animals/${id}_shadow.webp',
      category: 'animal',
      distractorIds: distractors,
    );

void main() {
  final catalog = [
    animal('cat', distractors: ['duck', 'elephant']),
    animal('duck'),
    animal('elephant'),
    animal('rabbit'),
    animal('whale'),
  ];

  test('exactly one correct option is included', () {
    final factory = RoundFactory(random: Random(1));
    for (var i = 0; i < 100; i++) {
      final round = factory.create(catalog: catalog, optionCount: 3);
      expect(round.options.length, 3);
      expect(round.options.map((animal) => animal.id).toSet().length, 3);
      expect(round.options.where((a) => a.id == round.target.id).length, 1);
    }
  });

  test('avoids repeating the previous target when alternatives exist', () {
    final factory = RoundFactory(random: Random(2));
    final first = factory.create(catalog: catalog, optionCount: 2);
    final second = factory.create(
      catalog: catalog,
      optionCount: 2,
      previousTargetId: first.target.id,
    );
    expect(second.target.id, isNot(first.target.id));
  });

  test('rejects impossible option count', () {
    final factory = RoundFactory(random: Random(3));
    expect(
      () => factory.create(catalog: catalog, optionCount: 6),
      throwsArgumentError,
    );
  });

  test('falls back to the relaxed pool when the ban covers every category',
      () {
    // The legacy catalog only carries a single 'animal' category, so a
    // ban on 'animal' would normally leave zero eligible items. The
    // factory should still hand back a valid round.
    final factory = RoundFactory(random: Random(4));
    for (var i = 0; i < 50; i++) {
      final round = factory.create(
        catalog: catalog,
        optionCount: 3,
        bannedCategories: const {'animal'},
      );
      expect(round.options.length, 3);
      expect(round.options.map((a) => a.id).toSet().length, 3,
          reason: 'must not duplicate options when relaxing bans');
      expect(round.options.where((a) => a.id == round.target.id).length, 1);
    }
  });

  test('always returns optionCount options when a small catalog is heavily banned',
      () {
    // Six items, three categories. Banning two of the three leaves two
    // items in the respecting pool, so the factory must reach into the
    // "different category" / "any other" ladders to fill optionCount=3.
    final multiCategory = <Animal>[
      animal('a_jelly_1', distractors: ['a_jelly_2']),
      animal('a_jelly_2'),
      animal('b_toy_1', distractors: ['b_toy_2']),
      animal('b_toy_2'),
      animal('c_cosmic_1', distractors: ['c_cosmic_2']),
      animal('c_cosmic_2'),
    ];
    final factory = RoundFactory(random: Random(5));
    for (var i = 0; i < 50; i++) {
      final round = factory.create(
        catalog: multiCategory,
        optionCount: 3,
        bannedCategories: const {'jelly', 'toy'},
      );
      expect(round.options.length, 3);
      expect(round.options.map((a) => a.id).toSet().length, 3);
      expect(round.options.where((a) => a.id == round.target.id).length, 1);
    }
  });
}
