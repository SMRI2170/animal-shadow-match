import 'package:animal_shadow_match/domain/effect_preset.dart';
import 'package:animal_shadow_match/domain/shadow_item.dart';
import 'package:animal_shadow_match/ui/play_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ShadowItem _item(String id) {
  return ShadowItem(
    id: id,
    imagePath: 'assets/animals/butterfly.webp', // bundled demo asset
    shadowPath: 'assets/animals/butterfly_shadow.webp',
    category: 'squishy_object',
    distractorIds: const [],
    effectPreset: EffectPreset.squish,
  );
}

void main() {
  testWidgets('ReviewPlayArea renders one tile per item', (tester) async {
    var continueCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewPlayArea(
          items: [
            _item('gel_star'),
            _item('cloud_cushion'),
            _item('teardrop_gummy'),
          ],
          onContinue: () => continueCalls++,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(ReviewPlayArea), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(continueCalls, 1);
  });

  testWidgets('ReviewPlayArea handles an empty list gracefully',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ReviewPlayArea(items: <ShadowItem>[])),
    );
    await tester.pump();
    expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);
  });
}
