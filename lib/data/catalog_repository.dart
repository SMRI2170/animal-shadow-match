import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/animal.dart';
import '../domain/shadow_item.dart';

/// Loads the playable catalog from the bundled JSON assets.
///
/// During the staged migration (Issue #29) the repository accepts both the
/// legacy `animals.json` and the new `items.json`. New items are taken from
/// `items.json`; if that file is missing, the loader falls back to the
/// existing `animals.json` so the demo game keeps running while the v6
/// pipeline produces real objects.
///
/// The two lists are merged by id. Conflicts (same id in both files) are
/// resolved in favor of the new `items.json` entry so the curated PR
/// pipeline can override demo defaults without touching the 8 placeholders.
class CatalogRepository {
  const CatalogRepository();

  Future<List<ShadowItem>> load() async {
    final byId = <String, ShadowItem>{};
    final legacy = await _tryLoad('assets/catalog/animals.json');
    if (legacy != null) {
      for (final entry in legacy) {
        byId[entry.id] = entry;
      }
    }
    final items = await _tryLoad('assets/catalog/items.json');
    if (items != null) {
      for (final entry in items) {
        byId[entry.id] = entry;
      }
    }
    if (byId.isEmpty) {
      throw const FormatException(
        'Catalog is empty: provide assets/catalog/items.json and/or animals.json',
      );
    }
    final entries = byId.values.toList(growable: false);
    if (entries.length < 4) {
      throw FormatException(
        'Catalog requires at least 4 items (currently ${entries.length})',
      );
    }
    return entries;
  }

  Future<List<ShadowItem>?> _tryLoad(String key) async {
    try {
      final raw = await rootBundle.loadString(key);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final data = json['items'] ?? json['animals'];
      if (data is! List) return null;
      final loaded = <ShadowItem>[];
      for (final dynamic entry in data) {
        if (entry is! Map<String, dynamic>) continue;
        final shadow = ShadowItem.fromJson(entry);
        if (!isValidItemId(shadow.id)) {
          throw FormatException('Invalid catalog id: ${shadow.id}');
        }
        loaded.add(shadow);
      }
      return loaded;
    } catch (_) {
      // Asset missing or unreadable; treated as "no entries" so the caller
      // can decide whether the catalog is otherwise complete.
      return null;
    }
  }
}

/// Convenience used in tests and dev seeds: hydrate the legacy `name`
/// fields into a [ShadowItem] without loading the JSON twice.
ShadowItem animalToShadowItem(Map<String, dynamic> json) {
  return Animal.fromJson(json);
}
