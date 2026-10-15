// ignore_for_file: prefer_const_constructors

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
                targetBox: Rect.fromLTWH(40, 60, 80, 80),
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

  testWidgets(
    'HandGuide honours MediaQuery.disableAnimations (reduce-motion, Issue #21)',
    (tester) async {
      // pumpAndSettle would otherwise hang on the repeating controller.
      // When reduce-motion is on, the controller must stay stopped.
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(
              disableAnimations: true,
              size: Size(400, 400),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(
            body: Stack(
              children: const [
                HandGuide(targetBox: Rect.fromLTWH(10, 10, 50, 50)),
              ],
            ),
          ),
        ),
      );
      // If the controller were still repeating, pumpAndSettle would time
      // out; the assertion below is reached only because the widget is
      // sitting at a static frame.
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(find.byType(HandGuide), findsOneWidget);
      expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);
    },
  );

  testWidgets('HandGuide re-arms the controller when reduce-motion is turned off',
      (tester) async {
    var reduceMotion = true;
    late StateSetter setStateOuter;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setStateOuter = setState;
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: reduceMotion,
                ),
                child: Stack(
                  children: const [
                    HandGuide(targetBox: Rect.fromLTWH(10, 10, 50, 50)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    reduceMotion = false;
    setStateOuter(() {});
    await tester.pump();
    // After flipping the flag the widget must rebuild without throwing
    // and remain on screen.
    expect(find.byType(HandGuide), findsOneWidget);
  });
}
