import 'dart:convert';
import 'package:flutter/services.dart';

import '../domain/animal.dart';

class CatalogRepository {
  const CatalogRepository();

  Future<List<Animal>> load() async {
    final raw = await rootBundle.loadString('assets/catalog/animals.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final entries = json['animals'] as List<dynamic>;
    final animals = entries
        .map((entry) => Animal.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
    if (animals.length < 4) {
      throw const FormatException('Catalog requires at least 4 animals');
    }
    return animals;
  }
}
