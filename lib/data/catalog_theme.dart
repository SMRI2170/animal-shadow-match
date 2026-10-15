/// Which subset of the bundled catalogs a [CatalogRepository] should
/// consult. The legacy `animals.json` is kept only as a regression
/// baseline during the v6 migration (Issue #29), and the production
/// builds should never mix silhouettes from different sources.
///
/// The four modes correspond 1:1 to the four files under
/// `assets/catalog/`:
/// * **v6Only**     — `items.json` only. This is the production default
///                     once a human reviewer has approved images.
/// * **legacyOnly**  — `animals.json` only. Used by regression tests
///                     and the v4 MVP demo. Children never see it.
/// * **developmentOnly** — `development.json` only. Playable when
///                     `--dart-define ENABLE_DEVELOPMENT_ASSETS=1` is
///                     set; never bundled into release builds.
/// * **all**         — every source merged by id. Reserved for
///                     catalog comparison runs; never the default for
///                     child-facing builds.
enum CatalogTheme {
  /// Production default. Reads only `assets/catalog/items.json`.
  v6Only,

  /// Reads only the legacy `assets/catalog/animals.json`.
  legacyOnly,

  /// Reads only the development `assets/catalog/development.json`.
  /// Only available when the `ENABLE_DEVELOPMENT_ASSETS` dart-define
  /// is true at build time.
  developmentOnly,

  /// Reads every available source. Useful for one-off catalog
  /// comparison runs; never the default for child-facing builds.
  all,
}

/// Resolves the build-time `--dart-define CATALOG_THEME=<value>` flag.
/// Accepts `v6` (default), `legacy`, `development`, and `all`.
CatalogTheme catalogThemeFromEnvironment({String? value}) {
  final raw = (value ?? const String.fromEnvironment('CATALOG_THEME',
          defaultValue: 'v6'))
      .toLowerCase()
      .trim();
  switch (raw) {
    case 'legacy':
      return CatalogTheme.legacyOnly;
    case 'development':
    case 'dev':
      return CatalogTheme.developmentOnly;
    case 'all':
      return CatalogTheme.all;
    case 'v6':
    default:
      return CatalogTheme.v6Only;
  }
}
