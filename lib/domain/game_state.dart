import 'round_factory.dart';
import 'shadow_item.dart';

/// State machine for a single play session (one set of up to 5 questions).
///
/// Sealed so the UI can exhaustively switch on the type. Image-free; the
/// only payload is [ShadowItem] metadata and counters.
sealed class GameState {
  const GameState();
}

class LoadingCatalogState extends GameState {
  const LoadingCatalogState();
}

class CatalogEmptyState extends GameState {
  const CatalogEmptyState(this.reason);
  final String reason;
}

class SolvingState extends GameState {
  const SolvingState({
    required this.round,
    required this.completedInSet,
    required this.optionCount,
    this.wrongChoiceId,
  });

  final ShadowRound round;
  final int completedInSet;
  final int optionCount;
  final String? wrongChoiceId;

  SolvingState copyWith({
    ShadowRound? round,
    int? completedInSet,
    int? optionCount,
    Object? wrongChoiceId = _sentinel,
  }) {
    return SolvingState(
      round: round ?? this.round,
      completedInSet: completedInSet ?? this.completedInSet,
      optionCount: optionCount ?? this.optionCount,
      wrongChoiceId: identical(wrongChoiceId, _sentinel)
          ? this.wrongChoiceId
          : wrongChoiceId as String?,
    );
  }
}

class SolvedState extends GameState {
  const SolvedState({
    required this.round,
    required this.completedInSet,
    required this.optionCount,
  });

  final ShadowRound round;
  final int completedInSet;
  final int optionCount;
}

class SetCompletedState extends GameState {
  const SetCompletedState({
    required this.recentItems,
    required this.totalCompletedToday,
  });

  /// The five [ShadowItem]s the child just finished with — used by the
  /// Review play area (#25). Always 5 entries when reached from [Solving];
  /// older sets may be shorter if persistence wasn't implemented yet.
  final List<ShadowItem> recentItems;
  final int totalCompletedToday;
}

/// Internal sentinel used by [SolvingState.copyWith] to distinguish "leave
/// unchanged" from "set to null".
const Object _sentinel = Object();
