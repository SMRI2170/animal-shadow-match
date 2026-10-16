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
///    (c) any other item regardless of category.
///
/// **Hard guarantees (Issue #3):**
/// * The catalog must contain `optionCount` items with unique ids; a
///   duplicate id raises [ArgumentError] before any round is produced.
/// * The factory must produce exactly `optionCount` options with unique
///   ids; if the catalog cannot supply them (after relaxing bans), a
///   [StateError] is raised. The factory never pads with the target id.
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
    if (optionCount < 2) {
      throw ArgumentError.value(
        optionCount,
        'optionCount',
        'must be at least 2 to form a meaningful question',
      );
    }
    if (catalog.length < optionCount) {
      throw ArgumentError(
        'RoundFactory needs at least $optionCount distinct items in the catalog (got ${catalog.length})',
      );
    }
    _assertCatalogIdsUnique(catalog);

    final alreadyUsed = <String>{
      if (previousTargetId != null) previousTargetId,
      ...previousTargetIds,
    };
    final byId = {for (final item in catalog) item.id: item};

    // 1. Pick the target. Try the banned-categories-respecting pool first;
    //    relax the ban if it leaves nothing eligible. We *always* honour
    //    `alreadyUsed` first; only the ban set is relaxed in the fallback
    //    so the distractor uniqueness invariant holds.
    final target = _pickTarget(
      catalog: catalog,
      alreadyUsed: alreadyUsed,
      bannedCategories: bannedCategories,
    );

    // Every item that shares `target.similarityGroup` is banned as a
    // distractor (Issue #89 follow-up). This is a hard contract: if the
    // catalog's same-group population makes it impossible to fill
    // `optionCount - 1` distinct distractors, [create] surfaces a
    // [StateError] rather than silently falling back to a confusing round.
    final similarityBanned = <String>{
      for (final item in catalog)
        if (item.similarityGroup != null &&
            item.similarityGroup == target.similarityGroup)
          item.id,
    };
    // The target id stays inside `similarityBanned` (its own group), but
    // the target id check below short-circuits before the ban applies, so
    // we don't need to special-case it.

    // 2. Pick (optionCount - 1) distractors in a strict priority order so
    //    the player always sees the target plus a full row of options.
    final distractors = <ShadowItem>[];
    void consider(ShadowItem candidate) {
      if (candidate.id == target.id) return;
      if (similarityBanned.contains(candidate.id)) return;
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

    // 2c. Any remaining item, ignoring the category preference but still
    //     respecting the uniqueness invariant. Without this, a small
    //     catalog with heavy bans could leave the round with only one
    //     option. We deliberately do NOT touch the banned set here:
    //     bans only affect target selection in step 1.
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

    if (distractors.length < optionCount - 1) {
      throw StateError(
        'RoundFactory could not fill $optionCount unique options '
        '(only ${distractors.length + 1} available after relaxing bans; '
        'catalog has ${catalog.length} items)',
      );
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
    // Fallback: ignore the ban set but still respect the recent-target
    // avoidance. This keeps a round playable even when the caller bans
    // every category the catalog has.
    final relaxed = catalog
        .where((item) => !alreadyUsed.contains(item.id))
        .toList();
    if (relaxed.isNotEmpty) {
      return relaxed[_random.nextInt(relaxed.length)];
    }
    // Every catalog id is on the alreadyUsed list. Returning a duplicate
    // would silently violate the uniqueness invariant the distractor
    // pipeline enforces, so surface a hard error instead and let the
    // caller (the GameController in our case) decide what to do.
    throw StateError(
      'RoundFactory could not pick a unique target: '
      'every catalog id (${catalog.length}) is on the alreadyUsed list.',
    );
  }

  /// Raises [ArgumentError] if the catalog contains two items with the
  /// same id. We don't try to deduplicate silently — duplicates indicate
  /// a real data bug that the caller (catalog loader) must fix.
  void _assertCatalogIdsUnique(List<ShadowItem> catalog) {
    final seen = <String>{};
    for (final item in catalog) {
      if (!seen.add(item.id)) {
        throw ArgumentError(
          'RoundFactory catalog contains duplicate id: ${item.id}',
        );
      }
    }
  }
}
