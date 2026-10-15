import 'package:flutter/material.dart';

import '../domain/effect_preset.dart';
import '../domain/shadow_item.dart';
import 'single_asset_effect.dart';

/// P1 prototype of the Clip-split effect (#30).
///
/// Same image rendered twice: the left half is shifted left, the right
/// half is shifted right. The result reads as a 2D paper-tearing reveal —
/// it is **not** a real cross-section (no interior is exposed).
///
/// Per the v6 spec §3 / Issue #30 the clip-split effect is a P1 experiment
/// and should NOT be used for objects whose identity depends on what is
/// inside them. Only objects whose value is purely the outer silhouette
/// should be paired with `effectPreset: split` once that enum value is
/// introduced. The MVP keeps `EffectPreset` locked to the four shipped
/// transforms; this widget is wired manually so designers can prototype it
/// from the catalog metadata.
class ClipSplitEffect extends StatefulWidget {
  const ClipSplitEffect({
    super.key,
    required this.item,
    required this.assetPath,
    this.splitOffset = 18,
    this.duration = const Duration(milliseconds: 750),
    this.onCompleted,
  });

  final ShadowItem item;
  final String assetPath;
  final double splitOffset;
  final Duration duration;
  final VoidCallback? onCompleted;

  @override
  State<ClipSplitEffect> createState() => _ClipSplitEffectState();
}

class _ClipSplitEffectState extends State<ClipSplitEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener(_onStatus)
        ..forward();

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onCompleted?.call();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(widget.assetPath, fit: BoxFit.contain);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final dx = widget.splitOffset * t;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRect(
              clipper: _LeftHalfClipper(),
              child: Transform.translate(offset: Offset(-dx, 0), child: image),
            ),
            ClipRect(
              clipper: _RightHalfClipper(),
              child: Transform.translate(offset: Offset(dx, 0), child: image),
            ),
          ],
        );
      },
    );
  }
}

class _LeftHalfClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

class _RightHalfClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}
