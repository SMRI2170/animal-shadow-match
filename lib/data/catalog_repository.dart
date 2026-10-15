import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/animal.dart';
import '../domain/shadow_item.dart';
import 'catalog_load_result.dart';
import 'catalog_source.dart';
import 'catalog_theme.dart';

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
/// legacy name onto the new [ShadowItem.accessibilityLabel]. To stop
/// mixing the v4 and v6 silhouettes, callers pick a [CatalogTheme].
///
/// **Issue #29 contract:** the development placeholder pool is NEVER
/// served by `v6Only`. The only way to consume it is to select
/// [CatalogTheme.developmentOnly] (or [CatalogTheme.all] for one-off
/// comparison runs). The playability gate (≥5 unique items) is checked
/// in [load] so the UI can render a friendly "no playable set" state
/// instead of letting [RoundFactory] throw deep inside a game loop.
class CatalogRepository {
  /// Production constructor: uses [rootBundle] to resolve assets.
  /// Not `const` because the optional test bundle requires a heap object.
  CatalogRepository({CatalogTheme? theme})
      : theme = theme ?? catalogThemeFromEnvironment(),
        _bundle = null,
        _developmentAssetsEnabled = null;

  /// Test override: pass a fake bundle that resolves every key in memory.
  @visibleForTesting
  CatalogRepository.test(
    AssetBundle bundle, {
    this.theme = CatalogTheme.v6Only,
    bool? developmentAssetsEnabled,
  })  : _bundle = bundle,
        _developmentAssetsEnabled = developmentAssetsEnabled;

  /// Restrict the catalog to a specific source. When null in production,
  /// the value is read from the `CATALOG_THEME` `--dart-define` flag;
  /// the default is [CatalogTheme.v6Only].
  final CatalogTheme? theme;

  /// Minimum number of unique items required to start a 5-question set
  /// (Issue #29: distinguish 4-distractor playability from 5-set
  /// playability). Below this threshold [load] throws a [FormatException]
  /// carrying a clear "no playable set" message.
  static const int minItemsForPlayableSet = 5;

  final AssetBundle? _bundle;
  final bool? _developmentAssetsEnabled;

  /// Whether the development placeholder pool is bundled into the running
  /// build. Controlled at build time via
  /// `--dart-define ENABLE_DEVELOPMENT_ASSETS=1`. Tests override this
  /// per-instance via [CatalogRepository.test].
  static const bool developmentAssetsEnabled =
      bool.fromEnvironment('ENABLE_DEVELOPMENT_ASSETS', defaultValue: false);

  Future<CatalogLoadResult> load() async {
    final resolver = _bundle ?? rootBundle;
    final effectiveTheme = theme ?? catalogThemeFromEnvironment();
    final byId = <String, ShadowItem>{};
    final sources = <CatalogSource>{};

    // Issue #29: the development placeholder pool is *opt-in*. We never
    // append it to v6Only / legacyOnly — the only way to consume it is
    // `developmentOnly` or `all` (the comparison-only mode).
    final includeLegacy = effectiveTheme == CatalogTheme.all ||
        effectiveTheme == CatalogTheme.legacyOnly;
    final includeV6 = effectiveTheme == CatalogTheme.all ||
        effectiveTheme == CatalogTheme.v6Only;
    final devEnabled = _developmentAssetsEnabled ?? developmentAssetsEnabled;
    final includeDev = devEnabled &&
        (effectiveTheme == CatalogTheme.all ||
            effectiveTheme == CatalogTheme.developmentOnly);

    if (includeLegacy) {
      final legacy = await _tryLoad(resolver, 'assets/catalog/animals.json');
      if (legacy != null) {
        sources.add(CatalogSource.legacyAnimals);
        for (final entry in legacy) {
          byId[entry.id] = entry;
        }
      }
    }

    if (includeV6) {
      final items = await _tryLoad(resolver, 'assets/catalog/items.json');
      if (items != null) {
        sources.add(CatalogSource.itemsV6);
        for (final entry in items) {
          byId[entry.id] = entry;
        }
      }
    }

    if (includeDev) {
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
    if (entries.length < minItemsForPlayableSet) {
      throw FormatException(
        'Catalog needs at least $minItemsForPlayableSet unique items to '
        'start a 5-question set (got ${entries.length} from $sources). '
        'Pick a different CatalogTheme or add approved images to '
        'items.json (Issue #29).',
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
