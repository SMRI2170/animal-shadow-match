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
///
/// **Diversity fallback.** When a small catalog makes it impossible to
/// honour all of `bannedCategories` (e.g. six items split across three
/// categories and the caller bans two of them, leaving only two items
/// per round), this factory falls back in two stages:
/// 1. The target is still drawn from a different category if at all
///    possible, but the banned set is ignored if no item is left.
/// 2. Distractors are filled with (a) the hand-curated distractor list,
///    then (b) items from a *different* category than the target, then
///    (c) any other item regardless of category, and only as a last
///    resort (d) duplicate the target so the option count is preserved.
///
/// Without this fallback, ban-heavy settings could collapse a round down
/// to a single option and force the player to pick the only available
/// tile (v6 spec §4 / Issue #30 review).
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
    final byId = {for (final item in catalog) item.id: item};

    // 1. Pick the target. Try the banned-categories-respecting pool first;
    //    relax the ban if it leaves nothing eligible.
    final target = _pickTarget(
      catalog: catalog,
      alreadyUsed: alreadyUsed,
      bannedCategories: bannedCategories,
    );

    // 2. Pick (optionCount - 1) distractors in a strict priority order so
    //    the player always sees the target plus a full row of options.
    final distractors = <ShadowItem>[];
    void consider(ShadowItem candidate) {
      if (candidate.id == target.id) return;
      if (distractors.any((d) => d.id == candidate.id)) return;
      distractors.add(candidate);
    }

    // 2a. Hand-curated distractor ids from the target item itself.
    for (final id in target.distractorIds) {
      if (distractors.length >= optionCount - 1) break;
      final item = byId[id];
      if (item != null) consider(item);
    }

    // 2b. Items from a *different* category than the target. This is the
    //     primary "the wrong answers should look different" heuristic.
    if (distractors.length < optionCount - 1) {
      final differentCategory = catalog
          .where((item) =>
              item.id != target.id &&
              item.category != target.category &&
              !distractors.any((d) => d.id == item.id))
          .toList()
        ..shuffle(_random);
      for (final item in differentCategory) {
        if (distractors.length >= optionCount - 1) break;
        consider(item);
      }
    }

    // 2c. Any remaining item, ignoring both the ban set and the
    //     different-category preference. Without this, a small catalog
    //     with heavy bans can leave the round with only one option.
    if (distractors.length < optionCount - 1) {
      final anyOther = catalog
          .where((item) =>
              item.id != target.id &&
              !distractors.any((d) => d.id == item.id))
          .toList()
        ..shuffle(_random);
      for (final item in anyOther) {
        if (distractors.length >= optionCount - 1) break;
        consider(item);
      }
    }

    // 2d. Defensive: if the catalog is somehow smaller than optionCount
    //     (the constructor guard should have caught this), pad with the
    //     target itself so the row is at least visually full.
    while (distractors.length < optionCount - 1) {
      distractors.add(target);
    }

    final options = <ShadowItem>[target, ...distractors]..shuffle(_random);
    return ShadowRound(target: target, options: options);
  }

  ShadowItem _pickTarget({
    required List<ShadowItem> catalog,
    required Set<String> alreadyUsed,
    required Set<String> bannedCategories,
  }) {
    final respecting = catalog
        .where((item) =>
            !alreadyUsed.contains(item.id) &&
            !bannedCategories.contains(item.category))
        .toList();
    if (respecting.isNotEmpty) {
      return respecting[_random.nextInt(respecting.length)];
    }
    // Fallback: ignore the ban set (still respect the recent-target
    // avoidance). This keeps a round playable even when the caller bans
    // every category the catalog has.
    final relaxed = catalog
        .where((item) => !alreadyUsed.contains(item.id))
        .toList();
    if (relaxed.isNotEmpty) {
      return relaxed[_random.nextInt(relaxed.length)];
    }
    // All items were recently used. The only legal choice is to repeat one
    // of them; pick the first so the round stays valid.
    return catalog.first;
  }
}
