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
}
