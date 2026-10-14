import 'package:animal_shadow_match/domain/shadow_item.dart';
import 'package:animal_shadow_match/ui/game_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<ShadowItem> _demo() {
  const ids = ['cat', 'rabbit', 'duck', 'whale', 'elephant', 'giraffe'];
  return [
    for (final id in ids)
      ShadowItem(
        id: id,
        imagePath: 'assets/animals/$id.webp',
        shadowPath: 'assets/animals/' + id + '_shadow.webp',
        category: 'demo',
        distractorIds: const [],
        accessibilityLabel: id,
      ),
  ];
}

void main() {
  testWidgets('five correct choices lead to gallery, break, and new set',
      (tester) async {
    final items = _demo();
    await tester.pumpWidget(
      MaterialApp(home: GamePage(demoItems: items)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mvp-play-board')), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      final image = tester.widget<Image>(find.byKey(const ValueKey('target-image')));
      final path = (image.image as AssetImage).assetName;
      final target = items.firstWhere((item) => item.imagePath == path);
      await tester.tap(find.byKey(ValueKey('option-' + target.id)));
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const ValueKey('mvp-playground')), findsOneWidget);
    expect(find.byKey(const ValueKey('continue-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('break-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('break-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mvp-resting')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('resume-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mvp-playground')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('continue-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mvp-play-board')), findsOneWidget);
    expect(find.byKey(const ValueKey('option-undefined')), findsNothing);
  });
}
