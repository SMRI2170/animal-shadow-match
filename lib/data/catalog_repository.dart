import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/animal.dart';
import '../domain/shadow_item.dart';
import 'catalog_load_result.dart';
import 'catalog_source.dart';

/// Loads the playable catalog from the bundled JSON assets.
///
/// Supports three operating modes (S2/S1/S0) as documented in
/// `docs/GAME_LOGIC_WITHOUT_IMAGES_JA.md` §1:
///
/// * **S2 live** — `assets/catalog/items.json` populated by
///   the Draft-PR pipeline (`promote-minimax-assets.yml`).
/// * **S1 placeholder** — `assets/catalog/development.json` shipped with
///   the project under `assets/development/`. Only read when the build was
///   started with `--dart-define ENABLE_DEVELOPMENT_ASSETS=1`, so production
///   bundles can never ship placeholders by accident.
/// * **S0 absent** — neither JSON exists. The UI will surface a friendly
///   "Catalog empty" state.
///
/// Legacy `animals.json` is still loaded as a regression baseline; entries
/// from there are merged by id with the live catalog and shadow the
/// legacy name onto the new [ShadowItem.accessibilityLabel].
class CatalogRepository {
  /// Production constructor: uses [rootBundle] to resolve assets.
  /// Not `const` because the optional test bundle requires a heap object.
  CatalogRepository() : _bundle = null;

  /// Test override: pass a fake bundle that resolves every key in memory.
  @visibleForTesting
  CatalogRepository.test(AssetBundle bundle) : _bundle = bundle;

  final AssetBundle? _bundle;

  static const bool developmentAssetsEnabled =
      bool.fromEnvironment('ENABLE_DEVELOPMENT_ASSETS', defaultValue: false);

  Future<CatalogLoadResult> load() async {
    final resolver = _bundle ?? rootBundle;
    final byId = <String, ShadowItem>{};
    final sources = <CatalogSource>{};

    final legacy = await _tryLoad(resolver, 'assets/catalog/animals.json');
    if (legacy != null) {
      sources.add(CatalogSource.legacyAnimals);
      for (final entry in legacy) {
        byId[entry.id] = entry;
      }
    }

    final items = await _tryLoad(resolver, 'assets/catalog/items.json');
    if (items != null) {
      sources.add(CatalogSource.itemsV6);
      for (final entry in items) {
        byId[entry.id] = entry;
      }
    }

    if (developmentAssetsEnabled) {
      final dev =
          await _tryLoad(resolver, 'assets/catalog/development.json');
      if (dev != null) {
        sources.add(CatalogSource.developmentPlaceholders);
        for (final entry in dev) {
          byId[entry.id] = entry;
        }
      }
    }

    final entries = byId.values.toList(growable: false);
    if (entries.length < 4) {
      throw FormatException(
        'Catalog requires at least 4 items (currently ${entries.length})',
      );
    }
    return CatalogLoadResult(items: entries, sources: sources);
  }

  Future<List<ShadowItem>?> _tryLoad(
    AssetBundle resolver,
    String key,
  ) async {
    try {
      final raw = await resolver.loadString(key);
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
