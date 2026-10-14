import 'dart:convert';

import 'package:animal_shadow_match/domain/shadow_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// In-memory [AssetBundle] that resolves every well-known asset key from a
/// flat map. Lets widget tests mount widgets with `Image.asset(...)` paths
/// without bundling the real WebP files.
class InMemoryAssetBundle extends CachingAssetBundle {
  InMemoryAssetBundle(this._entries);

  final Map<String, Object> _entries;

  static const _missingError = 'asset missing from test bundle: ';

  @override
  Future<ByteData> load(String key) async {
    final value = _entries[key];
    if (value is List<int>) {
      return ByteData.view(Uint8List.fromList(value).buffer);
    }
    throw FlutterError('$_missingError$key');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = _entries[key];
    if (value is! String) {
      throw FlutterError('$_missingError$key');
    }
    return value;
  }
}

/// Minimal 1x1 transparent PNG. Two visible bytes would be enough to render
/// but the Flutter asset decoder expects valid PNG framing.
List<int> transparentPixelPng() {
  return const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ];
}

/// Build a bundle that resolves every image path on the given [items]
/// plus the catalog JSON; useful for [SingleAssetEffect] / [GamePage] tests.
InMemoryAssetBundle bundleForItems(
  Iterable<ShadowItem> items, {
  String catalogJson = '{"items":[]}',
  String catalogKey = 'assets/catalog/items.json',
}) {
  final entries = <String, Object>{
    catalogKey: catalogJson,
    for (final item in items) ...{
      item.imagePath: transparentPixelPng(),
      item.shadowPath: transparentPixelPng(),
    },
  };
  return InMemoryAssetBundle(entries);
}

/// Convenience helpers for tests that build fully-formed JSON strings.
String itemsJson(Iterable<ShadowItem> items) {
  return jsonEncode({
    'items': [
      for (final item in items)
        {
          'id': item.id,
          'image': item.imagePath,
          'shadow': item.shadowPath,
          'category': item.category,
          'distractors': item.distractorIds,
        },
    ],
  });
}
