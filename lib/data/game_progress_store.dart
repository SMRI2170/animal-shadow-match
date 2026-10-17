import 'package:shared_preferences/shared_preferences.dart';

import '../domain/game_progress_phase.dart';

/// Internal sentinel used by [GameProgress.copyWith] to distinguish
/// "leave unchanged" from "set to null" for [wrongChoiceId].
const Object _sentinel = Object();

/// Persisted progress that survives app restarts.
///
/// Captures the counters needed for legacy resume (#22 soft) *and*
/// the full snapshot needed for Issue #22 strict resume: the current
/// phase (solving / solved / setCompleted / resting), which round
/// the player was on, and the exact option ordering of that round
/// so the same image and the same wrong-answer layout reappear after
/// a cold restart.
class GameProgress {
  const GameProgress({
    required this.totalCompleted,
    required this.lastRecentItemIds,
    required this.lastPlayedAt,
    required this.currentSetIndex,
    this.phase = SessionPhase.solving,
    this.roundIndex = 0,
    this.currentRoundOptionIds = const <String>[],
    this.currentRoundTargetId,
    this.wrongChoiceId,
  });

  /// Successful matches across the app lifetime. Bounded conceptually but
  /// stored as an int for flexibility.
  final int totalCompleted;

  /// Up to five target ids the child just played with. Used to populate
  /// the review play area when the child returns, and to rebuild the
  /// `_usedInSet` history on resume.
  final List<String> lastRecentItemIds;

  /// Last time the child reached a Solved / SetCompleted state.
  final DateTime lastPlayedAt;

  /// 0-based index of the active set. Resets to 0 after a SetCompleted
  /// continues into a new set.
  final int currentSetIndex;

  /// Where the player was when the snapshot was written. See
  /// [SessionPhase] for the meaning of each value.
  final SessionPhase phase;

  /// Index of the round in the current set that the player was looking
  /// at when the snapshot was written. 0..4 for a Solving/Solved round;
  /// 5 for SetCompleted/Resting.
  final int roundIndex;

  /// Exact ordering of the option tiles as they were laid out in the
  /// UI when the snapshot was written. The list preserves the visual
  /// order, which is *not* required to put the target first -- the
  /// target id is stored in [currentRoundTargetId]. Empty for
  /// SetCompleted / Resting.
  final List<String> currentRoundOptionIds;

  /// Id of the target the child was looking for in the active round.
  /// Stored separately from [currentRoundOptionIds] so the option
  /// layout stays faithful to what the UI rendered, even if the
  /// shuffle happened to place the target mid-list.
  final String? currentRoundTargetId;

  /// Id of the wrong option the child just tapped (only relevant for
  /// [SessionPhase.solving] snapshots), so the wrong-tile highlight
  /// reappears on cold start.
  final String? wrongChoiceId;

  static final empty = GameProgress(
    totalCompleted: 0,
    lastRecentItemIds: const <String>[],
    lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(0),
    currentSetIndex: 0,
  );

  Map<String, dynamic> toJson() => {
        'totalCompleted': totalCompleted,
        'lastRecentItemIds': lastRecentItemIds,
        'lastPlayedAt': lastPlayedAt.toIso8601String(),
        'currentSetIndex': currentSetIndex,
        'phase': phase.name,
        'roundIndex': roundIndex,
        'currentRoundOptionIds': currentRoundOptionIds,
        'currentRoundTargetId': currentRoundTargetId,
        'wrongChoiceId': wrongChoiceId,
      };

  factory GameProgress.fromJson(Map<String, dynamic> json) {
    return GameProgress(
      totalCompleted: (json['totalCompleted'] as int?) ?? 0,
      lastRecentItemIds: json['lastRecentItemIds'] is List
          ? List<String>.from(
              (json['lastRecentItemIds'] as List<dynamic>)
                  .map((e) => e.toString()),
            )
          : const <String>[],
      lastPlayedAt: DateTime.tryParse(json['lastPlayedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      currentSetIndex: (json['currentSetIndex'] as int?) ?? 0,
      phase: _phaseFromName(json['phase'] as String?) ?? SessionPhase.solving,
      roundIndex: (json['roundIndex'] as int?) ?? 0,
      currentRoundOptionIds: json['currentRoundOptionIds'] is List
          ? List<String>.from(
              (json['currentRoundOptionIds'] as List<dynamic>)
                  .map((e) => e.toString()),
            )
          : const <String>[],
      currentRoundTargetId: json['currentRoundTargetId'] as String?,
      wrongChoiceId: json['wrongChoiceId'] as String?,
    );
  }

  GameProgress copyWith({
    int? totalCompleted,
    List<String>? lastRecentItemIds,
    DateTime? lastPlayedAt,
    int? currentSetIndex,
    SessionPhase? phase,
    int? roundIndex,
    List<String>? currentRoundOptionIds,
    Object? currentRoundTargetId = _sentinel,
    Object? wrongChoiceId = _sentinel,
  }) {
    return GameProgress(
      totalCompleted: totalCompleted ?? this.totalCompleted,
      lastRecentItemIds:
          lastRecentItemIds ?? this.lastRecentItemIds,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      currentSetIndex: currentSetIndex ?? this.currentSetIndex,
      phase: phase ?? this.phase,
      roundIndex: roundIndex ?? this.roundIndex,
      currentRoundOptionIds:
          currentRoundOptionIds ?? this.currentRoundOptionIds,
      currentRoundTargetId: identical(currentRoundTargetId, _sentinel)
          ? this.currentRoundTargetId
          : currentRoundTargetId as String?,
      wrongChoiceId: identical(wrongChoiceId, _sentinel)
          ? this.wrongChoiceId
          : wrongChoiceId as String?,
    );
  }

  static SessionPhase? _phaseFromName(String? name) {
    if (name == null) return null;
    for (final phase in SessionPhase.values) {
      if (phase.name == name) return phase;
    }
    return null;
  }
}

/// Storage abstraction. The production implementation writes via
/// [SharedPreferences]; widget tests inject an [InMemoryGameProgressStore]
/// to keep `SharedPreferences.setMockInitialValues({})` out of every call
/// site.
abstract class GameProgressStore {
  Future<GameProgress?> load();
  Future<void> save(GameProgress progress);
  Future<void> clear();
}

class SharedPreferencesGameProgressStore implements GameProgressStore {
  const SharedPreferencesGameProgressStore({this.namespace = 'progress_v1'});

  final String namespace;

  static const _totalCompletedKey = 'totalCompleted';
  static const _lastRecentKey = 'lastRecentItemIds';
  static const _lastPlayedAtKey = 'lastPlayedAt';
  static const _currentSetIndexKey = 'currentSetIndex';
  static const _phaseKey = 'phase';
  static const _roundIndexKey = 'roundIndex';
  static const _roundOptionsKey = 'currentRoundOptionIds';
  static const _roundTargetKey = 'currentRoundTargetId';
  static const _wrongChoiceIdKey = 'wrongChoiceId';

  @override
  Future<GameProgress?> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_totalCompletedKey)) {
      return null;
    }
    final phaseName = prefs.getString(_phaseKey);
    final phase = _phaseFromName(phaseName) ?? SessionPhase.solving;
    return GameProgress(
      totalCompleted: prefs.getInt(_totalCompletedKey) ?? 0,
      lastRecentItemIds:
          prefs.getStringList(_lastRecentKey) ?? const <String>[],
      lastPlayedAt: DateTime.tryParse(prefs.getString(_lastPlayedAtKey) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      currentSetIndex: prefs.getInt(_currentSetIndexKey) ?? 0,
      phase: phase,
      roundIndex: prefs.getInt(_roundIndexKey) ?? 0,
      currentRoundOptionIds:
          prefs.getStringList(_roundOptionsKey) ?? const <String>[],
      currentRoundTargetId: prefs.getString(_roundTargetKey),
      wrongChoiceId: prefs.getString(_wrongChoiceIdKey),
    );
  }

  @override
  Future<void> save(GameProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_totalCompletedKey, progress.totalCompleted);
    await prefs.setStringList(
      _lastRecentKey,
      progress.lastRecentItemIds,
    );
    await prefs.setString(
      _lastPlayedAtKey,
      progress.lastPlayedAt.toIso8601String(),
    );
    await prefs.setInt(_currentSetIndexKey, progress.currentSetIndex);
    await prefs.setString(_phaseKey, progress.phase.name);
    await prefs.setInt(_roundIndexKey, progress.roundIndex);
    await prefs.setStringList(
      _roundOptionsKey,
      progress.currentRoundOptionIds,
    );
    if (progress.currentRoundTargetId == null) {
      await prefs.remove(_roundTargetKey);
    } else {
      await prefs.setString(_roundTargetKey, progress.currentRoundTargetId!);
    }
    if (progress.wrongChoiceId == null) {
      await prefs.remove(_wrongChoiceIdKey);
    } else {
      await prefs.setString(_wrongChoiceIdKey, progress.wrongChoiceId!);
    }
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_totalCompletedKey);
    await prefs.remove(_lastRecentKey);
    await prefs.remove(_lastPlayedAtKey);
    await prefs.remove(_currentSetIndexKey);
    await prefs.remove(_phaseKey);
    await prefs.remove(_roundIndexKey);
    await prefs.remove(_roundOptionsKey);
    await prefs.remove(_roundTargetKey);
    await prefs.remove(_wrongChoiceIdKey);
  }

  static SessionPhase? _phaseFromName(String? name) {
    if (name == null) return null;
    for (final phase in SessionPhase.values) {
      if (phase.name == name) return phase;
    }
    return null;
  }
}

/// In-memory implementation for tests.
class InMemoryGameProgressStore implements GameProgressStore {
  InMemoryGameProgressStore([GameProgress? initial]) : _value = initial;

  GameProgress? _value;

  @override
  Future<GameProgress?> load() async => _value;

  @override
  Future<void> save(GameProgress progress) async {
    _value = progress;
  }

  @override
  Future<void> clear() async {
    _value = null;
  }
}
