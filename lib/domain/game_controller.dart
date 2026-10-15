import 'shadow_item.dart';
import 'game_state.dart';
import 'round_factory.dart';

/// Pure state-machine transformer. Drives the play session without touching
/// image bytes or storing any mutable reference. Callers feed it events via
/// the [Event] classes and get the next [GameState] back.
///
/// The controller is intentionally image-free so every transition can be
/// Unit-tested without an [AssetBundle].
class GameController {
  GameController({
    required this.catalog,
    required this.factory,
    int setSize = 5,
  })  : assert(setSize >= 2),
        _setSize = setSize;

  final List<ShadowItem> catalog;
  final RoundFactory factory;
  final int _setSize;

  ShadowItem? _lastTarget;
  // Targets used *within the current set* (Issue #20 acceptance reset).
  // Cleared on onContinue so the new set's first round can pick from
  // the entire catalog.
  final List<ShadowItem> _usedInSet = [];
  // Targets we must avoid across set boundaries. We only need the
  // single most-recent target so a tiny 5-item catalog does not run
  // out of distractors on the second set's 5th question (Issue #20
  // mini-followup: "5 items, 3 sets, 15 questions" regression test).
  ShadowItem? _lastTargetAcrossSets;
  int _completedInSet = 0;
  int _totalCompleted = 0;

  GameState start() {
    final state = SolvingState(
      round: _freshRound(),
      completedInSet: _completedInSet,
      optionCount: _optionCount,
    );
    current = state;
    return state;
  }

  GameState onChoice(String chosenId) {
    final solving = _expectSolving();
    final round = solving.round;
    if (round.isCorrect(chosenId)) {
      _lastTarget = round.target;
      _lastTargetAcrossSets = round.target;
      _usedInSet.add(round.target);
      if (_usedInSet.length > _setSize) {
        _usedInSet.removeAt(0);
      }
      _completedInSet += 1;
      _totalCompleted += 1;
      // Always return SolvedState so the round's FX plays, even on the
      // final answer. SetCompletedState is reached via onEffectFinished
      // below, which keeps the v6 spec's "every correct answer plays the
      // FX" promise (Issue #86 review).
      final next = SolvedState(
        round: round,
        completedInSet: _completedInSet,
        optionCount: _optionCount,
      );
      current = next;
      return next;
    }
    final next = solving.copyWith(wrongChoiceId: chosenId);
    current = next;
    return next;
  }

  GameState onEffectFinished() {
    _expectSolved();
    final reachedEnd = _completedInSet >= _setSize;
    final next = reachedEnd
        ? _buildSetCompleted()
        : SolvingState(
            round: _freshRound(),
            completedInSet: _completedInSet,
            optionCount: _optionCount,
          );
    current = next;
    return next;
  }

  GameState onContinue() {
    // Begin the next set of questions.
    //
    // Issue #20 follow-up: the in-set history resets so the new set
    // can pick from the entire catalog. The single most-recent target
    // is *not* part of the in-set history; it is kept in
    // _lastTargetAcrossSets and passed to _freshRound via the
    // `previousTargetId` argument so only the new set's first round
    // has to avoid it. This keeps a 5-item catalog playable for
    // multiple sets in a row.
    _completedInSet = 0;
    _usedInSet.clear();
    final next = SolvingState(
      round: _freshRound(),
      completedInSet: 0,
      optionCount: _optionCount,
    );
    current = next;
    return next;
  }

  /// Switch from [SetCompletedState] to [RestingState]. Progress counters
  /// are preserved; the child can resume to the same review area without
  /// losing track of which set they just finished.
  GameState onRest() {
    final state = current;
    if (state is! SetCompletedState) {
      throw StateError('expected SetCompletedState, got $state');
    }
    final next = RestingState(
      recentItems: List.unmodifiable(_usedInSet),
      totalCompletedToday: _totalCompleted,
    );
    current = next;
    return next;
  }

  /// Return from [RestingState] to [SetCompletedState] without touching
  /// progress. The review area re-renders with the same items so the
  /// child can decide between Continue and another rest.
  GameState onResume() {
    final state = current;
    if (state is! RestingState) {
      throw StateError('expected RestingState, got $state');
    }
    final next = _buildSetCompleted();
    current = next;
    return next;
  }

  /// Restore the controller from a persisted `totalCompleted` counter
  /// (Issue #22 resume / #25 review). The current [GameState] is left in
  /// [current] as a fresh [SolvingState] so the child sees new options
  /// instead of replaying the round that was interrupted.
  ///
  /// Accepting an `int` rather than a `GameProgress` keeps the domain
  /// layer free of persistence concerns; callers translate the persisted
  /// record into the counter and pass it in.
  void resumeFromTotalCompleted(int totalCompleted) {
    _totalCompleted = totalCompleted;
    _completedInSet = 0;
    _lastTarget = null;
    _lastTargetAcrossSets = null;
    _usedInSet.clear();
    current = SolvingState(
      round: _freshRound(),
      completedInSet: 0,
      optionCount: _optionCount,
    );
  }

  /// Public for tests: lets the caller peek at "what was the last target?"
  /// without exposing mutable state.
  ShadowItem? get lastTarget => _lastTarget;
  ShadowItem? get lastTargetAcrossSets => _lastTargetAcrossSets;
  int get completedInSet => _completedInSet;
  int get totalCompleted => _totalCompleted;
  /// In-set history: cleared on `onContinue`, capped at `_setSize`.
  /// Use this to inspect "what did the child just play through this set?"
  List<ShadowItem> get recentItems => List.unmodifiable(_usedInSet);

  ShadowRound _freshRound() {
    // In-set history feeds the in-set `previousTargetIds` so the next
    // round within the same set avoids repeats. The single
    // across-sets target is passed via `previousTargetId` so only the
    // first round of a new set has to dodge it.
    final previousIds = _usedInSet.map((e) => e.id).toList();
    // After 80% of the catalog from one category has appeared, ban that
    // category for a round to keep silhouettes varied.
    final banned = <String>{};
    if (_usedInSet.length >= 2 && catalog.length >= 6) {
      final byCategory = <String, int>{};
      for (final item in _usedInSet) {
        byCategory[item.category] = (byCategory[item.category] ?? 0) + 1;
      }
      final top = byCategory.entries
          .where((e) => e.value >= 2)
          .map((e) => e.key);
      banned.addAll(top);
    }
    return factory.create(
      catalog: catalog,
      optionCount: _optionCount,
      previousTargetId: _lastTargetAcrossSets?.id,
      previousTargetIds: previousIds,
      bannedCategories: banned,
    );
  }

  /// Option count climbs gradually: 2 for the first set, 3 the next ten,
  /// 4 thereafter (preserves the existing v2 escalation).
  int get _optionCount =>
      _totalCompleted < 5 ? 2 : (_totalCompleted < 15 ? 3 : 4);

  SolvingState _expectSolving() {
    final state = current;
    if (state is! SolvingState) {
      throw StateError('expected SolvingState, got $state');
    }
    return state;
  }

  SolvedState _expectSolved() {
    final state = current;
    if (state is! SolvedState) {
      throw StateError('expected SolvedState, got $state');
    }
    return state;
  }

  SetCompletedState _buildSetCompleted() {
    return SetCompletedState(
      recentItems: List.unmodifiable(_usedInSet),
      totalCompletedToday: _totalCompleted,
    );
  }

  /// Last computed state. Held by the controller only between transitions;
  /// the UI is expected to drive transitions explicitly and re-render.
  GameState? current;
}
