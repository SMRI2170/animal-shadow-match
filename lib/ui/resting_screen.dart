import 'package:flutter/material.dart';

import '../domain/shadow_item.dart';

/// Idle "rest" screen shown after the child taps Rest on
/// [ReviewPlayArea]. Lays out the recent [ShadowItem]s in a calm
/// floating-grid layout that gently bobs up and down so the screen
/// never goes blank. A tap anywhere returns to the review area via
/// [onResume]; the AppBar also exposes a Resume button for caregivers.
class RestingScreen extends StatelessWidget {
  const RestingScreen({
    super.key,
    required this.items,
    this.onResume,
  });

  final List<ShadowItem> items;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resting'),
        backgroundColor: const Color(0xFFFFF9F0),
        elevation: 0,
        actions: [
          if (onResume != null)
            TextButton(
              onPressed: onResume,
              child: const Text(
                'Resume',
                style: TextStyle(fontSize: 18),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onResume,
          child: Center(
            child: items.isEmpty
                ? const Icon(Icons.inbox_rounded, size: 72)
                : Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final item in items) _RestingTile(item: item),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _RestingTile extends StatefulWidget {
  const _RestingTile({required this.item});

  final ShadowItem item;

  @override
  State<_RestingTile> createState() => _RestingTileState();
}

class _RestingTileState extends State<_RestingTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, 4 * (0.5 - _controller.value)),
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE9E8DF), width: 2),
            ),
            padding: const EdgeInsets.all(8),
            child: Opacity(
              opacity: 0.75,
              child: Image.asset(widget.item.imagePath, fit: BoxFit.contain),
            ),
          ),
        );
      },
    );
  }
}
