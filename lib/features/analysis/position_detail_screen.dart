import 'package:chess_trainer/core/lichess/explorer_result.dart';
import 'package:chess_trainer/features/analysis/explorer_provider.dart';
import 'package:chess_trainer/theme/app_theme.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Detail for one problem position: the board, a masters/lichess toggle, and the
// explorer's ranked candidate moves. Future home of "my games from here" and
// the play-out loop.
class PositionDetailScreen extends ConsumerStatefulWidget {
  const PositionDetailScreen({required this.fen, super.key});

  final String fen;

  @override
  ConsumerState<PositionDetailScreen> createState() =>
      _PositionDetailScreenState();
}

class _PositionDetailScreenState extends ConsumerState<PositionDetailScreen> {
  ExplorerSource _source = ExplorerSource.lichess;
  late final ChessboardController _boardController;
  late final bool _whiteToMove;
  late final Side _orientation;

  static const double _boardSize = 280;

  @override
  void initState() {
    super.initState();
    _whiteToMove = widget.fen.split(' ')[1] == 'w';
    _orientation = _whiteToMove ? Side.white : Side.black;
    _boardController = ChessboardController(
      game: GameData(
        fen: widget.fen,
        playerSide: PlayerSide.none,
        sideToMove: _whiteToMove ? Side.white : Side.black,
        validMoves: const <Square, Set<Square>>{},
      ),
    );
  }

  @override
  void dispose() {
    _boardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ExplorerQuery query = (fen: widget.fen, source: _source);
    final AsyncValue<ExplorerResult> explorer =
        ref.watch(explorerProvider(query));

    return Scaffold(
      appBar: AppBar(title: const Text('Position')),
      body: Column(
        children: <Widget>[
          const SizedBox(height: 16),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Chessboard(
                size: _boardSize,
                settings: AppTheme.boardSettings,
                controller: _boardController,
                orientation: _orientation,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SourceToggle(
            source: _source,
            onChanged: (ExplorerSource next) =>
                setState(() => _source = next),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: explorer.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace _) => _Message(
                icon: Icons.cloud_off_outlined,
                text: "Couldn't load moves.\n$e",
              ),
              data: (ExplorerResult result) =>
                  _MovesView(result: result, whiteToMove: _whiteToMove),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceToggle extends StatelessWidget {
  const _SourceToggle({required this.source, required this.onChanged});

  final ExplorerSource source;
  final ValueChanged<ExplorerSource> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ExplorerSource>(
      segments: const <ButtonSegment<ExplorerSource>>[
        ButtonSegment<ExplorerSource>(
          value: ExplorerSource.lichess,
          label: Text('Your level'),
        ),
        ButtonSegment<ExplorerSource>(
          value: ExplorerSource.masters,
          label: Text('Masters'),
        ),
      ],
      selected: <ExplorerSource>{source},
      onSelectionChanged: (Set<ExplorerSource> selection) =>
          onChanged(selection.first),
    );
  }
}

class _MovesView extends StatelessWidget {
  const _MovesView({required this.result, required this.whiteToMove});

  final ExplorerResult result;
  final bool whiteToMove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (result.moves.isEmpty) {
      return const _Message(
        icon: Icons.search_off_outlined,
        text: 'No games found for this position at this level.',
      );
    }
    final int positionTotal = result.total;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: <Widget>[
        if (result.opening != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              result.opening!.name,
              style: theme.textTheme.titleMedium,
            ),
          ),
        for (final ExplorerMove move in result.moves)
          _MoveRow(
            move: move,
            whiteToMove: whiteToMove,
            positionTotal: positionTotal,
          ),
      ],
    );
  }
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({
    required this.move,
    required this.whiteToMove,
    required this.positionTotal,
  });

  final ExplorerMove move;
  final bool whiteToMove;
  final int positionTotal;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Orient wins/losses to the side to move (the player), not to White.
    final int wins = whiteToMove ? move.white : move.black;
    final int losses = whiteToMove ? move.black : move.white;
    final int popularity =
        positionTotal == 0 ? 0 : ((move.total / positionTotal) * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 52,
            child: Text(
              move.san,
              style: AppTheme.mono(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      '${move.total} games',
                      style: AppTheme.mono(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$popularity%',
                      style: AppTheme.mono(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _WdlBar(wins: wins, draws: move.draws, losses: losses),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Win / draw / loss proportion bar, from the side-to-move's perspective.
class _WdlBar extends StatelessWidget {
  const _WdlBar({required this.wins, required this.draws, required this.losses});

  final int wins;
  final int draws;
  final int losses;

  static const Color _win = Color(0xFF6FA96F);
  static const Color _draw = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final int total = wins + draws + losses;
    if (total == 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Row(
        children: <Widget>[
          if (wins > 0) Expanded(flex: wins, child: _segment(_win)),
          if (draws > 0) Expanded(flex: draws, child: _segment(_draw)),
          if (losses > 0)
            Expanded(
              flex: losses,
              child: _segment(Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }

  Widget _segment(Color color) => Container(height: 8, color: color);
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
