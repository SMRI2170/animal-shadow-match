/// Where a [ShadowItem] came from. Used by the [CatalogLoadResult] to make
/// the runtime state observable (e.g. "demo mode" UI badge) without leaking
/// any concrete path into the gameplay code.
library;

enum CatalogSource {
  /// v4 legacy animals in `assets/catalog/animals.json`. Kept only as a
  /// regression set during Issue #29 migration.
  legacyAnimals,

  /// v6 single-asset objects in `assets/catalog/items.json`. This is the
  /// production source once MiniMax-approved images are merged.
  itemsV6,

  /// Local placeholder shapes that ship under `assets/development/` and
  /// are bundled only when the build is started with
  /// `--dart-define ENABLE_DEVELOPMENT_ASSETS=1`.
  developmentPlaceholders,
}
