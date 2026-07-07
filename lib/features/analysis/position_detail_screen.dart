import 'package:chess_trainer/core/lichess/explorer_result.dart';
import 'package:chess_trainer/features/analysis/explorer_provider.dart';
import 'package:chess_trainer/theme/app_theme.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Practice one problem position. The board is live: you play the move you'd
// actually play, and it's graded against the Lichess explorer. The strongest
// moves are drawn back onto the board as arrows, so you learn what's good by
// trying — not by reading a list. Nothing is saved; it's pure practice.
class PositionDetailScreen extends ConsumerStatefulWidget {
  const PositionDetailScreen({required this.fen, super.key});

  final String fen;

  @override
  ConsumerState<PositionDetailScreen> createState() =>
      _PositionDetailScreenState();
}

class _PositionDetailScreenState extends ConsumerState<PositionDetailScreen> {
  ExplorerSource _source = ExplorerSource.lichess;
  late final Position _position;
  late final Side _playerSide;
  late final ChessboardController _boardController;

  // The move the user last played (null until they move). _playedInDb is false
  // when the played move is legal but simply doesn't appear in the explorer.
  ExplorerMove? _played;
  bool _moved = false;
  bool _playedInDb = false;

  static const double _boardSize = 320;
  static const int _topCount = 3;

  // Semi-transparent so the piece underneath stays visible. Green = the single
  // most-played move; gold = the other top moves.
  static const Color _bestColor = Color(0xAA6FA96F);
  static const Color _otherColor = Color(0xAAC8A24B);

  @override
  void initState() {
    super.initState();
    // The FEN parsed once into a live position — the source of truth for whose
    // turn it is and which moves are legal.
    _position = Chess.fromSetup(Setup.parseFen(widget.fen));
    _playerSide = _position.turn;
    _boardController = ChessboardController(game: _interactiveGame());
  }

  @override
  void dispose() {
    _boardController.dispose();
    super.dispose();
  }

  // The live starting position: the side to move can play any legal move.
  GameData _interactiveGame() => GameData(
        fen: widget.fen,
        playerSide:
            _playerSide == Side.white ? PlayerSide.white : PlayerSide.black,
        sideToMove: _playerSide,
        validMoves: makeLegalMoves(_position),
      );

  // Called by chessground when the user completes a move. We don't apply it —
  // we snap the board back so the top-move arrows overlay the starting position
  // and the next attempt starts clean; we only record what was played.
  void _onMove(ExplorerResult result, Move move) {
    _boardController.updatePosition(_interactiveGame());
    final int index =
        result.moves.indexWhere((ExplorerMove m) => m.uci == move.uci);
    setState(() {
      _moved = true;
      _playedInDb = index >= 0;
      _played = index >= 0 ? result.moves[index] : null;
    });
  }

  void _changeSource(ExplorerSource next) {
    setState(() {
      _source = next;
      _moved = false;
      _played = null;
      _playedInDb = false;
    });
  }

  void _reset() {
    _boardController.updatePosition(_interactiveGame());
    setState(() {
      _moved = false;
      _played = null;
      _playedInDb = false;
    });
  }

  // Arrows + destination circles for the top moves, best-first. Only shown
  // after the user has moved, so the answers aren't given away up front.
  Set<Shape> _topShapes(ExplorerResult result) {
    final Set<Shape> shapes = <Shape>{};
    final List<ExplorerMove> top = result.moves.take(_topCount).toList();
    for (int i = 0; i < top.length; i++) {
      final NormalMove move = NormalMove.fromUci(top[i].uci);
      final Color color = i == 0 ? _bestColor : _otherColor;
      shapes.add(Arrow(color: color, orig: move.from, dest: move.to));
      shapes.add(Circle(color: color, orig: move.to));
    }
    return shapes;
  }

  @override
  Widget build(BuildContext context) {
    final ExplorerQuery query = (fen: widget.fen, source: _source);
    final AsyncValue<ExplorerResult> explorer =
        ref.watch(explorerProvider(query));
    final ExplorerResult? data = explorer.asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
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
                orientation: _playerSide,
                // Only gradeable once the explorer data has loaded.
                onMove: data == null
                    ? null
                    : (Move move, {bool? viaDragAndDrop}) =>
                        _onMove(data, move),
                shapes: (_moved && data != null)
                    ? _topShapes(data)
                    : const <Shape>{},
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SourceToggle(source: _source, onChanged: _changeSource),
          const SizedBox(height: 12),
          Expanded(
            child: explorer.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace _) => _Message(
                icon: Icons.cloud_off_outlined,
                text: "Couldn't load moves.\n$e",
              ),
              data: (ExplorerResult result) => _FeedbackPanel(
                result: result,
                whiteToMove: _playerSide == Side.white,
                moved: _moved,
                playedInDb: _playedInDb,
                played: _played,
                topCount: _topCount,
                bestColor: _bestColor,
                otherColor: _otherColor,
                onReset: _reset,
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

// Below-board panel: the verdict on the move you just played, plus a compact
// legend decoding the arrow colours to the top moves.
class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({
    required this.result,
    required this.whiteToMove,
    required this.moved,
    required this.playedInDb,
    required this.played,
    required this.topCount,
    required this.bestColor,
    required this.otherColor,
    required this.onReset,
  });

  final ExplorerResult result;
  final bool whiteToMove;
  final bool moved;
  final bool playedInDb;
  final ExplorerMove? played;
  final int topCount;
  final Color bestColor;
  final Color otherColor;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (result.moves.isEmpty) {
      return const _Message(
        icon: Icons.search_off_outlined,
        text: 'No games found for this position at this level.',
      );
    }
    final List<ExplorerMove> top = result.moves.take(topCount).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: <Widget>[
        _verdict(theme),
        const SizedBox(height: 20),
        Text(
          moved ? 'Strongest moves here' : 'Play a move to see the best options',
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        // The legend only decodes the arrows, so it's shown alongside them.
        if (moved)
          for (int i = 0; i < top.length; i++)
            _TopMoveRow(
              move: top[i],
              color: i == 0 ? bestColor : otherColor,
              positionTotal: result.total,
              whiteToMove: whiteToMove,
              isBest: i == 0,
            ),
      ],
    );
  }

  Widget _verdict(ThemeData theme) {
    if (!moved) {
      return _line(
        theme,
        Icons.touch_app_outlined,
        theme.colorScheme.onSurfaceVariant,
        'Your move — play the move you\'d make in a game.',
      );
    }
    if (!playedInDb || played == null) {
      return _line(
        theme,
        Icons.help_outline,
        theme.colorScheme.onSurfaceVariant,
        "That move barely appears here — the arrows show what's usually played.",
      );
    }
    final ExplorerMove move = played!;
    final int popularity =
        result.total == 0 ? 0 : ((move.total / result.total) * 100).round();
    final int wins = whiteToMove ? move.white : move.black;
    final int score = move.total == 0
        ? 0
        : (((wins + move.draws / 2) / move.total) * 100).round();
    final bool isTop = move.uci == result.moves.first.uci;
    return _line(
      theme,
      isTop ? Icons.check_circle : Icons.info_outline,
      isTop ? bestColor : theme.colorScheme.onSurfaceVariant,
      isTop
          ? 'You played ${move.san} — the most popular move here '
              '($popularity%), scoring $score% for you.'
          : 'You played ${move.san} — played $popularity% here, '
              'scoring $score% for you.',
    );
  }

  Widget _line(ThemeData theme, IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(color: color),
          ),
        ),
        if (moved)
          IconButton(
            tooltip: 'Reset',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: onReset,
          ),
      ],
    );
  }
}

// One entry in the top-moves legend: a colour swatch matching its board arrow,
// the SAN, and how often it's played.
class _TopMoveRow extends StatelessWidget {
  const _TopMoveRow({
    required this.move,
    required this.color,
    required this.positionTotal,
    required this.whiteToMove,
    required this.isBest,
  });

  final ExplorerMove move;
  final Color color;
  final int positionTotal;
  final bool whiteToMove;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int popularity =
        positionTotal == 0 ? 0 : ((move.total / positionTotal) * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          // Solid swatch of the arrow colour (drop the transparency so it reads).
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color.withAlpha(0xFF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
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
          if (isBest)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('best',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          const Spacer(),
          Text(
            '$popularity%',
            style: AppTheme.mono(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
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
