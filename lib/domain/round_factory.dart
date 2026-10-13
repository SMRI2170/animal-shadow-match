import 'dart:math';

import 'animal.dart';

class ShadowRound {
  const ShadowRound({required this.target, required this.options});

  final Animal target;
  final List<Animal> options;

  bool isCorrect(String animalId) => target.id == animalId;
}

/// Generates rounds locally. The listed distractors are hand-curated, with a
/// catalog-wide fallback; the final options are shuffled on every round.
class RoundFactory {
  RoundFactory({Random? random}) : _random = random ?? Random();

  final Random _random;

  ShadowRound create({
    required List<Animal> catalog,
    required int optionCount,
    String? previousTargetId,
  }) {
    if (optionCount < 2 || catalog.length < optionCount) {
      throw ArgumentError('Not enough animals for $optionCount options');
    }
    final eligible = catalog
        .where((animal) => animal.id != previousTargetId)
        .toList();
    final targetPool = eligible.isNotEmpty ? eligible : catalog;
    final target = targetPool[_random.nextInt(targetPool.length)];
    final byId = {for (final animal in catalog) animal.id: animal};

    final preferred = <Animal>[];
    for (final id in target.distractorIds) {
      final animal = byId[id];
      if (animal != null && animal.id != target.id) preferred.add(animal);
    }
    preferred.shuffle(_random);
    final fallback = catalog
        .where((animal) =>
            animal.id != target.id &&
            !preferred.any((preferredAnimal) => preferredAnimal.id == animal.id))
        .toList()
      ..shuffle(_random);

    final distractors = <Animal>[];
    for (final candidate in [...preferred, ...fallback]) {
      if (distractors.any((animal) => animal.id == candidate.id)) continue;
      distractors.add(candidate);
      if (distractors.length == optionCount - 1) break;
    }
    final options = <Animal>[target, ...distractors]..shuffle(_random);
    return ShadowRound(target: target, options: options);
  }
}
