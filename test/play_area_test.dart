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
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byTooltip('Continue'), findsOneWidget);
    await tester.tap(find.byTooltip('Continue'));
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

  testWidgets('ReviewPlayArea shows a Rest button when onRest is provided',
      (tester) async {
    var continueCalls = 0;
    var restCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewPlayArea(
          items: [
            _item('gel_star'),
            _item('cloud_cushion'),
            _item('teardrop_gummy'),
          ],
          onContinue: () => continueCalls++,
          onRest: () => restCalls++,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byTooltip('Rest'), findsOneWidget);
    expect(find.byTooltip('Continue'), findsOneWidget);
    expect(find.byIcon(Icons.bedtime_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Rest'));
    await tester.pump();
    expect(restCalls, 1);
    expect(continueCalls, 0);
  });

  testWidgets('ReviewPlayArea fits a 360x640dp viewport without overflow',
      (tester) async {
    // 5 tiles on a 360x640dp phone. The Wrap should fold them onto
    // multiple lines without throwing a RenderFlex overflow.
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewPlayArea(
          items: [
            _item('gel_star'),
            _item('cloud_cushion'),
            _item('teardrop_gummy'),
            _item('twist_gummy'),
            _item('soft_planet'),
          ],
          onContinue: () {},
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.byType(ReviewPlayArea), findsOneWidget);
    // The 5 review tiles are present.
    expect(find.byIcon(Icons.bedtime_rounded), findsNothing,
        reason: 'onRest was not provided, so the Rest icon is absent');
  });
}
