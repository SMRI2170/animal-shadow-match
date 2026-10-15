/// Which subset of the bundled catalogs a [CatalogRepository] should
/// consult. The legacy `animals.json` is kept only as a regression
/// baseline during the v6 migration (Issue #29), and the production
/// builds should never mix silhouettes from the two sources.
enum CatalogTheme {
  /// Production default. Reads only `assets/catalog/items.json` (and
  /// `development.json` when [CatalogRepository.developmentAssetsEnabled]
  /// is true). Mixing in the legacy animal silhouettes is opt-in only.
  v6Only,

  /// Reads only the legacy `assets/catalog/animals.json`. Used by
  /// regression tests that need to exercise the v4 layout.
  legacyOnly,

  /// Reads both. Useful for one-off catalog comparison runs; never the
  /// default for child-facing builds.
  all,
}

/// Resolves the build-time `--dart-define CATALOG_THEME=<value>` flag.
/// Accepts `v6` (default), `legacy`, and `all`.
CatalogTheme catalogThemeFromEnvironment({String? value}) {
  final raw = (value ?? const String.fromEnvironment('CATALOG_THEME',
          defaultValue: 'v6'))
      .toLowerCase()
      .trim();
  switch (raw) {
    case 'legacy':
      return CatalogTheme.legacyOnly;
    case 'all':
      return CatalogTheme.all;
    case 'v6':
    default:
      return CatalogTheme.v6Only;
  }
}
