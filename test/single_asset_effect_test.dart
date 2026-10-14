import 'package:animal_shadow_match/domain/effect_preset.dart';
import 'package:animal_shadow_match/domain/shadow_item.dart';
import 'package:animal_shadow_match/ui/single_asset_effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ShadowItem _item(EffectPreset preset) => ShadowItem(
      id: 'gel_star',
      imagePath: 'assets/animals/butterfly.webp', // bundled demo asset
      shadowPath: 'assets/animals/butterfly_shadow.webp',
      category: 'squishy_object',
      distractorIds: const ['toy_001'],
      effectPreset: preset,
    );

Future<void> _pumpEffect(WidgetTester tester, ShadowItem item) async {
  bool called = false;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SingleAssetEffect(
            item: item,
            assetPath: item.imagePath,
            onCompleted: () => called = true,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(called, isFalse, reason: 'onCompleted must not fire before the animation finishes');
  await tester.pumpAndSettle(const Duration(seconds: 2));
  expect(find.byType(SingleAssetEffect), findsOneWidget);
}

void main() {
  for (final preset in EffectPreset.values) {
    testWidgets('SingleAssetEffect renders and completes for ${preset.name}',
        (tester) async {
      await _pumpEffect(tester, _item(preset));
    });
  }

  testWidgets('SingleAssetEffect invokes the completion hook exactly once',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SingleAssetEffect(
              item: _item(EffectPreset.wobble),
              assetPath: 'assets/animals/butterfly.webp',
              onCompleted: () => calls += 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(calls, 1);
  });
}
