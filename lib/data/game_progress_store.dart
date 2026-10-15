import 'package:shared_preferences/shared_preferences.dart';

/// Persisted progress that survives app restarts. Captures enough state for
/// #22 (中断/再開) and #25 (プレイエリア復元) without ever holding a
/// reference to a [ShadowItem].
class GameProgress {
  const GameProgress({
    required this.totalCompleted,
    required this.lastRecentItemIds,
    required this.lastPlayedAt,
    required this.currentSetIndex,
  });

  /// Successful matches across the app lifetime. Bounded conceptually but
  /// stored as an int for flexibility.
  final int totalCompleted;

  /// Up to five target ids the child just played with. Used to populate the
  /// review play area when the child returns.
  final List<String> lastRecentItemIds;

  /// Last time the child reached a Solved / SetCompleted state.
  final DateTime lastPlayedAt;

  /// 0-based index of the active set. Resets to 0 after a SetCompleted
  /// continues into a new set.
  final int currentSetIndex;

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
    );
  }

  GameProgress copyWith({
    int? totalCompleted,
    List<String>? lastRecentItemIds,
    DateTime? lastPlayedAt,
    int? currentSetIndex,
  }) {
    return GameProgress(
      totalCompleted: totalCompleted ?? this.totalCompleted,
      lastRecentItemIds:
          lastRecentItemIds ?? this.lastRecentItemIds,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      currentSetIndex: currentSetIndex ?? this.currentSetIndex,
    );
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

  @override
  Future<GameProgress?> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_totalCompletedKey)) {
      return null;
    }
    return GameProgress(
      totalCompleted: prefs.getInt(_totalCompletedKey) ?? 0,
      lastRecentItemIds:
          prefs.getStringList(_lastRecentKey) ?? const <String>[],
      lastPlayedAt: DateTime.tryParse(prefs.getString(_lastPlayedAtKey) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      currentSetIndex: prefs.getInt(_currentSetIndexKey) ?? 0,
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
    await prefs.setString(_lastPlayedAtKey, progress.lastPlayedAt.toIso8601String());
    await prefs.setInt(_currentSetIndexKey, progress.currentSetIndex);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_totalCompletedKey);
    await prefs.remove(_lastRecentKey);
    await prefs.remove(_lastPlayedAtKey);
    await prefs.remove(_currentSetIndexKey);
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
