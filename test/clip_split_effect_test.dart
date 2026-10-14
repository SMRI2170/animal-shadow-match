import 'package:animal_shadow_match/domain/effect_preset.dart';
import 'package:animal_shadow_match/domain/shadow_item.dart';
import 'package:animal_shadow_match/ui/clip_split_effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ShadowItem _item() => ShadowItem(
      id: 'gel_star',
      imagePath: 'assets/animals/butterfly.webp',
      shadowPath: 'assets/animals/butterfly_shadow.webp',
      category: 'squishy_object',
      distractorIds: const [],
      effectPreset: EffectPreset.squish,
    );

void main() {
  testWidgets('ClipSplitEffect renders two halves side-by-side',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ClipSplitEffect(
              item: _item(),
              assetPath: 'assets/animals/butterfly.webp',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ClipSplitEffect), findsOneWidget);
    expect(find.byType(ClipRect), findsNWidgets(2));
  });

  testWidgets('ClipSplitEffect completion hook fires exactly once',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ClipSplitEffect(
              item: _item(),
              assetPath: 'assets/animals/butterfly.webp',
              duration: const Duration(milliseconds: 200),
              onCompleted: () => calls += 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(calls, 1);
  });
}
