import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/catalog_repository.dart';
import '../domain/round_factory.dart';
import '../domain/shadow_item.dart';
import 'single_asset_effect.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final Future<List<ShadowItem>> _items = const CatalogRepository().load();

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
  final RoundFactory _factory = RoundFactory(random: Random());
  late ShadowRound _round;
  int _completed = 0;
  bool _solved = false;
  String? _wrongChoice;
  Timer? _nextRoundTimer;
  Timer? _wrongResetTimer;
  bool _effectPlaying = false;

  int get _optionCount => _completed < 5 ? 2 : (_completed < 15 ? 3 : 4);

  @override
  void initState() {
    super.initState();
    _round = _factory.create(catalog: widget.items, optionCount: _optionCount);
  }

  @override
  void dispose() {
    _nextRoundTimer?.cancel();
    _wrongResetTimer?.cancel();
    super.dispose();
  }

  void _onEffectCompleted() {
    if (!mounted) return;
    _advanceRound();
  }

  void _advanceRound() {
    final previousTarget = _round.target.id;
    _nextRoundTimer?.cancel();
    setState(() {
      _completed += 1;
      _round = _factory.create(
        catalog: widget.items,
        optionCount: _optionCount,
        previousTargetId: previousTarget,
      );
      _solved = false;
      _wrongChoice = null;
      _effectPlaying = false;
    });
  }

  void _choose(ShadowItem item) {
    if (_solved) return;
    if (_round.isCorrect(item.id)) {
      _wrongResetTimer?.cancel();
      setState(() {
        _solved = true;
        _wrongChoice = null;
        _effectPlaying = true;
      });
      _nextRoundTimer?.cancel();
      // 1.1s base reaction window; actual advance happens when the effect's
      // SingleAssetEffect widget calls back via [SingleAssetEffect.onCompleted].
      _nextRoundTimer = Timer(const Duration(milliseconds: 1200), _advanceRound);
    } else {
      setState(() => _wrongChoice = item.id);
      _wrongResetTimer?.cancel();
      _wrongResetTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _wrongChoice = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final tileSize = min(144.0, (screenSize.width - 56) / 2);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              SizedBox(
                height: 38,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final lit = index < (_completed % 5);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Icon(
                        lit ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 28,
                        color: const Color(0xFFE3B95B),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                flex: 5,
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 340, maxWidth: 340),
                    child: Semantics(
                      label: 'Find the matching silhouette for '
                          '${_round.target.accessibilityLabel ?? _round.target.id}',
                      child: _solved
                          ? SingleAssetEffect(
                              item: _round.target,
                              assetPath: _round.target.imagePath,
                              onCompleted: _effectPlaying ? _onEffectCompleted : null,
                            )
                          : AnimatedScale(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutBack,
                              scale: _solved ? 1.08 : 1,
                              child: Image.asset(
                                _round.target.imagePath,
                                fit: BoxFit.contain,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Center(
                  child: SingleChildScrollView(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final item in _round.options)
                          Semantics(
                            button: true,
                            label: '${item.accessibilityLabel ?? item.id} silhouette',
                            child: GestureDetector(
                              onTap: () => _choose(item),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: tileSize,
                                height: tileSize,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _solved && item.id == _round.target.id
                                      ? const Color(0xFFD7F0DD)
                                      : _wrongChoice == item.id
                                          ? const Color(0xFFFFE9C9)
                                          : Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: const Color(0xFFE9E8DF),
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x14000000),
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
          ),
        ),
      ),
    );
  }
}
