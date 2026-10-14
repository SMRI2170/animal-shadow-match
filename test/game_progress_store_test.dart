import 'package:animal_shadow_match/data/game_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('GameProgress round-trips through JSON', () {
    final now = DateTime.utc(2026, 10, 14, 1, 2, 3);
    final progress = GameProgress(
      totalCompleted: 7,
      lastRecentItemIds: const ['gel_star', 'cloud_cushion'],
      lastPlayedAt: now,
      currentSetIndex: 2,
    );
    final restored = GameProgress.fromJson(progress.toJson());
    expect(restored.totalCompleted, 7);
    expect(restored.lastRecentItemIds,
        equals(['gel_star', 'cloud_cushion']));
    expect(restored.lastPlayedAt.toUtc(), now);
    expect(restored.currentSetIndex, 2);
  });

  test('fromJson tolerates missing fields with defaults', () {
    final restored = GameProgress.fromJson({});
    expect(restored.totalCompleted, 0);
    expect(restored.lastRecentItemIds, isEmpty);
    expect(restored.currentSetIndex, 0);
  });

  test('InMemoryGameProgressStore honours save/load/clear', () async {
    final store = InMemoryGameProgressStore();
    expect(await store.load(), isNull);

    final progress = GameProgress(
      totalCompleted: 3,
      lastRecentItemIds: const ['a'],
      lastPlayedAt: DateTime.utc(2026, 1, 1),
      currentSetIndex: 0,
    );
    await store.save(progress);
    final restored = await store.load();
    expect(restored, isNotNull);
    expect(restored!.totalCompleted, 3);

    await store.clear();
    expect(await store.load(), isNull);
  });

  test('SharedPreferencesGameProgressStore writes via the global prefs',
      () async {
    SharedPreferences.setMockInitialValues({
      'totalCompleted': 5,
      'lastRecentItemIds': ['toy_001', 'toy_002'],
      'lastPlayedAt': '2026-10-14T00:00:00.000Z',
      'currentSetIndex': 1,
    });
    final store = const SharedPreferencesGameProgressStore();
    final loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!.totalCompleted, 5);
    expect(loaded.lastRecentItemIds, ['toy_001', 'toy_002']);
    expect(loaded.currentSetIndex, 1);

    await store.save(loaded.copyWith(totalCompleted: 6));
    final reloaded = await store.load();
    expect(reloaded!.totalCompleted, 6);

    await store.clear();
    expect(await store.load(), isNull);
  });
}
