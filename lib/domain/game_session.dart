import 'dart:math' as math;

import 'round_factory.dart';
import 'shadow_item.dart';

/// The complete offline five-question loop.
///
/// The UI only animates the current state. It never decides which answer is
/// correct, when a set is complete, or whether a double tap should count.
enum GamePhase { matching, playground, resting }

class GameSession {
  GameSession({
    required this.catalog,
    RoundFactory? roundFactory,
    this.roundsPerSet = 5,
  })  : assert(catalog.length >= 2),
        assert(roundsPerSet > 0),
        _factory = roundFactory ?? RoundFactory() {
    _startNextRound();
  }

  final List<ShadowItem> catalog;
  final RoundFactory _factory;
  final int roundsPerSet;

  late ShadowRound _round;
  ShadowRound get round => _round;

  GamePhase _phase = GamePhase.matching;
  GamePhase get phase => _phase;

  int _totalCompleted = 0;
  int get totalCompleted => _totalCompleted;

  final List<ShadowItem> _setItems = [];
  List<ShadowItem> get setItems => List.unmodifiable(_setItems);

  bool _awaitingReaction = false;
  bool get awaitingReaction => _awaitingReaction;

  String? _previousTargetId;

  /// 2 choices at first, 3 after five answers, 4 after fifteen answers.
  /// A small catalog never causes an impossible choice count.
  int get optionCount =>
      math.min(catalog.length, _totalCompleted < 5 ? 2 : (_totalCompleted < 15 ? 3 : 4));

  /// Returns true only for a new correct choice. Wrong answers and rapid
  /// repeats leave the current round unchanged.
  bool choose(String itemId) {
    if (_phase != GamePhase.matching || _awaitingReaction) return false;
    if (!_round.isCorrect(itemId)) return false;
    _awaitingReaction = true;
    return true;
  }

  /// Called when the animation completes (or a single safety timeout fires).
  /// Calling twice is safe and never awards two points.
  void finishReaction() {
    if (_phase != GamePhase.matching || !_awaitingReaction) return;
    _awaitingReaction = false;
    _setItems.add(_round.target);
    _totalCompleted += 1;
    _previousTargetId = _round.target.id;

    if (_setItems.length >= roundsPerSet) {
      _phase = GamePhase.playground;
    } else {
      _startNextRound();
    }
  }

  void continuePlaying() {
    if (_phase != GamePhase.playground) return;
    _setItems.clear();
    _phase = GamePhase.matching;
    _startNextRound();
  }

  void takeBreak() {
    if (_phase == GamePhase.playground) _phase = GamePhase.resting;
  }

  void resume() {
    if (_phase == GamePhase.resting) _phase = GamePhase.playground;
  }

  void _startNextRound() {
    _round = _factory.create(
      catalog: catalog,
      optionCount: optionCount,
      previousTargetId: _previousTargetId,
      excludedTargetIds: _setItems.map((item) => item.id).toSet(),
    );
  }
}
