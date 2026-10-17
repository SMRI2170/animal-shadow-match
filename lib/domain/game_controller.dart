import '../data/game_progress_store.dart';
import 'game_progress_phase.dart';
import 'game_state.dart';
import 'round_factory.dart';
import 'shadow_item.dart';

/// Pure state-machine transformer. Drives the play session without touching
/// image bytes or storing any mutable reference. Callers feed it events via
/// [onChoice] / [onEffectFinished] / [onContinue] / [onRest] / [onResume] and
/// read [current] for the next [GameState].
///
/// Issue #22 strict resume: in addition to the event-driven transitions,
/// the controller exposes [snapshot] and [restoreFrom] so an app restart
/// can put the player back on the exact round they left off on — same
/// target, same option ordering, same progress counters.
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
  // out of distractors on the second set's 5th question.
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

  /// Order the saved option list so the target id appears at index 0.
  /// [ShadowRound.options] is the post-shuffle order returned by
  /// [RoundFactory.create], so it may not start with the target. The
  /// Issue #22 strict-resume contract guarantees the saved list's head
  /// is always the target so the controller can rebuild the round with
  /// `_reconstructRound` and still surface the correct answer.
  static List<String> _orderedOptionIds(ShadowRound round) {
    final targetId = round.target.id;
    return <String>[
      targetId,
      ...round.options
          .map((o) => o.id)
          .where((id) => id != targetId),
    ];
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
    // has to avoid it.
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

  /// Switch from [SetCompletedState] to [RestingState].
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

  /// Return from [RestingState] to [SetCompletedState].
  GameState onResume() {
    final state = current;
    if (state is! RestingState) {
      throw StateError('expected RestingState, got $state');
    }
    final next = _buildSetCompleted();
    current = next;
    return next;
  }

  /// Build a [GameProgress] snapshot covering every piece of state the
  /// UI cares about (Issue #22 strict resume). Callers persist the
  /// result via [GameProgressStore]; the next cold start passes it to
  /// [restoreFrom] to land the player exactly where they left off.
  GameProgress snapshot() {
    final state = current;
    if (state == null) return GameProgress.empty;
    final lastRecentItemIds =
        _usedInSet.map((e) => e.id).toList(growable: false);
    final now = DateTime.now();
    final currentSetIndex = _totalCompleted ~/ _setSize;
    if (state is SolvingState) {
      return GameProgress(
        totalCompleted: _totalCompleted,
        lastRecentItemIds: lastRecentItemIds,
        lastPlayedAt: now,
        currentSetIndex: currentSetIndex,
        phase: SessionPhase.solving,
        roundIndex: state.completedInSet,
        currentRoundOptionIds:
            _orderedOptionIds(state.round).toList(growable: false),
        wrongChoiceId: state.wrongChoiceId,
      );
    }
    if (state is SolvedState) {
      return GameProgress(
        totalCompleted: _totalCompleted,
        lastRecentItemIds: lastRecentItemIds,
        lastPlayedAt: now,
        currentSetIndex: currentSetIndex,
        phase: SessionPhase.solved,
        // completedInSet counts answered rounds; the FX is playing on
        // the just-answered round, so its 0-based index is one less.
        roundIndex: state.completedInSet - 1,
        currentRoundOptionIds:
            _orderedOptionIds(state.round).toList(growable: false),
      );
    }
    if (state is SetCompletedState) {
      return GameProgress(
        totalCompleted: _totalCompleted,
        lastRecentItemIds:
            state.recentItems.map((e) => e.id).toList(growable: false),
        lastPlayedAt: now,
        currentSetIndex: currentSetIndex,
        phase: SessionPhase.setCompleted,
        roundIndex: _setSize,
        currentRoundOptionIds: const <String>[],
      );
    }
    if (state is RestingState) {
      return GameProgress(
        totalCompleted: _totalCompleted,
        lastRecentItemIds:
            state.recentItems.map((e) => e.id).toList(growable: false),
        lastPlayedAt: now,
        currentSetIndex: currentSetIndex,
        phase: SessionPhase.resting,
        roundIndex: _setSize,
        currentRoundOptionIds: const <String>[],
      );
    }
    // LoadingCatalogState / CatalogEmptyState: snapshot nothing
    // interesting; the loader will simply rehydrate on the next launch.
    return GameProgress.empty;
  }

  /// Soft resume (legacy, kept as a thin wrapper around [restoreFrom]).
  /// Callers should persist a full [GameProgress] and use [restoreFrom]
  /// for the strict-resume semantics required by Issue #22.
  @Deprecated('Use restoreFrom(GameProgress) for issue #22 strict resume.')
  void resumeFromTotalCompleted(int totalCompleted) {
    final snapshot = GameProgress(
      totalCompleted: totalCompleted,
      lastRecentItemIds: const <String>[],
      lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(0),
      currentSetIndex: totalCompleted,
      phase: SessionPhase.solving,
      roundIndex: 0,
      currentRoundOptionIds: const <String>[],
    );
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
    // suppress unused warning for snapshot on this legacy path
    snapshot.totalCompleted;
  }

  /// Restore the controller from a previously persisted [GameProgress]
  /// snapshot. The rebuild covers progress counters, the in-set history,
  /// and the exact round the player was on (Issue #22 strict resume).
  ///
  /// Throws [StateError] if the snapshot references ids that are no
  /// longer in the catalogue, e.g. because a [RoundFactory]'s
  /// distractorIds set was edited between sessions.
  void restoreFrom(GameProgress saved) {
    _totalCompleted = saved.totalCompleted;
    _completedInSet = 0;
    _lastTarget = null;
    _lastTargetAcrossSets = null;
    _usedInSet.clear();
    for (final id in saved.lastRecentItemIds) {
      final item = _lookupItem(id);
      if (item != null) _usedInSet.add(item);
    }
    switch (saved.phase) {
      case SessionPhase.solving:
        _completedInSet = saved.roundIndex;
        final round = _reconstructRound(saved.currentRoundOptionIds);
        // For Solving at roundIndex 0 the player has just begun a set,
        // so there is no across-sets last target to avoid.
        if (_usedInSet.isNotEmpty && saved.roundIndex > 0) {
          _lastTargetAcrossSets = _usedInSet.last;
        } else {
          _lastTargetAcrossSets = null;
        }
        current = SolvingState(
          round: round,
          completedInSet: _completedInSet,
          optionCount: _optionCount,
          wrongChoiceId: saved.wrongChoiceId,
        );
      case SessionPhase.solved:
        _completedInSet = saved.roundIndex + 1;
        final round = _reconstructRound(saved.currentRoundOptionIds);
        _lastTarget = round.target;
        _lastTargetAcrossSets = round.target;
        _usedInSet.add(round.target);
        if (_usedInSet.length > _setSize) {
          _usedInSet.removeAt(0);
        }
        current = SolvedState(
          round: round,
          completedInSet: _completedInSet,
          optionCount: _optionCount,
        );
      case SessionPhase.setCompleted:
        _completedInSet = _setSize;
        if (_usedInSet.isNotEmpty) {
          _lastTargetAcrossSets = _usedInSet.last;
        }
        current = SetCompletedState(
          recentItems: List.unmodifiable(_usedInSet),
          totalCompletedToday: _totalCompleted,
        );
      case SessionPhase.resting:
        _completedInSet = _setSize;
        if (_usedInSet.isNotEmpty) {
          _lastTargetAcrossSets = _usedInSet.last;
        }
        current = RestingState(
          recentItems: List.unmodifiable(_usedInSet),
          totalCompletedToday: _totalCompleted,
        );
    }
  }

  /// Public for tests: lets the caller peek at "what was the last target?"
  /// without exposing mutable state.
  ShadowItem? get lastTarget => _lastTarget;
  ShadowItem? get lastTargetAcrossSets => _lastTargetAcrossSets;
  int get completedInSet => _completedInSet;
  int get totalCompleted => _totalCompleted;
  /// In-set history: cleared on `onContinue`, capped at `_setSize`.
  List<ShadowItem> get recentItems => List.unmodifiable(_usedInSet);

  ShadowRound _freshRound() {
    final previousIds = _usedInSet.map((e) => e.id).toList();
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

  /// Look up a [ShadowItem] in the catalogue by id. Returns null when
  /// the id is unknown so callers can decide whether the absence is
  /// fatal (resume) or harmless (in-set history).
  ShadowItem? _lookupItem(String id) {
    for (final item in catalog) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Reconstruct a [ShadowRound] from the saved option ordering.
  /// The first id is the target; the rest are distractors in the same
  /// order the UI was showing when the snapshot was written.
  ShadowRound _reconstructRound(List<String> optionIds) {
    if (optionIds.isEmpty) {
      throw StateError(
          'cannot reconstruct round: currentRoundOptionIds is empty');
    }
    final items = <ShadowItem>[];
    for (final id in optionIds) {
      final item = _lookupItem(id);
      if (item == null) {
        throw StateError(
          'cannot reconstruct round: "$id" is no longer in the catalogue. '
          'Reset the session with restartFromTotalCompleted(0) or update the '
          'saved snapshot to match the new catalogue.',
        );
      }
      items.add(item);
    }
    return ShadowRound(target: items.first, options: items);
  }

  /// Last computed state. Held by the controller only between transitions;
  /// the UI is expected to drive transitions explicitly and re-render.
  GameState? current;
}
