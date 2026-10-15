import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/effect_preset.dart';
import '../domain/shadow_item.dart';

/// Plays the gentle, image-only reaction for a single [ShadowItem] when the
/// player answers a round correctly.
///
/// Each preset is implemented as a tiny Flutter animation driven by a single
/// [AnimationController]. There is no skeletal rig, no extra pose art, and
/// no extra runtime image fetch — everything happens on the GPU using
/// `Transform.scale/rotate/translate`, exactly as the v6 spec §3 enumerates.
class SingleAssetEffect extends StatefulWidget {
  const SingleAssetEffect({
    super.key,
    required this.item,
    required this.assetPath,
    this.size,
    this.onCompleted,
    this.imageBundle,
    this.imageProvider,
  });

  final ShadowItem item;

  /// Path of the (already decoded) image asset to animate.
  final String assetPath;

  /// Optional forced tile size. When null the widget expands to its
  /// parent and the underlying image keeps its `BoxFit.contain` ratio.
  final Size? size;

  /// Optional hook invoked once the effect finishes; the parent widget can
  /// use this to advance to the next round.
  final VoidCallback? onCompleted;

  /// Optional [AssetBundle] that resolves [assetPath]. Widget tests
  /// inject an in-memory bundle to avoid `rootBundle.load('AssetManifest.bin')`
  /// failures (Issue #21 follow-up).
  final AssetBundle? imageBundle;

  /// Optional pre-built [ImageProvider]. When non-null, takes
  /// precedence over [assetPath]/[imageBundle]; widget tests pass a
  /// [MemoryImage] here to bypass the asset bundle entirely.
  final ImageProvider? imageProvider;

  @override
  State<SingleAssetEffect> createState() => _SingleAssetEffectState();
}

class _SingleAssetEffectState extends State<SingleAssetEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _controller.addStatusListener(_handleStatus);
    _controller.forward();
  }

  void _handleStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed) {
      widget.onCompleted?.call();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Prefer an injected ImageProvider (widget tests pass MemoryImage to
    // bypass AssetManifest.bin entirely); otherwise fall back to Image.asset
    // with the optional [imageBundle] override.
    final image = widget.imageProvider != null
        ? Image(image: widget.imageProvider!, fit: BoxFit.contain)
        : Image.asset(
            widget.assetPath,
            fit: BoxFit.contain,
            bundle: widget.imageBundle,
          );
    final wrapped = widget.size == null
        ? image
        : SizedBox.fromSize(size: widget.size!, child: image);
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) =>
          _applyTransform(widget.item.effectPreset, child, _animation.value),
      child: wrapped,
    );
  }

  Widget _applyTransform(EffectPreset preset, Widget? child, double t) {
    const pivot = Alignment.center;
    switch (preset) {
      case EffectPreset.squish:
        // Squeeze X, squash Y inversely. `t` goes 0→1; peak at t=0.5.
        final phase = t < 0.5 ? t * 2 : (1 - t) * 2;
        final scaleX = 1 + 0.12 * phase;
        final scaleY = 1 - 0.12 * phase;
        return Transform(
          alignment: pivot,
          transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
          child: child,
        );
      case EffectPreset.wobble:
        // Damped rotation: 7° amplitude decaying to 0° as `t` → 1.
        final angle = (1 - t) * 0.12 * math.sin(t * 4 * math.pi);
        return Transform.rotate(
          alignment: pivot,
          angle: angle,
          child: child,
        );
      case EffectPreset.bounce:
        if (t < 0.6) {
          // Hop up and back down.
          final n = t / 0.6;
          return Transform.translate(
            offset: Offset(0, -12 * n * (1 - n) * 4),
            child: child,
          );
        }
        // Landing squash for the last 40% of the animation.
        final landT = (t - 0.6) / 0.4;
        final landPhase = (landT - 0.5).abs() * 2; // 1 → 0 → 1
        final scaleY = 1 - 0.18 * landPhase;
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.diagonal3Values(2 - scaleY, scaleY, 1),
          child: child,
        );
      case EffectPreset.inflate:
        // Brief expansion with peak at t=0.5.
        final peak = t < 0.5 ? t * 2 : (1 - t) * 2;
        final scale = 1 + 0.2 * peak;
        return Transform(
          alignment: pivot,
          transform: Matrix4.diagonal3Values(scale, scale, 1),
          child: child,
        );
    }
  }
}
