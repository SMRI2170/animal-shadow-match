import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/catalog_load_result.dart';
import '../data/catalog_repository.dart';
import '../data/game_progress_store.dart';
import '../domain/game_controller.dart';
import '../domain/game_state.dart';
import '../domain/round_factory.dart';
import '../domain/shadow_item.dart';
import 'hand_guide.dart';
import 'play_area.dart';
import 'resting_screen.dart';
import 'single_asset_effect.dart';

/// Top-level game screen. Wires [CatalogRepository] -> [GameController] ->
/// [GameState] -> the appropriate widget ([Solving] board, the [Solved] FX,
/// or the [ReviewPlayArea]) and persists progress through
/// [GameProgressStore].
///
/// Widget tests inject a fake asset bundle via [CatalogRepository.test] and
/// an in-memory progress store via [progressStore] so the whole flow can be
/// driven without `SharedPreferences.setMockInitialValues` at every call site.
class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    this.progressStore,
    this.repository,
    this.disableHandGuide = false,
  });

  /// Optional injection point. Defaults to [SharedPreferencesGameProgressStore].
  final GameProgressStore? progressStore;

  /// Optional injection point for the catalog loader. Widget tests pass a
  /// [CatalogRepository.test] instance bound to an in-memory bundle; production
  /// callers leave this null to use the default [CatalogRepository] that reads
  /// from the Flutter [rootBundle].
  final CatalogRepository? repository;

  /// When true, the first-set onboarding HandGuide is suppressed entirely
  /// (used by widget tests so `pumpAndSettle` does not block on the
  /// repeating AnimationController — Issue #21).
  final bool disableHandGuide;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final Future<CatalogLoadResult> _catalogFuture =
      (widget.repository ?? CatalogRepository()).load();
  late final GameProgressStore _progressStore =
      widget.progressStore ?? const SharedPreferencesGameProgressStore();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CatalogLoadResult>(
      future: _catalogFuture,
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
        return _PlayBoard(
          result: snapshot.data!,
          factory: RoundFactory(random: Random()),
          progressStore: _progressStore,
          disableHandGuide: widget.disableHandGuide,
        );
      },
    );
  }
}

class _PlayBoard extends StatefulWidget {
  const _PlayBoard({
    required this.result,
    required this.factory,
    required this.progressStore,
    this.disableHandGuide = false,
  });

  final CatalogLoadResult result;
  final RoundFactory factory;
  final GameProgressStore progressStore;
  final bool disableHandGuide;

  @override
  State<_PlayBoard> createState() => _PlayBoardState();
}

class _PlayBoardState extends State<_PlayBoard> {
  late GameController _controller;
  GameState? _state;
  String? _wrongChoice;
  Timer? _wrongResetTimer;
  bool _showHandGuide = true;
  bool _resumed = false;

  bool get _handGuideEnabled =>
      _showHandGuide && !widget.disableHandGuide;

  @override
  void initState() {
    super.initState();
    _controller = GameController(
      catalog: widget.result.items,
      factory: widget.factory,
    );
    _state = _controller.start();
    // Attempt to restore from persisted progress (Issue #22 / #25). The
    // store is read once on the first frame; we clear the saved progress
    // afterwards so the next cold start begins a fresh set unless the
    // player explicitly returns mid-set.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeResume());
  }

  @override
  void dispose() {
    _wrongResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _maybeResume() async {
    if (_resumed || !mounted) return;
    _resumed = true;
    final saved = await widget.progressStore.load();
    if (!mounted || saved == null) return;
    if (saved.totalCompleted <= 0) return;
    setState(() {
      _controller.resumeFromTotalCompleted(saved.totalCompleted);
      _state = _controller.current;
    });
  }

  void _onChoice(ShadowItem item) {
    final current = _state;
    if (current is! SolvingState) return;
    if (current.round.isCorrect(item.id)) {
      _wrongResetTimer?.cancel();
      final next = _controller.onChoice(item.id);
      setState(() {
        _state = next;
        _wrongChoice = null;
        _showHandGuide = false;
      });
      _persistProgress();
    } else {
      _wrongResetTimer?.cancel();
      setState(() => _wrongChoice = item.id);
      _wrongResetTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _wrongChoice = null);
      });
    }
  }

  void _onEffectCompleted() {
    final current = _state;
    if (current is! SolvedState) return;
    final next = _controller.onEffectFinished();
    setState(() => _state = next);
  }

  void _onContinueFromSet() {
    final current = _state;
    if (current is! SetCompletedState) return;
    final next = _controller.onContinue();
    setState(() {
      _state = next;
      _showHandGuide = true;
    });
    _persistProgress();
  }

  void _onRestFromSet() {
    final current = _state;
    if (current is! SetCompletedState) return;
    setState(() => _state = _controller.onRest());
  }

  void _onResumeFromRest() {
    final current = _state;
    if (current is! RestingState) return;
    setState(() => _state = _controller.onResume());
  }

  Future<void> _persistProgress() async {
    final totalCompleted = _controller.totalCompleted;
    final recent =
        _controller.recentItems.map((item) => item.id).toList(growable: false);
    final progress = GameProgress(
      totalCompleted: totalCompleted,
      lastRecentItemIds: recent,
      lastPlayedAt: DateTime.now(),
      currentSetIndex: totalCompleted,
    );
    await widget.progressStore.save(progress);
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state is SolvingState) return _buildSolving(state);
    if (state is SolvedState) return _buildSolved(state);
    if (state is SetCompletedState) return _buildSetCompleted(state);
    if (state is RestingState) return _buildResting(state);
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Widget _buildSolving(SolvingState state) {
    final screenSize = MediaQuery.sizeOf(context);
    final columns = state.optionCount;
    final tileSize = min(144.0, (screenSize.width - 56) / columns);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              if (widget.result.hasPlaceholders) const _DemoBadge(),
              _SetIndicator(completedInSet: state.completedInSet, setSize: 5),
              const SizedBox(height: 6),
              Expanded(
                flex: 5,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 340,
                      maxWidth: 340,
                    ),
                    child: KeyedSubtree(
                      key: const ValueKey<String>('headline-image'),
                      child: Image.asset(
                        state.round.target.imagePath,
                        fit: BoxFit.contain,
                        semanticLabel: 'Find the matching silhouette for '
                            '${state.round.target.accessibilityLabel ?? state.round.target.id}',
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
                        for (final item in state.round.options)
                          _OptionTile(
                            optionKey: 'option-${item.id}',
                            item: item,
                            size: tileSize,
                            isCorrectChoice: false,
                            isWrongChoice: _wrongChoice == item.id,
                            onTap: () => _onChoice(item),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_handGuideEnabled && state.completedInSet == 0)
                HandGuide(
                  targetBox: Rect.fromCenter(
                    center: Offset(
                      screenSize.width / 2,
                      screenSize.height * 0.75,
                    ),
                    width: tileSize,
                    height: tileSize,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSolved(SolvedState state) {
    final screenSize = MediaQuery.sizeOf(context);
    final columns = state.optionCount;
    final tileSize = min(144.0, (screenSize.width - 56) / columns);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              _SetIndicator(completedInSet: state.completedInSet, setSize: 5),
              const SizedBox(height: 6),
              Expanded(
                flex: 5,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 340,
                      maxWidth: 340,
                    ),
                    child: SingleAssetEffect(
                      key: ValueKey(
                        'solved-${state.round.target.id}-${state.completedInSet}',
                      ),
                      item: state.round.target,
                      assetPath: state.round.target.imagePath,
                      onCompleted: _onEffectCompleted,
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
                        for (final item in state.round.options)
                          _OptionTile(
                            optionKey: 'option-${item.id}',
                            item: item,
                            size: tileSize,
                            isCorrectChoice: item.id == state.round.target.id,
                            isWrongChoice: false,
                            onTap: null,
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

  Widget _buildSetCompleted(SetCompletedState state) {
    return ReviewPlayArea(
      items: state.recentItems,
      onContinue: _onContinueFromSet,
      onRest: _onRestFromSet,
    );
  }

  Widget _buildResting(RestingState state) {
    return RestingScreen(
      items: state.recentItems,
      onResume: _onResumeFromRest,
    );
  }
}

/// Five-star strip that lights up `completedInSet / setSize`.
class _SetIndicator extends StatelessWidget {
  const _SetIndicator({required this.completedInSet, required this.setSize});

  final int completedInSet;
  final int setSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(setSize, (index) {
          final lit = index < completedInSet;
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
    );
  }
}

/// One tappable silhouette tile, shared between the Solving and Solved views.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.optionKey,
    required this.item,
    required this.size,
    required this.isCorrectChoice,
    required this.isWrongChoice,
    required this.onTap,
  });

  /// Stable key string used by integration tests to find this tile.
  final String optionKey;
  final ShadowItem item;
  final double size;
  final bool isCorrectChoice;
  final bool isWrongChoice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<String>(optionKey),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: size,
          height: size,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCorrectChoice
                ? const Color(0xFFD7F0DD)
                : isWrongChoice
                    ? const Color(0xFFFFE9C9)
                    : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE9E8DF), width: 2),
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
            semanticLabel:
                '${item.accessibilityLabel ?? item.id} silhouette',
          ),
        ),
      ),
    );
  }
}

/// Tiny badge shown only while [CatalogLoadResult.hasPlaceholders] is true.
/// Helps reviewers notice when a build was run with
/// `ENABLE_DEVELOPMENT_ASSETS=1`.
class _DemoBadge extends StatelessWidget {
  const _DemoBadge();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1DA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'DEMO / placeholder assets',
          style: TextStyle(fontSize: 12, color: Color(0xFF8A6E2F)),
        ),
      ),
    );
  }
}
