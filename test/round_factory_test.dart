import 'dart:math';

import 'package:animal_shadow_match/domain/shadow_item.dart';
import 'package:animal_shadow_match/domain/round_factory.dart';
import 'package:flutter_test/flutter_test.dart';

ShadowItem _animal(
  String id, {
  String category = 'animal',
  List<String> distractors = const [],
  String? similarityGroup,
}) {
  return ShadowItem(
    id: id,
    imagePath: 'assets/animals/$id.webp',
    shadowPath: 'assets/animals/${id}_shadow.webp',
    category: category,
    distractorIds: distractors,
    similarityGroup: similarityGroup,
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

  // -------- Issue #89 follow-up: similarity-group exclusion --------

  group('Issue #89 follow-up: similarityGroup excludes same-shape distractors', () {
    test('no distractor shares the target similarityGroup', () {
      // `stacked_disks` and `wavy_disc` are visually interchangeable
      // (both round with perimeter dots). Both belong to `round_disc`.
      // When either is the target, the other must NEVER appear as a
      // distractor — even when it would otherwise be a natural fill.
      final factory = RoundFactory(random: Random(31));
      final catalog = <ShadowItem>[
        _animal('stacked_disks',
            category: 'toys', similarityGroup: 'round_disc'),
        _animal('wavy_disc',
            category: 'toys', similarityGroup: 'round_disc'),
        _animal('puzzle_bean', category: 'toys'),
        _animal('soft_planet', category: 'cosmic'),
        _animal('moon_stone', category: 'cosmic'),
      ];
      for (var i = 0; i < 200; i++) {
        final round = factory.create(catalog: catalog, optionCount: 3);
        expect(round.options.length, 3);
        final others = round.options
            .where((o) => o.id != round.target.id)
            .toList();
        if (round.target.similarityGroup != null) {
          for (final d in others) {
            expect(d.similarityGroup, isNot(round.target.similarityGroup),
                reason: 'round $i: distractor ${d.id} shares the target '
                    '${round.target.id} similarityGroup '
                    '"${round.target.similarityGroup}"');
          }
        }
      }
    });

    test('items in different similarityGroups co-exist as target/distractor', () {
      // Sanity: the similarity rule only matches same-group pairs; a
      // round with target in group A may freely include a distractor in
      // group B. Use a 3-item catalog with optionCount=2 so the single
      // distractor slot is filled by the only different-category item,
      // deterministically.
      final factory = RoundFactory(random: Random(32));
      final catalog = <ShadowItem>[
        _animal('a_jelly', category: 'jelly', similarityGroup: 'group_a'),
        _animal('b_jelly', category: 'toy', similarityGroup: 'group_b'),
        _animal('c_toy', category: 'toy', similarityGroup: 'group_c'),
      ];
      final round = factory.create(
        catalog: catalog,
        optionCount: 2,
        previousTargetIds: const ['c_toy'],
      );
      expect(round.target.id, 'a_jelly');
      expect(round.options.where((o) => o.id == 'b_jelly').length, 1,
          reason: 'cross-group distractor must be allowed when groups differ');
    });

    test('catalog whose same-group population leaves too few distractors '
        'surfaces a StateError instead of silently falling back', () {
      // Pin the target to `one` so its similarityGroup (`shared`) is
      // deterministic. Four of the five items share that group; the
      // factory would need 3 distinct distractors in *different* groups
      // to satisfy optionCount=4, but the catalog only has one such item
      // (`five`). Hard StateError, not a silent fallback (Issue #3).
      final factory = RoundFactory(random: Random(33));
      final five = <ShadowItem>[
        _animal('one', category: 'a', similarityGroup: 'shared'),
        _animal('two', category: 'b', similarityGroup: 'shared'),
        _animal('three', category: 'c', similarityGroup: 'shared'),
        _animal('four', category: 'd', similarityGroup: 'shared'),
        _animal('five', category: 'e', similarityGroup: 'alone'),
      ];
      // Ban every id except `one` so the target is pinned to it
      // regardless of the Random sequence.
      expect(
        () => factory.create(
          catalog: five,
          optionCount: 4,
          previousTargetIds: const ['two', 'three', 'four', 'five'],
        ),
        throwsStateError,
        reason: 'factory must refuse to take a same-group distractor '
            'or pad with the target id',
      );
    });

    test('null similarityGroup on the target imposes no constraint', () {
      // Backwards-compat: items without a similarityGroup must keep the
      // pre-Issue-#89 behaviour where they may co-occur as target and
      // distractor.
      final factory = RoundFactory(random: Random(34));
      final plain = <ShadowItem>[
        _animal('a'),
        _animal('b'),
        _animal('c'),
        _animal('d'),
        _animal('e'),
      ];
      for (var i = 0; i < 100; i++) {
        final round = factory.create(catalog: plain, optionCount: 4);
        expect(round.options.length, 4);
        expect(round.options.map((o) => o.id).toSet().length, 4);
      }
    });
  });
}
