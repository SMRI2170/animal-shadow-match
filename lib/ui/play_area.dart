import 'package:flutter/material.dart';

import '../domain/shadow_item.dart';
import 'single_asset_effect.dart';

/// Review play area for #25.
///
/// Lays out up to five [ShadowItem]s in a wrap, each individually tappable.
/// A successful tap plays the FX preset (same as in-game) so the child can
/// replay their favourite objects after a set completes.
///
/// [onRest] is the optional callback for the Rest button. When provided,
/// the AppBar shows a "Rest" action that pauses the session so the
/// caregiver can step away without losing progress (Issue #86 review).
class ReviewPlayArea extends StatelessWidget {
  const ReviewPlayArea({
    super.key,
    required this.items,
    this.onContinue,
    this.onRest,
    this.imageBundle,
    this.imageProvider,
  });

  final List<ShadowItem> items;
  final VoidCallback? onContinue;
  final VoidCallback? onRest;

  /// Optional [AssetBundle] that resolves every Image.asset on the
  /// review tiles. Widget tests inject an in-memory bundle to avoid
  /// `rootBundle.load('AssetManifest.bin')` failures (Issue #21
  /// follow-up: full GamePage widget test).
  final AssetBundle? imageBundle;

  /// Optional pre-built [ImageProvider] used as the source for every
  /// review tile. When non-null, takes precedence over [imageBundle].
  /// Widget tests inject a [MemoryImage] here to bypass the asset
  /// manifest entirely.
  final ImageProvider? imageProvider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: const Color(0xFFFFF9F0),
        elevation: 0,
        actions: [
          if (onRest != null)
            IconButton(
              icon: const Icon(Icons.bedtime_rounded, size: 28),
              tooltip: 'Rest',
              onPressed: onRest,
            ),
          if (onContinue != null)
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              tooltip: 'Continue',
              onPressed: onContinue,
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: items.isEmpty
              ? const Center(
                  child: Icon(Icons.inbox_rounded, size: 72),
                )
              : Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final item in items)
                      _ReviewTile(
                        item: item,
                        imageBundle: imageBundle,
                        imageProvider: imageProvider,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatefulWidget {
  const _ReviewTile({
    required this.item,
    this.imageBundle,
    this.imageProvider,
  });

  final ShadowItem item;
  final AssetBundle? imageBundle;
  final ImageProvider? imageProvider;

  @override
  State<_ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends State<_ReviewTile> {
  Key _effectKey = UniqueKey();

  void _trigger() {
    setState(() => _effectKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _trigger,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE9E8DF), width: 2),
        ),
        padding: const EdgeInsets.all(8),
        child: SingleAssetEffect(
          key: _effectKey,
          item: widget.item,
          assetPath: widget.item.imagePath,
          imageBundle: widget.imageBundle,
          imageProvider: widget.imageProvider,
        ),
      ),
    );
  }
}
