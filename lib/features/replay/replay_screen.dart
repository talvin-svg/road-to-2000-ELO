import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_trainer/core/chess/game_replay.dart';
import 'package:chess_trainer/features/analysis/analysis_screen.dart';
import 'package:chess_trainer/features/analysis/position_detail_screen.dart';
import 'package:chess_trainer/features/import_game/import_controller.dart';
import 'package:chess_trainer/features/import_game/import_screen.dart';
import 'package:chess_trainer/features/replay/replay_controller.dart';
import 'package:chess_trainer/features/replay/replay_state.dart';
import 'package:chess_trainer/theme/app_theme.dart';

const double _boardSize = 480;
const double _playerLabelHeight = 32;

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
    _boardController = ChessboardController(
      game: _gameDataFor(ref.read(replayControllerProvider)),
    );
  }

  @override
  void dispose() {
    _boardController.dispose();
    super.dispose();
  }

  // Confirm before logging out — clearUser wipes the username and the whole
  // analysis pool. On confirm, clearGame() nulls the replay game, so AppRouter
  // swaps back to the import screen at the username entry step.
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'This clears your username and everything in your analysis pool.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(importControllerProvider.notifier).clearUser();
    }
  }

  // The board never receives moves directly (`playerSide: none`) since this
  // screen only replays a fixed game; Milestone 4 will flip this to let the
  // trainee actually play a side.
  GameData _gameDataFor(ReplayState state) => GameData(
    fen: state.fen,
    lastMove: state.lastMove,
    playerSide: PlayerSide.none,
    sideToMove: state.sideToMove,
    kingSquareInCheck: state.checkedKingSquare,
    validMoves: const {},
  );

  @override
  Widget build(BuildContext context) {
    // Bridges Riverpod state into the imperative ChessboardController:
    // single steps animate, multi-ply jumps (start/end/move-list tap) don't.
    ref.listen<ReplayState>(replayControllerProvider, (previous, next) {
      final bool isSingleStep =
          previous != null &&
          (next.currentPly - previous.currentPly).abs() == 1;
      _boardController.updatePosition(
        _gameDataFor(next),
        animate: isSingleStep,
      );
    });

    final ReplayState state = ref.watch(replayControllerProvider);
    final ReplayController controller = ref.read(
      replayControllerProvider.notifier,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess Trainer'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Play from here',
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => PositionDetailScreen(fen: state.fen),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Pick another game',
            icon: const Icon(Icons.grid_view),
            onPressed: () {
              // Land on the month list (not the leftover game list): reset the
              // import flow back to months, then open it over the replay screen.
              ref.read(importControllerProvider.notifier).backToMonths();
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const ImportScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Analyze positions',
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const AnalysisScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Flip board',
            icon: const Icon(Icons.swap_vert),
            onPressed: controller.flipBoard,
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context, ref),
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
                height: _boardSize + _playerLabelHeight * 2 + 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PlayerLabel(
                          name: state.orientation == Side.white
                              ? state.game!.blackPlayer
                              : state.game!.whitePlayer,
                          isWhitePiece: state.orientation != Side.white,
                        ),
                        const SizedBox(height: 8),
                        Chessboard(
                          size: _boardSize,
                          settings: AppTheme.boardSettings,
                          controller: _boardController,
                          orientation: state.orientation,
                        ),
                        const SizedBox(height: 8),
                        _PlayerLabel(
                          name: state.orientation == Side.white
                              ? state.game!.whitePlayer
                              : state.game!.blackPlayer,
                          isWhitePiece: state.orientation == Side.white,
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: _MoveList(
                              plies: state.game!.plies,
                              currentPly: state.currentPly,
                              onSelectPly: controller.jumpTo,
                              result: state.game!.result,
                              whitePlayer: state.game!.whitePlayer,
                              blackPlayer: state.game!.blackPlayer,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
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
        ),
        TextButton.icon(
          onPressed: state.canGoToPrevious ? controller.goToStart : null,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Reset'),
        ),
      ],
    );
  }
}

class _MoveList extends StatelessWidget {
  const _MoveList({
    required this.plies,
    required this.currentPly,
    required this.onSelectPly,
    required this.result,
    required this.whitePlayer,
    required this.blackPlayer,
  });

  final List<PlyRecord> plies;
  final int currentPly;
  final ValueChanged<int> onSelectPly;
  final String result;
  final String whitePlayer;
  final String blackPlayer;

  @override
  Widget build(BuildContext context) {
    final int moveRows = (plies.length / 2).ceil();
    return Card(
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        // One extra row after the moves for the result footer.
        itemCount: moveRows + 1,
        itemBuilder: (context, rowIndex) {
          if (rowIndex == moveRows) {
            return _ResultFooter(
              result: result,
              whitePlayer: whitePlayer,
              blackPlayer: blackPlayer,
            );
          }
          final int whitePly = rowIndex * 2 + 1;
          final int blackPly = whitePly + 1;
          final PlyRecord white = plies[whitePly - 1];
          final PlyRecord? black =
              blackPly <= plies.length ? plies[blackPly - 1] : null;

          return Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '${rowIndex + 1}.',
                  style: AppTheme.mono(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
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

// Shown at the very end of the move list: the game outcome and who beat whom.
class _ResultFooter extends StatelessWidget {
  const _ResultFooter({
    required this.result,
    required this.whitePlayer,
    required this.blackPlayer,
  });

  final String result;
  final String whitePlayer;
  final String blackPlayer;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // headline = the outcome; detail = who won / lost.
    final (String headline, String? detail) = switch (result) {
      '1-0' => ('White wins', '$whitePlayer def. $blackPlayer'),
      '0-1' => ('Black wins', '$blackPlayer def. $whitePlayer'),
      '1/2-1/2' => ('Draw', '$whitePlayer  vs  $blackPlayer'),
      _ => ('Game unfinished', null),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                result == '*' ? '—' : result,
                style: AppTheme.mono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(headline, style: theme.textTheme.titleSmall),
                    if (detail != null)
                      Text(
                        detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerLabel extends StatelessWidget {
  const _PlayerLabel({required this.name, required this.isWhitePiece});

  final String name;
  final bool isWhitePiece;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _playerLabelHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isWhitePiece ? Colors.white : Colors.black,
              border: Border.all(color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(width: 8),
          Text(name, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _MoveLabel extends StatelessWidget {
  const _MoveLabel({
    required this.san,
    required this.selected,
    required this.onTap,
  });

  final String san;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          san,
          style: AppTheme.mono(
            fontSize: 13,
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
