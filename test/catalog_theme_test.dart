// ignore_for_file: prefer_const_constructors

import 'package:animal_shadow_match/data/catalog_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogThemeFromEnvironment defaults to v6Only', () {
    expect(catalogThemeFromEnvironment(), CatalogTheme.v6Only);
    expect(catalogThemeFromEnvironment(value: 'v6'), CatalogTheme.v6Only);
  });

  test('catalogThemeFromEnvironment accepts legacy and all explicitly', () {
    expect(catalogThemeFromEnvironment(value: 'legacy'),
        CatalogTheme.legacyOnly);
    expect(catalogThemeFromEnvironment(value: 'all'), CatalogTheme.all);
  });

  test('catalogThemeFromEnvironment tolerates case and whitespace', () {
    expect(catalogThemeFromEnvironment(value: ' Legacy '),
        CatalogTheme.legacyOnly);
    expect(catalogThemeFromEnvironment(value: 'ALL'), CatalogTheme.all);
  });

  test('catalogThemeFromEnvironment falls back to v6Only for unknown values',
      () {
    expect(catalogThemeFromEnvironment(value: 'legacy-but-only-cows'),
        CatalogTheme.v6Only);
  });
}
