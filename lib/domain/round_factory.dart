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
/// Recent-target avoidance and category diversity are knobs that callers
/// can pass through `previousTargetIds` / `bannedCategories` to keep
/// multi-round sessions from getting boring (v6 §4).
class RoundFactory {
  RoundFactory({Random? random}) : _random = random ?? Random();

  final Random _random;

  ShadowRound create({
    required List<ShadowItem> catalog,
    required int optionCount,
    String? previousTargetId,
    List<String> previousTargetIds = const <String>[],
    Set<String> bannedCategories = const <String>{},
  }) {
    if (optionCount < 2 || catalog.length < optionCount) {
      throw ArgumentError(
        'RoundFactory needs at least $optionCount distinct items in the catalog',
      );
    }
    final alreadyUsed = <String>{
      if (previousTargetId != null) previousTargetId,
      ...previousTargetIds,
    };
    final eligible = catalog
        .where((item) =>
            !alreadyUsed.contains(item.id) &&
            !bannedCategories.contains(item.category))
        .toList();
    final targetPool = eligible.isNotEmpty ? eligible : catalog;
    final target = targetPool[_random.nextInt(targetPool.length)];
    final byId = {for (final item in catalog) item.id: item};

    final preferred = <ShadowItem>[];
    for (final id in target.distractorIds) {
      final item = byId[id];
      if (item != null &&
          item.id != target.id &&
          !bannedCategories.contains(item.category)) {
        preferred.add(item);
      }
    }
    preferred.shuffle(_random);
    final fallback = catalog
        .where((item) =>
            item.id != target.id &&
            !bannedCategories.contains(item.category) &&
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
