// ignore_for_file: prefer_const_constructors

import 'package:animal_shadow_match/domain/effect_preset.dart';
import 'package:animal_shadow_match/domain/shadow_item.dart';
import 'package:animal_shadow_match/ui/resting_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ShadowItem _item(String id) {
  return ShadowItem(
    id: id,
    imagePath: 'assets/animals/butterfly.webp',
    shadowPath: 'assets/animals/butterfly_shadow.webp',
    category: 'squishy_object',
    distractorIds: const [],
    effectPreset: EffectPreset.squish,
  );
}

void main() {
  final items = [
    _item('gel_star'),
    _item('cloud_cushion'),
    _item('teardrop_gummy'),
    _item('twist_gummy'),
    _item('soft_planet'),
  ];

  testWidgets('RestingScreen renders the recent items and the Resume button',
      (tester) async {
    var resumeCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RestingScreen(items: items, onResume: () => resumeCalls += 1),
      ),
    );
    // The RestingTile animation controller repeats indefinitely; pump a
    // few explicit frames instead of pumpAndSettle so the test can
    // observe the static state.
    await tester.pump();
    expect(find.byType(RestingScreen), findsOneWidget);
    expect(find.byTooltip('Resume'), findsOneWidget);
    expect(find.byIcon(Icons.replay_rounded), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(items.length));
    // Issue #21 follow-up: the AppBar must NOT carry a text title.
    expect(find.text('Resting'), findsNothing);
  });

  testWidgets('RestingScreen fits a 360x640dp viewport without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: RestingScreen(items: items, onResume: () {}),
      ),
    );
    await tester.pump();
    // No exception is the success signal. The tile wrap should fold the
    // 5 items onto multiple lines without overflowing the AppBar or the
    // safe area.
    expect(tester.takeException(), isNull);
    expect(find.byType(RestingScreen), findsOneWidget);
  });

  testWidgets('Tapping the Resume icon button calls onResume',
      (tester) async {
    var resumeCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RestingScreen(items: items, onResume: () => resumeCalls += 1),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();
    expect(resumeCalls, 1);
  });

  testWidgets('Tapping anywhere on the resting area also calls onResume',
      (tester) async {
    var resumeCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RestingScreen(items: items, onResume: () => resumeCalls += 1),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(GestureDetector).last);
    await tester.pump();
    expect(resumeCalls, 1);
  });

  testWidgets('Empty items list shows the inbox icon instead of crashing',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RestingScreen(items: <ShadowItem>[])),
    );
    await tester.pump();
    expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);
  });
}
