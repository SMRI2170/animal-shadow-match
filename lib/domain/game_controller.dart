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
  final List<ShadowItem> _recentItems = [];
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
      _recentItems.add(round.target);
      if (_recentItems.length > _setSize) {
        _recentItems.removeAt(0);
      }
      _completedInSet += 1;
      _totalCompleted += 1;
      final completed = _completedInSet;
      final reachedEnd = completed >= _setSize;
      final next = reachedEnd
          ? _buildSetCompleted()
          : SolvedState(
              round: round,
              completedInSet: completed,
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
    final next = SolvingState(
      round: _freshRound(),
      completedInSet: _completedInSet,
      optionCount: _optionCount,
    );
    current = next;
    return next;
  }

  GameState onContinue() {
    // Begin the next set of questions.
    _completedInSet = 0;
    final next = SolvingState(
      round: _freshRound(),
      completedInSet: 0,
      optionCount: _optionCount,
    );
    current = next;
    return next;
  }

  /// Public for tests: lets the caller peek at "what was the last target?"
  /// without exposing mutable state.
  ShadowItem? get lastTarget => _lastTarget;
  int get completedInSet => _completedInSet;
  int get totalCompleted => _totalCompleted;
  List<ShadowItem> get recentItems => List.unmodifiable(_recentItems);

  ShadowRound _freshRound() {
    final previousIds = _recentItems.map((e) => e.id).toList();
    // After 80% of the catalog from one category has appeared, ban that
    // category for a round to keep silhouettes varied.
    final banned = <String>{};
    if (_recentItems.length >= 2 && catalog.length >= 6) {
      final byCategory = <String, int>{};
      for (final item in _recentItems) {
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
      recentItems: List.unmodifiable(_recentItems),
      totalCompletedToday: _totalCompleted,
    );
  }

  /// Last computed state. Held by the controller only between transitions;
  /// the UI is expected to drive transitions explicitly and re-render.
  GameState? current;
}
