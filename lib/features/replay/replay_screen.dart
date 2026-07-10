import 'dart:math' as math;

import 'package:chessground/chessground.dart';
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
import 'package:chess_trainer/widgets/transport_button.dart';

// Standalone screen — wraps ReplayBody with an AppBar that has flip/logout/etc.
// The shell uses ReplayBody directly, with flip wired into the shell header.
class ReplayScreen extends ConsumerStatefulWidget {
  const ReplayScreen({super.key});

  @override
  ConsumerState<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends ConsumerState<ReplayScreen> {
  Future<void> _confirmLogout(BuildContext context) async {
    final Future<void> Function() doLogout =
        ref.read(importControllerProvider.notifier).clearUser;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'This clears your username and everything in your analysis pool.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await doLogout();
  }

  @override
  Widget build(BuildContext context) {
    final ReplayState state = ref.watch(replayControllerProvider);
    final ReplayController controller =
        ref.read(replayControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game replay'),
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
              ref.read(importControllerProvider.notifier).backToMonths();
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ImportScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Analyze positions',
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AnalysisScreen(),
              ),
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
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: const ReplayBody(),
    );
  }
}

// Reusable body — used by ReplayScreen and AppShell's replay section.
// Shows an empty state when no game is loaded.
class ReplayBody extends ConsumerStatefulWidget {
  const ReplayBody({super.key});

  @override
  ConsumerState<ReplayBody> createState() => _ReplayBodyState();
}

class _ReplayBodyState extends ConsumerState<ReplayBody> {
  late ChessboardController _boardController;

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
    ref.listen<ReplayState>(replayControllerProvider, (
      ReplayState? previous,
      ReplayState next,
    ) {
      final bool isSingleStep = previous != null &&
          (next.currentPly - previous.currentPly).abs() == 1;
      _boardController.updatePosition(_gameDataFor(next), animate: isSingleStep);
    });

    final ReplayState state = ref.watch(replayControllerProvider);
    final ReplayController controller =
        ref.read(replayControllerProvider.notifier);

    if (state.game == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'No game loaded',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Import a game and select it to start replaying.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final GameReplay game = state.game!;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double boardSize =
            math.min(constraints.maxWidth - 40, 360);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${game.whitePlayer} vs ${game.blackPlayer}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Chessboard(
                      size: boardSize,
                      settings: AppTheme.boardSettings,
                      controller: _boardController,
                      orientation: state.orientation,
                    ),
                  ),
                ),
                Expanded(
                  child: _MoveList(
                    plies: game.plies,
                    currentPly: state.currentPly,
                    onSelectPly: controller.jumpTo,
                    result: game.result,
                    whitePlayer: game.whitePlayer,
                    blackPlayer: game.blackPlayer,
                  ),
                ),
                _TransportBar(state: state, controller: controller),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Transport bar ─────────────────────────────────────────────────────────────
class _TransportBar extends StatelessWidget {
  const _TransportBar({required this.state, required this.controller});

  final ReplayState state;
  final ReplayController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.line)),
        ),
        child: Row(
          children: <Widget>[
            TransportButton(
              icon: Icons.first_page,
              flex: 1,
              onPressed:
                  state.canGoToPrevious ? controller.goToStart : null,
            ),
            const SizedBox(width: 8),
            TransportButton(
              icon: Icons.chevron_left,
              flex: 1,
              onPressed:
                  state.canGoToPrevious ? controller.goToPrevious : null,
            ),
            const SizedBox(width: 8),
            TransportButton(
              icon: Icons.chevron_right,
              flex: 2,
              primary: true,
              onPressed: state.canGoToNext ? controller.goToNext : null,
            ),
            const SizedBox(width: 8),
            TransportButton(
              icon: Icons.last_page,
              flex: 1,
              onPressed: state.canGoToNext ? controller.goToEnd : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Move list ─────────────────────────────────────────────────────────────────
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
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: moveRows + 1,
      itemBuilder: (BuildContext context, int rowIndex) {
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
          children: <Widget>[
            SizedBox(
              width: 30,
              child: Text(
                '${rowIndex + 1}.',
                textAlign: TextAlign.right,
                style: AppTheme.mono(fontSize: 13, color: AppTheme.faint),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MoveLabel(
                san: white.san,
                isWhiteMove: true,
                selected: currentPly == whitePly,
                onTap: () => onSelectPly(whitePly),
              ),
            ),
            Expanded(
              child: black == null
                  ? const SizedBox.shrink()
                  : _MoveLabel(
                      san: black.san,
                      isWhiteMove: false,
                      selected: currentPly == blackPly,
                      onTap: () => onSelectPly(blackPly),
                    ),
            ),
          ],
        );
      },
    );
  }
}

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
    final (String headline, String? detail) = switch (result) {
      '1-0' => ('White wins', '$whitePlayer def. $blackPlayer'),
      '0-1' => ('Black wins', '$blackPlayer def. $whitePlayer'),
      '1/2-1/2' => ('Draw', '$whitePlayer  vs  $blackPlayer'),
      _ => ('Game unfinished', null),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(height: 20),
        Row(
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
      ],
    );
  }
}

class _MoveLabel extends StatelessWidget {
  const _MoveLabel({
    required this.san,
    required this.isWhiteMove,
    required this.selected,
    required this.onTap,
  });

  final String san;
  final bool isWhiteMove;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color gold = theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? gold.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          san,
          style: AppTheme.mono(
            fontSize: 13,
            fontWeight: selected
                ? FontWeight.w700
                : (isWhiteMove ? FontWeight.w600 : FontWeight.w400),
            color: selected
                ? gold
                : (isWhiteMove
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
