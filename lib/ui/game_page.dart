import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/catalog_repository.dart';
import '../domain/game_session.dart';
import '../domain/shadow_item.dart';
import 'single_asset_effect.dart';

/// Text-free matching game. A bundled eight-animal demo stays available until
/// human-reviewed MiniMax objects are added to assets/catalog/items.json.
class GamePage extends StatefulWidget {
  const GamePage({super.key, this.demoItems});

  /// Test/playtest injection; production uses the bundled catalog.
  final List<ShadowItem>? demoItems;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final Future<List<ShadowItem>> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.demoItems == null
        ? const CatalogRepository().load()
        : Future<List<ShadowItem>>.value(widget.demoItems!);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ShadowItem>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Icon(Icons.sentiment_dissatisfied_rounded, size: 72),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _PlayBoard(items: snapshot.data!);
      },
    );
  }
}

class _PlayBoard extends StatefulWidget {
  const _PlayBoard({required this.items});

  final List<ShadowItem> items;

  @override
  State<_PlayBoard> createState() => _PlayBoardState();
}

class _PlayBoardState extends State<_PlayBoard> {
  late final GameSession _session;

  Timer? _nextRoundTimeout;
  Timer? _wrongChoiceTimeout;
  String? _wrongChoiceId;
  int? _activeGalleryIndex;
  int _galleryTapCounter = 0;

  @override
  void initState() {
    super.initState();
    _session = GameSession(catalog: widget.items);
  }

  @override
  void dispose() {
    _nextRoundTimeout?.cancel();
    _wrongChoiceTimeout?.cancel();
    super.dispose();
  }

  void _choose(ShadowItem item) {
    if (_session.phase != GamePhase.matching ||
        _session.awaitingReaction) return;

    if (_session.choose(item.id)) {
      _wrongChoiceTimeout?.cancel();
      _nextRoundTimeout?.cancel();
      _nextRoundTimeout = Timer(
        const Duration(milliseconds: 1200),
        _completeReaction,
      );
      setState(() => _wrongChoiceId = null);
    } else {
      setState(() => _wrongChoiceId = item.id);
      _wrongChoiceTimeout?.cancel();
      _wrongChoiceTimeout = Timer(
        const Duration(milliseconds: 500),
        () {
          if (mounted) setState(() => _wrongChoiceId = null);
        },
      );
    }
  }

  void _completeReaction() {
    if (!mounted || !_session.awaitingReaction) return;
    _nextRoundTimeout?.cancel();
    setState(() {
      _session.finishReaction();
      _wrongChoiceId = null;
      _activeGalleryIndex = null;
    });
  }

  void _continue() {
    setState(() {
      _session.continuePlaying();
      _activeGalleryIndex = null;
    });
  }

  void _takeBreak() => setState(_session.takeBreak);
  void _resume() => setState(_session.resume);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: switch (_session.phase) {
            GamePhase.matching => _matching(),
            GamePhase.playground => _playground(),
            GamePhase.resting => _resting(),
          },
        ),
      ),
    );
  }

  Widget _progress() {
    final done = _session.setItems.length +
        (_session.awaitingReaction ? 1 : 0);
    return SizedBox(
      height: 38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_session.roundsPerSet, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Icon(
              index < done ? Icons.star_rounded : Icons.star_border_rounded,
              size: 28,
              color: const Color(0xFFE3B95B),
            ),
          );
        }),
      ),
    );
  }

  Widget _matching() {
    final width = MediaQuery.sizeOf(context).width;
    final tile = math.min(140.0, math.max(96.0, (width - 60) / 2));
    final target = _session.round.target;

    return Column(
      key: const ValueKey('mvp-play-board'),
      children: [
        _progress(),
        const SizedBox(height: 8),
        Expanded(
          flex: 5,
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxHeight: 330, maxWidth: 330),
              child: Semantics(
                label: 'Match the silhouette of ' +
                    (target.accessibilityLabel ?? target.id),
                child: _session.awaitingReaction
                    ? SingleAssetEffect(
                        key: ValueKey('target-effect-' + target.id),
                        item: target,
                        assetPath: target.imagePath,
                        onCompleted: _completeReaction,
                      )
                    : Image.asset(
                        target.imagePath,
                        key: const ValueKey('target-image'),
                        fit: BoxFit.contain,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 5,
          child: Center(
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in _session.round.options)
                    Semantics(
                      button: true,
                      label: 'Silhouette of ' +
                          (item.accessibilityLabel ?? item.id),
                      child: GestureDetector(
                        key: ValueKey('option-' + item.id),
                        onTap: () => _choose(item),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: tile,
                          height: tile,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _session.awaitingReaction &&
                                    item.id == target.id
                                ? const Color(0xFFD7F0DD)
                                : _wrongChoiceId == item.id
                                    ? const Color(0xFFFFE9C9)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: const Color(0xFFE9E8DF),
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            item.shadowPath,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _playground() {
    final items = _session.setItems;
    final width = MediaQuery.sizeOf(context).width;
    final tile = math.min(134.0, math.max(96.0, (width - 72) / 2));

    return Column(
      key: const ValueKey('mvp-playground'),
      children: [
        _progress(),
        const SizedBox(height: 14),
        const Icon(Icons.auto_awesome_rounded,
            size: 48, color: Color(0xFFE3B95B)),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < items.length; i++)
                    Semantics(
                      button: true,
                      label: 'Play with ' +
                          (items[i].accessibilityLabel ?? items[i].id),
                      child: GestureDetector(
                        key: ValueKey('playground-' + items[i].id),
                        onTap: () => setState(() {
                          _activeGalleryIndex = i;
                          _galleryTapCounter++;
                        }),
                        child: Container(
                          width: tile,
                          height: tile,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(0xFFD9E8DE), width: 2),
                          ),
                          child: _activeGalleryIndex == i
                              ? SingleAssetEffect(
                                  key: ValueKey('replay-' + items[i].id +
                                      '-' + _galleryTapCounter.toString()),
                                  item: items[i],
                                  assetPath: items[i].imagePath,
                                )
                              : Image.asset(items[i].imagePath,
                                  fit: BoxFit.contain),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _largeIconButton(
              key: const ValueKey('continue-button'),
              icon: Icons.play_arrow_rounded,
              color: const Color(0xFFBCE9D3),
              label: 'Play five more',
              onTap: _continue,
            ),
            _largeIconButton(
              key: const ValueKey('break-button'),
              icon: Icons.nightlight_round,
              color: const Color(0xFFE8E0F8),
              label: 'Take a break',
              onTap: _takeBreak,
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _resting() {
    return Column(
      key: const ValueKey('mvp-resting'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        const Icon(Icons.nightlight_round,
            size: 120, color: Color(0xFFB6A8E3)),
        const SizedBox(height: 35),
        const Icon(Icons.auto_awesome_rounded,
            size: 52, color: Color(0xFFD8CAA4)),
        const Spacer(),
        Center(
          child: _largeIconButton(
            key: const ValueKey('resume-button'),
            icon: Icons.play_arrow_rounded,
            color: const Color(0xFFBCE9D3),
            label: 'Return to the play area',
            onTap: _resume,
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _largeIconButton({
    required Key key,
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(32),
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(32),
          onTap: onTap,
          child: SizedBox(
            width: 112,
            height: 100,
            child: Icon(icon, size: 62, color: const Color(0xFF465452)),
          ),
        ),
      ),
    );
  }
}
