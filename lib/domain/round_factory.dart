import 'dart:math';

import 'shadow_item.dart';

class ShadowRound {
  const ShadowRound({required this.target, required this.options});

  final ShadowItem target;
  final List<ShadowItem> options;

  bool isCorrect(String itemId) => target.id == itemId;
}

/// Generates rounds locally. The listed distractors are hand-curated, with a
/// catalog-wide fallback; the final options are shuffled on every round.
///
/// Works on the generic [ShadowItem] so animal/object/character catalogs all
/// use the same round logic. The legacy `Animal` type is now a subclass of
/// [ShadowItem], so this keeps working without changes for the demo data.
class RoundFactory {
  RoundFactory({Random? random}) : _random = random ?? Random();

  final Random _random;

  ShadowRound create({
    required List<ShadowItem> catalog,
    required int optionCount,
    String? previousTargetId,
    Set<String> excludedTargetIds = const {},
  }) {
    if (optionCount < 2 || catalog.length < optionCount) {
      throw ArgumentError(
        'RoundFactory needs at least $optionCount distinct items in the catalog',
      );
    }
    // Prefer an unseen target within this five-question set. When the
    // catalog is too small, gracefully fall back to a previously seen item.
    final unseen = catalog
        .where((item) =>
            item.id != previousTargetId &&
            !excludedTargetIds.contains(item.id))
        .toList();
    final eligible =
        catalog.where((item) => item.id != previousTargetId).toList();
    final targetPool =
        unseen.isNotEmpty ? unseen : (eligible.isNotEmpty ? eligible : catalog);
    final target = targetPool[_random.nextInt(targetPool.length)];
    final byId = {for (final item in catalog) item.id: item};

    final preferred = <ShadowItem>[];
    for (final id in target.distractorIds) {
      final item = byId[id];
      if (item != null && item.id != target.id) preferred.add(item);
    }
    preferred.shuffle(_random);
    final fallback = catalog
        .where((item) =>
            item.id != target.id &&
            !preferred.any((preferredAnimal) => preferredAnimal.id == item.id))
        .toList()
      ..shuffle(_random);

    final distractors = <ShadowItem>[];
    for (final candidate in [...preferred, ...fallback]) {
      if (distractors.any((item) => item.id == candidate.id)) continue;
      distractors.add(candidate);
      if (distractors.length == optionCount - 1) break;
    }
    final options = <ShadowItem>[target, ...distractors]..shuffle(_random);
    return ShadowRound(target: target, options: options);
  }
}
