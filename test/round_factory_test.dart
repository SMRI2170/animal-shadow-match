import 'dart:math';

import 'package:animal_shadow_match/domain/shadow_item.dart';
import 'package:animal_shadow_match/domain/round_factory.dart';
import 'package:flutter_test/flutter_test.dart';

ShadowItem _animal(
  String id, {
  String category = 'animal',
  List<String> distractors = const [],
}) {
  return ShadowItem(
    id: id,
    imagePath: 'assets/animals/$id.webp',
    shadowPath: 'assets/animals/${id}_shadow.webp',
    category: category,
    distractorIds: distractors,
  );
}

void main() {
  final catalog = [
    _animal('cat', distractors: ['duck', 'elephant']),
    _animal('duck'),
    _animal('elephant'),
    _animal('rabbit'),
    _animal('whale'),
  ];

  test('exactly one correct option is included', () {
    final factory = RoundFactory(random: Random(1));
    for (var i = 0; i < 100; i++) {
      final round = factory.create(catalog: catalog, optionCount: 3);
      expect(round.options.length, 3);
      expect(round.options.map((a) => a.id).toSet().length, 3);
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
    final multiCategory = <ShadowItem>[
      _animal('a_jelly_1', category: 'jelly', distractors: ['a_jelly_2']),
      _animal('a_jelly_2', category: 'jelly'),
      _animal('b_toy_1', category: 'toy', distractors: ['b_toy_2']),
      _animal('b_toy_2', category: 'toy'),
      _animal('c_cosmic_1', category: 'cosmic', distractors: ['c_cosmic_2']),
      _animal('c_cosmic_2', category: 'cosmic'),
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

  // -------- Issue #3 acceptance tests --------

  group('Issue #3 acceptance: guaranteed uniqueness', () {
    test('single-category catalog of five supports 2/3/4 options', () {
      // Five items in one category. optionCount escalates 2, 3, 4.
      final single = List<ShadowItem>.generate(
        5,
        (i) => _animal('only_$i', category: 'only'),
      );
      final factory = RoundFactory(random: Random(11));
      for (final n in [2, 3, 4]) {
        for (var i = 0; i < 100; i++) {
          final round = factory.create(catalog: single, optionCount: n);
          expect(round.options.length, n, reason: 'optionCount=$n');
          expect(round.options.map((a) => a.id).toSet().length, n);
          expect(round.options.where((a) => a.id == round.target.id).length, 1);
        }
      }
    });

    test('banning every category still fills optionCount when catalog has enough unique items',
        () {
      final factory = RoundFactory(random: Random(12));
      for (var i = 0; i < 50; i++) {
        final round = factory.create(
          catalog: catalog,
          optionCount: 4,
          bannedCategories: const {'animal'},
        );
        expect(round.options.length, 4);
        expect(round.options.map((a) => a.id).toSet().length, 4);
      }
    });

    test('1000 rounds with a fixed seed are byte-identical across factories',
        () {
      // Deterministic guard: regression shield against accidentally
      // introducing `Random()` (no seed) or `DateTime.now()` in the factory.
      // Two factories seeded the same way must produce identical rounds.
      final factoryA = RoundFactory(random: Random(20261015));
      final factoryB = RoundFactory(random: Random(20261015));
      for (var i = 0; i < 1000; i++) {
        final a = factoryA.create(catalog: catalog, optionCount: 3);
        final b = factoryB.create(catalog: catalog, optionCount: 3);
        expect(
          a.options.map((x) => x.id).toList(),
          equals(b.options.map((x) => x.id).toList()),
          reason: 'iteration $i differs across seeded factories',
        );
        expect(a.target.id, b.target.id);
      }
    });
  });

  group('Issue #3 acceptance: explicit rejection, no silent fallback', () {
    test('duplicate id in catalog raises ArgumentError', () {
      final dup = <ShadowItem>[
        _animal('a'),
        _animal('b'),
        _animal('a'),
      ];
      final factory = RoundFactory(random: Random(20));
      expect(
        () => factory.create(catalog: dup, optionCount: 2),
        throwsArgumentError,
      );
    });

    test('optionCount below 2 raises ArgumentError', () {
      final factory = RoundFactory(random: Random(21));
      expect(
        () => factory.create(catalog: catalog, optionCount: 1),
        throwsArgumentError,
      );
      expect(
        () => factory.create(catalog: catalog, optionCount: 0),
        throwsArgumentError,
      );
    });

    test('optionCount larger than catalog raises ArgumentError', () {
      final factory = RoundFactory(random: Random(22));
      expect(
        () => factory.create(catalog: catalog, optionCount: 99),
        throwsArgumentError,
      );
    });

    test('impossible target pick raises StateError when every id is banned',
        () {
      // Four items; previousTargetIds bans all four. The respecting pool
      // and the relaxed pool are both empty, so the factory must surface
      // a hard StateError instead of silently duplicating a target id.
      final four = <ShadowItem>[
        _animal('a', category: 'x'),
        _animal('b', category: 'x'),
        _animal('c', category: 'x'),
        _animal('d', category: 'x'),
      ];
      final factory = RoundFactory(random: Random(23));
      expect(
        () => factory.create(
          catalog: four,
          optionCount: 3,
          previousTargetIds: const ['a', 'b', 'c', 'd'],
        ),
        throwsStateError,
      );
    });

    test('never pads with the target id (Issue #3: unique ids only)', () {
      // Drive 200 rounds on a small catalog and assert no round ever
      // contains the target id twice.
      final small = <ShadowItem>[
        _animal('a'),
        _animal('b'),
        _animal('c'),
        _animal('d'),
      ];
      final factory = RoundFactory(random: Random(24));
      for (var i = 0; i < 200; i++) {
        final round = factory.create(catalog: small, optionCount: 2);
        expect(round.options.length, 2);
        expect(round.options.map((a) => a.id).toSet().length, 2);
        expect(round.options.where((a) => a.id == round.target.id).length, 1);
      }
    });
  });
}
