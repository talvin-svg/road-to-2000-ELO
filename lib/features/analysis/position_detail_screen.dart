import 'package:chess_trainer/core/chess/fen.dart';
import 'package:chess_trainer/core/lichess/explorer_result.dart';
import 'package:chess_trainer/features/analysis/explorer_provider.dart';
import 'package:chess_trainer/features/repertoire/repertoire_controller.dart';
import 'package:chess_trainer/features/repertoire/repertoire_entry.dart';
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

  // Tapping a move commits it as this position's repertoire choice; tapping the
  // one that's already chosen clears it. ref.read (not watch) here — this is a
  // one-shot action, not something the callback needs to rebuild on.
  void _onPick(ExplorerMove move, bool isAlreadyPicked) {
    final RepertoireController controller =
        ref.read(repertoireControllerProvider.notifier);
    if (isAlreadyPicked) {
      controller.remove(widget.fen);
    } else {
      controller.pick(fen: widget.fen, uci: move.uci, san: move.san);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ExplorerQuery query = (fen: widget.fen, source: _source);
    final AsyncValue<ExplorerResult> explorer =
        ref.watch(explorerProvider(query));

    // The move (if any) already committed for THIS position. Watching the map
    // rebuilds the list the instant a pick changes; the shared normalizeFen is
    // how the lookup lines up with what the controller stored.
    final Map<String, RepertoireEntry> repertoire =
        ref.watch(repertoireControllerProvider);
    final RepertoireEntry? picked = repertoire[normalizeFen(widget.fen)];

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
              data: (ExplorerResult result) => _MovesView(
                result: result,
                whiteToMove: _whiteToMove,
                pickedUci: picked?.uci,
                onPick: _onPick,
              ),
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
  const _MovesView({
    required this.result,
    required this.whiteToMove,
    required this.pickedUci,
    required this.onPick,
  });

  final ExplorerResult result;
  final bool whiteToMove;
  // The UCI of this position's repertoire choice, or null if none picked yet.
  final String? pickedUci;
  final void Function(ExplorerMove move, bool isAlreadyPicked) onPick;

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
            isPicked: move.uci == pickedUci,
            onPick: onPick,
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
    required this.isPicked,
    required this.onPick,
  });

  final ExplorerMove move;
  final bool whiteToMove;
  final int positionTotal;
  // Whether this move is the one committed to the repertoire for this position.
  final bool isPicked;
  final void Function(ExplorerMove move, bool isAlreadyPicked) onPick;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Orient wins/losses to the side to move (the player), not to White.
    final int wins = whiteToMove ? move.white : move.black;
    final int losses = whiteToMove ? move.black : move.white;
    final int popularity =
        positionTotal == 0 ? 0 : ((move.total / positionTotal) * 100).round();

    return InkWell(
      onTap: () => onPick(move, isPicked),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        // A picked move gets a tinted, gold-outlined background so the chosen
        // reply stands out from the other candidates at a glance.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isPicked
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : null,
          border: Border.all(
            color: isPicked ? theme.colorScheme.primary : Colors.transparent,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
            // Trailing slot: a filled check when picked, keeping the row width
            // stable for unpicked rows with an equal-size placeholder.
            SizedBox(
              width: 32,
              child: isPicked
                  ? Icon(Icons.check_circle,
                      color: theme.colorScheme.primary, size: 22)
                  : null,
            ),
          ],
        ),
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
