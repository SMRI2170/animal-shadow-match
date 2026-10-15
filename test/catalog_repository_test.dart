import 'dart:convert';

import 'package:animal_shadow_match/data/catalog_repository.dart';
import 'package:animal_shadow_match/domain/animal.dart';
import 'package:animal_shadow_match/domain/shadow_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isValidItemId accepts canonical ids and rejects unsafe ones', () {
    expect(isValidItemId('gel_star'), isTrue);
    expect(isValidItemId('toy_001'), isTrue);
    expect(isValidItemId('Cloud-Star'), isFalse);
    expect(isValidItemId(''), isFalse);
    expect(isValidItemId('../escape'), isFalse);
  });

  test('Animal stays a ShadowItem with the legacy name carried as label', () {
    final animal = Animal(
      id: 'giraffe',
      name: 'Giraffe',
      imagePath: 'assets/animals/giraffe.webp',
      shadowPath: 'assets/animals/giraffe_shadow.webp',
      category: 'savanna',
      distractorIds: const ['elephant'],
    );
    final ShadowItem asShadow = animal;
    expect(asShadow.id, 'giraffe');
    expect(asShadow.effectPreset.name, 'squish');
    expect(animal.name, 'Giraffe');
  });

  test('animalToShadowItem round-trips legacy JSON shape', () {
    final raw = {
      'id': 'rabbit',
      'name': 'Rabbit',
      'image': 'assets/animals/rabbit.webp',
      'shadow': 'assets/animals/rabbit_shadow.webp',
      'category': 'farm',
      'distractors': ['cat', 'duck'],
    };
    final item = animalToShadowItem(jsonDecode(jsonEncode(raw)) as Map<String, dynamic>);
    expect(item, isA<Animal>());
    expect(item.id, 'rabbit');
    expect(item.imagePath, 'assets/animals/rabbit.webp');
    expect(item.distractorIds, ['cat', 'duck']);
  });
}
