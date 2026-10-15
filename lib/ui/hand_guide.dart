import 'package:flutter/material.dart';

/// Hands-on silent onboarding hint for #16.
///
/// Rendered next to the option row; animates a finger from above down to
/// the centre option once, then disappears. The widget holds no game state
/// — it loops locally while the player is idle and self-removes when the
/// parent unmounts it (typically the first time the player taps an option).
class HandGuide extends StatefulWidget {
  const HandGuide({
    super.key,
    required this.targetBox,
    this.color = const Color(0xFF83BBAF),
  });

  /// The rectangle on screen that the finger should "tap".
  final Rect targetBox;
  final Color color;

  @override
  State<HandGuide> createState() => _HandGuideState();
}

class _HandGuideState extends State<HandGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_controller.value);
              final startY = widget.targetBox.top - 80;
              final endY = widget.targetBox.center.dy;
              final y = startY + (endY - startY) * t;
              final x = widget.targetBox.center.dx;
              return Positioned(
                left: x - 28,
                top: y - 28,
                child: Opacity(
                  opacity: 1 - t,
                  child: Icon(
                    Icons.touch_app_rounded,
                    size: 56,
                    color: widget.color,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
