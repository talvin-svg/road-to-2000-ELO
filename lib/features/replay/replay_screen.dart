import 'package:chessground/chessground.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/chess/game_replay.dart';
import 'replay_controller.dart';
import 'replay_state.dart';

const double _boardSize = 480;

class ReplayScreen extends ConsumerStatefulWidget {
  const ReplayScreen({super.key});

  @override
  ConsumerState<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends ConsumerState<ReplayScreen> {
  late final ChessboardController _boardController;

  @override
  void initState() {
    super.initState();
    _boardController = ChessboardController(game: _gameDataFor(ref.read(replayControllerProvider)));
  }

  @override
  void dispose() {
    _boardController.dispose();
    super.dispose();
  }

  // The board never receives moves directly (`playerSide: none`) since this
  // screen only replays a fixed game; Milestone 4 will flip this to let the
  // trainee actually play a side.
  GameData _gameDataFor(ReplayState s) => GameData(
    fen: s.fen,
    lastMove: s.lastMove,
    playerSide: PlayerSide.none,
    sideToMove: s.sideToMove,
    kingSquareInCheck: s.checkedKingSquare,
    validMoves: const {},
  );

  @override
  Widget build(BuildContext context) {
    // Bridges Riverpod state into the imperative ChessboardController:
    // single steps animate, multi-ply jumps (start/end/move-list tap) don't.
    ref.listen<ReplayState>(replayControllerProvider, (previous, next) {
      final isSingleStep = previous != null && (next.currentPly - previous.currentPly).abs() == 1;
      _boardController.updatePosition(_gameDataFor(next), animate: isSingleStep);
    });

    final state = ref.watch(replayControllerProvider);
    final controller = ref.read(replayControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess Trainer'),
        actions: [
          IconButton(
            tooltip: 'Flip board',
            icon: const Icon(Icons.swap_vert),
            onPressed: controller.flipBoard,
          ),
        ],
      ),
      // Wrapped in a scroll view + a fixed-height SizedBox so a short window
      // (or a later mobile layout) scrolls instead of throwing a RenderFlex
      // overflow: the sidebar's Expanded move list needs a bounded height to
      // lay out against, and ambient constraints alone don't guarantee one.
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: _boardSize,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chessboard(
                      size: _boardSize,
                      controller: _boardController,
                      orientation: state.orientation,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: _MoveList(
                              plies: state.game.plies,
                              currentPly: state.currentPly,
                              onSelectPly: controller.jumpTo,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _ReplayControls(state: state, controller: controller),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplayControls extends StatelessWidget {
  const _ReplayControls({required this.state, required this.controller});

  final ReplayState state;
  final ReplayController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Jump to start',
          icon: const Icon(Icons.skip_previous),
          onPressed: state.canGoToPrevious ? controller.goToStart : null,
        ),
        IconButton(
          tooltip: 'Previous move',
          icon: const Icon(Icons.chevron_left),
          onPressed: state.canGoToPrevious ? controller.goToPrevious : null,
        ),
        IconButton(
          tooltip: 'Next move',
          icon: const Icon(Icons.chevron_right),
          onPressed: state.canGoToNext ? controller.goToNext : null,
        ),
        IconButton(
          tooltip: 'Jump to end',
          icon: const Icon(Icons.skip_next),
          onPressed: state.canGoToNext ? controller.goToEnd : null,
        ),
      ],
    );
  }
}

class _MoveList extends StatelessWidget {
  const _MoveList({required this.plies, required this.currentPly, required this.onSelectPly});

  final List<PlyRecord> plies;
  final int currentPly;
  final ValueChanged<int> onSelectPly;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: (plies.length / 2).ceil(),
        itemBuilder: (context, rowIndex) {
          final whitePly = rowIndex * 2 + 1;
          final blackPly = whitePly + 1;
          final white = plies[whitePly - 1];
          final black = blackPly <= plies.length ? plies[blackPly - 1] : null;

          return Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('${rowIndex + 1}.', style: Theme.of(context).textTheme.bodySmall),
              ),
              _MoveLabel(
                san: white.san,
                selected: currentPly == whitePly,
                onTap: () => onSelectPly(whitePly),
              ),
              if (black != null)
                _MoveLabel(
                  san: black.san,
                  selected: currentPly == blackPly,
                  onTap: () => onSelectPly(blackPly),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MoveLabel extends StatelessWidget {
  const _MoveLabel({required this.san, required this.selected, required this.onTap});

  final String san;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(san),
      ),
    );
  }
}
