import 'package:animal_shadow_match/ui/hand_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HandGuide renders a touch icon over the target box',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 40,
                top: 60,
                width: 80,
                height: 80,
                child: Container(key: key, color: Colors.amber),
              ),
              HandGuide(
                targetBox: const Rect.fromLTWH(40, 60, 80, 80),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);
  });

  testWidgets('HandGuide stays on screen at the first frame', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: const [
              HandGuide(targetBox: Rect.fromLTWH(10, 10, 50, 50)),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(HandGuide), findsOneWidget);
  });
}
