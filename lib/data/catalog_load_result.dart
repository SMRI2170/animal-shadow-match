import 'catalog_source.dart';
import '../domain/shadow_item.dart';

/// Result of a catalog load. Lets the UI distinguish between the three
/// operating modes (S2 live / S1 placeholder / S0 absent) without the rest
/// of the game caring about asset paths.
class CatalogLoadResult {
  const CatalogLoadResult({
    required this.items,
    required this.sources,
  });

  /// All entries the gameplay should iterate over. May combine sources
  /// (legacy + v6) while keeping IDs unique.
  final List<ShadowItem> items;

  /// Which catalogs contributed to [items]. Never empty when [items] is.
  final Set<CatalogSource> sources;

  bool get hasLiveItems => sources.contains(CatalogSource.itemsV6);

  /// True when at least one item originated from
  /// [CatalogSource.developmentPlaceholders]. The UI uses this to render a
  /// "demo / placeholder" affordance so reviewers and parents can spot
  /// unreleased art.
  bool get hasPlaceholders =>
      sources.contains(CatalogSource.developmentPlaceholders);

  bool get isEmpty => items.isEmpty;
}
