import 'dart:convert';

import 'package:animal_shadow_match/data/catalog_load_result.dart';
import 'package:animal_shadow_match/data/catalog_repository.dart';
import 'package:animal_shadow_match/data/catalog_source.dart';
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
    final repo = CatalogRepository.test(bundle);
    final result = await repo.load();
    expect(result.items, hasLength(4));
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
      ]),
    });
    final repo = CatalogRepository.test(bundle);
    final result = await repo.load();
    expect(result.items.map((e) => e.id),
        containsAll(['gel_star', 'cloud_cushion', 'teardrop_gummy']));
    expect(result.hasLiveItems, isTrue);
    expect(result.sources,
        equals({CatalogSource.legacyAnimals, CatalogSource.itemsV6}));
  });

  test('refuses catalogs with fewer than four items', () async {
    final bundle = _MemoryAssetBundle({
      'assets/catalog/items.json': _itemsJson(['a', 'b', 'c']),
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
          _developmentJson(['dev_a', 'dev_b', 'dev_c', 'dev_d']),
    });
    final repo = CatalogRepository.test(bundle);
    await expectLater(
      repo.load,
      throwsA(isA<FormatException>()),
      reason: 'should not read development.json without the switch',
    );
  });

  test('CatalogLoadResult.hasPlaceholders reflects the source set', () {
    final none = CatalogLoadResult(
      items: const <ShadowItem>[],
      sources: const <CatalogSource>{},
    );
    expect(none.hasPlaceholders, isFalse);
    expect(none.hasLiveItems, isFalse);
    final liveOnly = CatalogLoadResult(
      items: const <ShadowItem>[],
      sources: <CatalogSource>{CatalogSource.itemsV6},
    );
    expect(liveOnly.hasPlaceholders, isFalse);
    expect(liveOnly.hasLiveItems, isTrue);
    final placeholder = CatalogLoadResult(
      items: const <ShadowItem>[],
      sources: <CatalogSource>{CatalogSource.developmentPlaceholders},
    );
    expect(placeholder.hasPlaceholders, isTrue);
    expect(placeholder.hasLiveItems, isFalse);
  });
}
