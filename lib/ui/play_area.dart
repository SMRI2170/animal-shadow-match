import 'package:flutter/material.dart';

import '../domain/shadow_item.dart';
import 'single_asset_effect.dart';

/// Review play area for #25.
///
/// Lays out up to five [ShadowItem]s in a wrap, each individually tappable.
/// A successful tap plays the FX preset (same as in-game) so the child can
/// replay their favourite objects after a set completes.
class ReviewPlayArea extends StatelessWidget {
  const ReviewPlayArea({
    super.key,
    required this.items,
    this.onContinue,
  });

  final List<ShadowItem> items;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: const Color(0xFFFFF9F0),
        elevation: 0,
        actions: [
          if (onContinue != null)
            TextButton(
              onPressed: onContinue,
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 18),
              ),
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
                      _ReviewTile(item: item),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatefulWidget {
  const _ReviewTile({required this.item});

  final ShadowItem item;

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
        ),
      ),
    );
  }
}
