import 'dart:convert';

import 'package:animal_shadow_match/data/catalog_load_result.dart';
import 'package:animal_shadow_match/data/catalog_repository.dart';
import 'package:animal_shadow_match/data/catalog_source.dart';
import 'package:animal_shadow_match/data/catalog_theme.dart';
import 'package:animal_shadow_match/domain/shadow_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal AssetBundle that resolves a fixed in-memory map of assets.
class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(this._entries);

  final Map<String, Object> _entries;

  static const _missingError =
      'Asset not found in test bundle. Add it to _MemoryAssetBundle.';

  @override
  Future<ByteData> load(String key) async {
    final value = _entries[key];
    if (value == null) {
      throw FlutterError('$_missingError key=$key');
    }
    if (value is List<int>) {
      return ByteData.view(Uint8List.fromList(value).buffer);
    }
    throw FlutterError('Unsupported test asset: $key');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = _entries[key];
    if (value is! String) {
      throw FlutterError('$_missingError key=$key');
    }
    return value;
  }
}

String _itemsJson(List<String> ids) => jsonEncode({
      'items': [
        for (final id in ids)
          {
            'id': id,
            'image': 'assets/items/$id.webp',
            'shadow': 'assets/items/${id}_shadow.webp',
            'category': 'squishy_object',
            'distractors': [],
          },
      ],
    });

String _legacyAnimalsJson() => jsonEncode({
      'animals': [
        {
          'id': 'giraffe',
          'name': 'Giraffe',
          'image': 'assets/animals/giraffe.webp',
          'shadow': 'assets/animals/giraffe_shadow.webp',
          'category': 'savanna',
          'distractors': ['elephant'],
        },
        {
          'id': 'elephant',
          'name': 'Elephant',
          'image': 'assets/animals/elephant.webp',
          'shadow': 'assets/animals/elephant_shadow.webp',
          'category': 'savanna',
          'distractors': ['giraffe'],
        },
        {
          'id': 'rabbit',
          'name': 'Rabbit',
          'image': 'assets/animals/rabbit.webp',
          'shadow': 'assets/animals/rabbit_shadow.webp',
          'category': 'farm',
          'distractors': [],
        },
        {
          'id': 'cat',
          'name': 'Cat',
          'image': 'assets/animals/cat.webp',
          'shadow': 'assets/animals/cat_shadow.webp',
          'category': 'farm',
          'distractors': [],
        },
        {
          'id': 'whale',
          'name': 'Whale',
          'image': 'assets/animals/whale.webp',
          'shadow': 'assets/animals/whale_shadow.webp',
          'category': 'ocean',
          'distractors': [],
        },
      ],
    });

String _developmentJson(List<String> ids) => jsonEncode({
      'items': [
        for (final id in ids)
          {
            'id': id,
            'image': 'assets/development/$id.webp',
            'shadow': 'assets/development/${id}_shadow.webp',
            'category': 'squishy_object',
            'distractors': [],
            'effectPreset': 'squish',
          },
      ],
    });

void main() {
  // Sanity: when the dart-define is off (default), the developer flag is
  // false so production builds cannot accidentally ship placeholders.
  test('developmentAssetsEnabled defaults to false', () {
    expect(CatalogRepository.developmentAssetsEnabled, isFalse);
  });

  test('returns legacy animals + catalog source when only animals.json is present', () async {
    final bundle = _MemoryAssetBundle({
      'assets/catalog/animals.json': _legacyAnimalsJson(),
    });
    final repo = CatalogRepository.test(bundle, theme: CatalogTheme.legacyOnly);
    final result = await repo.load();
    expect(result.items, hasLength(5));
    expect(result.sources, equals({CatalogSource.legacyAnimals}));
    expect(result.hasLiveItems, isFalse);
    expect(result.hasPlaceholders, isFalse);
  });

  test('items.json shadows the legacy list when ids collide', () async {
    final bundle = _MemoryAssetBundle({
      'assets/catalog/animals.json': _legacyAnimalsJson(),
      'assets/catalog/items.json': _itemsJson([
        'gel_star',
        'cloud_cushion',
        'teardrop_gummy',
        'twist_gummy',
        'puzzle_bean',
      ]),
    });
    final repo = CatalogRepository.test(bundle, theme: CatalogTheme.all);
    final result = await repo.load();
    expect(result.items.map((e) => e.id),
        containsAll(['gel_star', 'cloud_cushion', 'teardrop_gummy']));
    expect(result.hasLiveItems, isTrue);
    expect(result.sources,
        equals({CatalogSource.legacyAnimals, CatalogSource.itemsV6}));
  });

  test('refuses catalogs with fewer than five items (Issue #29)', () async {
    final bundle = _MemoryAssetBundle({
      'assets/catalog/items.json': _itemsJson(['a', 'b', 'c', 'd']),
    });
    final repo = CatalogRepository.test(bundle);
    await expectLater(
      repo.load,
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects catalog ids that are not lowercase ASCII', () async {
    final bundle = _MemoryAssetBundle({
      'assets/catalog/items.json': jsonEncode({
        'items': [
          {
            'id': 'Bad-Id',
            'image': 'x.webp',
            'shadow': 'x_shadow.webp',
            'category': 'c',
            'distractors': [],
          },
          {
            'id': 'cloud_cushion',
            'image': 'y.webp',
            'shadow': 'y_shadow.webp',
            'category': 'c',
            'distractors': [],
          },
          {
            'id': 'teardrop_gummy',
            'image': 'z.webp',
            'shadow': 'z_shadow.webp',
            'category': 'c',
            'distractors': [],
          },
          {
            'id': 'twist_gummy',
            'image': 'q.webp',
            'shadow': 'q_shadow.webp',
            'category': 'c',
            'distractors': [],
          },
        ],
      }),
    });
    final repo = CatalogRepository.test(bundle);
    await expectLater(
      repo.load,
      throwsA(isA<FormatException>()),
    );
  });

  test('development.json is only consulted when the dart-define is true',
      () async {
    final bundle = _MemoryAssetBundle({
      'assets/catalog/development.json':
          _developmentJson(['dev_a', 'dev_b', 'dev_c', 'dev_d', 'dev_e']),
    });
    final repo = CatalogRepository.test(bundle);
    await expectLater(
      repo.load,
      throwsA(isA<FormatException>()),
      reason:
          'should not read development.json without the dart-define or '
          'a developmentOnly theme',
    );
  });

  test(
      'developmentOnly theme reads development.json when dart-define is on',
      () async {
    final bundle = _MemoryAssetBundle({
      'assets/catalog/development.json': _developmentJson(
          ['dev_a', 'dev_b', 'dev_c', 'dev_d', 'dev_e']),
    });
    final repo = CatalogRepository.test(
      bundle,
      theme: CatalogTheme.developmentOnly,
      developmentAssetsEnabled: true,
    );
    final result = await repo.load();
    expect(result.items, hasLength(5));
    expect(result.sources,
        equals({CatalogSource.developmentPlaceholders}));
  });

  test('v6Only theme never picks up development.json even when it exists',
      () async {
    final bundle = _MemoryAssetBundle({
      'assets/catalog/development.json': _developmentJson(
          ['dev_a', 'dev_b', 'dev_c', 'dev_d', 'dev_e']),
    });
    final repo = CatalogRepository.test(
      bundle,
      theme: CatalogTheme.v6Only,
      developmentAssetsEnabled: true,
    );
    // v6Only + only development.json present => no entries => 5-item gate
    // raises FormatException, NOT the development pool.
    await expectLater(
      repo.load,
      throwsA(isA<FormatException>()),
    );
  });

  test('legacyOnly theme never picks up development.json', () async {
    final bundle = _MemoryAssetBundle({
      'assets/catalog/animals.json': _legacyAnimalsJson(),
      'assets/catalog/development.json': _developmentJson(
          ['dev_a', 'dev_b', 'dev_c', 'dev_d', 'dev_e']),
    });
    final repo = CatalogRepository.test(
      bundle,
      theme: CatalogTheme.legacyOnly,
      developmentAssetsEnabled: true,
    );
    final result = await repo.load();
    expect(result.sources, equals({CatalogSource.legacyAnimals}));
    expect(result.hasPlaceholders, isFalse);
  });

  test('all theme merges every source, but unique-by-id wins', () async {
    final bundle = _MemoryAssetBundle({
      'assets/catalog/animals.json': _legacyAnimalsJson(),
      'assets/catalog/items.json': _itemsJson([
        'gel_star',
        'cloud_cushion',
        'teardrop_gummy',
        'twist_gummy',
        'puzzle_bean',
      ]),
      'assets/catalog/development.json': _developmentJson(
          ['dev_a', 'dev_b', 'dev_c', 'dev_d', 'dev_e']),
    });
    final repo = CatalogRepository.test(
      bundle,
      theme: CatalogTheme.all,
      developmentAssetsEnabled: true,
    );
    final result = await repo.load();
    expect(result.sources, equals({
      CatalogSource.legacyAnimals,
      CatalogSource.itemsV6,
      CatalogSource.developmentPlaceholders,
    }));
    // 5 legacy + 5 items + 5 dev = 15 unique ids.
    expect(result.items.length, 15);
  });

  test('CatalogLoadResult.hasPlaceholders reflects the source set', () {
    const none = CatalogLoadResult(
      items: <ShadowItem>[],
      sources: <CatalogSource>{},
    );
    expect(none.hasPlaceholders, isFalse);
    expect(none.hasLiveItems, isFalse);
    // ignore: prefer_const_constructors
    final liveOnly = CatalogLoadResult(
      items: const <ShadowItem>[],
      sources: <CatalogSource>{CatalogSource.itemsV6},
    );
    expect(liveOnly.hasPlaceholders, isFalse);
    expect(liveOnly.hasLiveItems, isTrue);
    // ignore: prefer_const_constructors
    final placeholder = CatalogLoadResult(
      items: const <ShadowItem>[],
      sources: <CatalogSource>{CatalogSource.developmentPlaceholders},
    );
    expect(placeholder.hasPlaceholders, isTrue);
    expect(placeholder.hasLiveItems, isFalse);
  });
}
