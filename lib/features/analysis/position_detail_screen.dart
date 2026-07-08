import 'dart:math';

import 'package:chess_trainer/core/lichess/explorer_result.dart';
import 'package:chess_trainer/features/analysis/explorer_provider.dart';
import 'package:chess_trainer/theme/app_theme.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Play a problem position out as a whole line. The board is live: you play the
// move you'd actually play and it's graded against the Lichess explorer, then
// the app replies as a ~1000-rated opponent — a weighted-random pick from what
// real players at that level actually play in the resulting position (no engine;
// the explorer's low rating band IS a sample of 1000-level human games). The
// line runs until it leaves book (no games at this level) or the game ends.
// Nothing is saved; it's pure practice.
class PositionDetailScreen extends ConsumerStatefulWidget {
  const PositionDetailScreen({required this.fen, super.key});

  final String fen;

  @override
  ConsumerState<PositionDetailScreen> createState() =>
      _PositionDetailScreenState();
}

class _PositionDetailScreenState extends ConsumerState<PositionDetailScreen> {
  ExplorerSource _source = ExplorerSource.lichess;

  // Mutable now — the position advances as the line is played out. (It was
  // `late final` when the board only ever snapped back to the start.)
  late Position _position;
  // Your side for the whole line: whoever was to move in the starting position.
  late final Side _playerSide;
  // The explorer query key; tracks _position as moves are played.
  late String _currentFen;
  late final ChessboardController _boardController;

  final Random _random = Random();

  // The line so far, in SAN. Even plies (0,2,4…) are your moves — you always
  // move first from the starting position — odd plies are the opponent's.
  final List<String> _sans = <String>[];

  // Feedback about YOUR most recent move. Captured at move time against the
  // position you played it in (_gradedResult), because once the line advances
  // the board's current explorer result is for a different position.
  ExplorerResult? _gradedResult;
  ExplorerMove? _played;
  bool _moved = false;
  bool _playedInDb = false;

  // The opponent is fetching/playing its reply — board is locked meanwhile.
  bool _opponentThinking = false;
  // The line has ended (mate/stalemate, out of book, or a load failure).
  bool _lineOver = false;
  String? _lineOverReason;

  // The best-move hint. When you miss the top move, we hold the pre-move
  // position for a beat and draw two arrows — your move vs the move you should
  // have played — so a miss is something you SEE, not just read. Non-empty only
  // during that flash; _hintLocked locks the board while it shows (the board is
  // still on your position, so without the lock you could fire a second move
  // over the arrows). This is the arrow feedback the snap-back → play-out switch
  // had removed.
  Set<Shape> _hintShapes = <Shape>{};
  bool _hintLocked = false;

  static const double _boardSize = 320;

  // Best move (what you should have played) in green; your move in the theme's
  // warm loss-rate red — the two colours read as "right vs wrong" at a glance.
  static const Color _bestArrow = Color(0xCC5FB07A);
  static const Color _yourArrow = Color(0xCCD9646B);

  @override
  void initState() {
    super.initState();
    // The FEN parsed once into a live position — the source of truth for whose
    // turn it is and which moves are legal.
    _position = Chess.fromSetup(Setup.parseFen(widget.fen));
    _playerSide = _position.turn;
    _currentFen = widget.fen;
    _boardController = ChessboardController(game: _gameForCurrent());
  }

  @override
  void dispose() {
    _boardController.dispose();
    super.dispose();
  }

  // The board's view of the current position. It's draggable only when it's
  // your turn and the line is still live (not while the opponent is replying,
  // and not after the line has ended).
  GameData _gameForCurrent() {
    final bool interactive = !_opponentThinking &&
        !_lineOver &&
        !_hintLocked &&
        _position.turn == _playerSide;
    return GameData(
      fen: _currentFen,
      playerSide: interactive
          ? (_playerSide == Side.white ? PlayerSide.white : PlayerSide.black)
          : PlayerSide.none,
      sideToMove: _position.turn,
      validMoves: makeLegalMoves(_position),
    );
  }

  // Called by chessground when you complete a legal move. [result] is the
  // explorer data for the position you moved in (your turn) — grade against it,
  // then apply the move and hand over to the opponent.
  Future<void> _onUserMove(ExplorerResult result, Move move) async {
    final int index =
        result.moves.indexWhere((ExplorerMove m) => m.uci == move.uci);
    final bool missedTop =
        result.moves.isNotEmpty && move.uci != result.moves.first.uci;
    setState(() {
      _moved = true;
      _playedInDb = index >= 0;
      _played = index >= 0 ? result.moves[index] : null;
      _gradedResult = result;
    });
    // Missed the top move → flash it against yours on the position you played
    // in, before the line advances past it. Play it on the nose and nothing
    // flashes — quiet reinforcement, no nagging.
    if (missedTop) {
      await _flashBestMove(yours: move, best: result.moves.first);
      if (!mounted) return;
    }
    _applyMove(move);
    _opponentReply();
  }

  // Hold the current (pre-move) position and draw your move vs the top move for
  // a beat, so the miss is visible against the very position it happened in. The
  // board is locked meanwhile; the arrows clear before your move is applied, so
  // they never linger on the advanced position.
  Future<void> _flashBestMove({
    required Move yours,
    required ExplorerMove best,
  }) async {
    final NormalMove yourMove = yours as NormalMove;
    final NormalMove bestMove = NormalMove.fromUci(best.uci);
    setState(() {
      _hintLocked = true;
      _hintShapes = <Shape>{
        Arrow(color: _yourArrow, orig: yourMove.from, dest: yourMove.to),
        Arrow(color: _bestArrow, orig: bestMove.from, dest: bestMove.to),
      };
    });
    _boardController.updatePosition(_gameForCurrent());
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() {
      _hintLocked = false;
      _hintShapes = <Shape>{};
    });
  }

  // Advance the live position by one move, record its SAN, and push the new
  // position to the board. makeSan gives the new Position and the SAN in one
  // call — the SAN has to be read before the move is played.
  void _applyMove(Move move) {
    final (Position next, String san) = _position.makeSan(move);
    setState(() {
      _position = next;
      _currentFen = _position.fen;
      _sans.add(san);
    });
    _boardController.updatePosition(_gameForCurrent());
  }

  // The opponent's turn: fetch the explorer for the current position, pick a
  // reply the way a ~1000 would (weighted by how often each move is played),
  // and play it. Ends the line on mate/stalemate, out of book, or load failure.
  Future<void> _opponentReply() async {
    if (_position.isGameOver) {
      _endLine(_outcomeText());
      return;
    }
    setState(() => _opponentThinking = true);
    _boardController.updatePosition(_gameForCurrent());
    // A beat so the reply doesn't snap in instantly — reads as a move, not a
    // glitch. Also covers the network round-trip.
    await Future<void>.delayed(const Duration(milliseconds: 450));

    try {
      final ExplorerResult after = await ref.read(
        explorerProvider((fen: _currentFen, source: _source)).future,
      );
      if (!mounted) return;
      if (after.moves.isEmpty) {
        _endLine(
          "Out of book — no games at this level here. You're on your own now.",
        );
        return;
      }
      setState(() => _opponentThinking = false);
      final ExplorerMove reply = _weightedPick(after.moves);
      _applyMove(NormalMove.fromUci(reply.uci));

      // Back to your turn. If mate/stalemate, or the position has no book for
      // your next move, the line is over.
      if (_position.isGameOver) {
        _endLine(_outcomeText());
        return;
      }
      final ExplorerResult yours = await ref.read(
        explorerProvider((fen: _currentFen, source: _source)).future,
      );
      if (!mounted) return;
      if (yours.moves.isEmpty) {
        _endLine(
          "Out of book — no games at this level here. You're on your own now.",
        );
      }
    } on Object catch (e) {
      if (!mounted) return;
      _endLine("Couldn't load the opponent's reply.\n$e");
    }
  }

  // Pick a move weighted by how often it's played, so common moves come up
  // often and rare ones occasionally — a realistic 1000, not a fixed book line.
  ExplorerMove _weightedPick(List<ExplorerMove> moves) {
    final int totalGames =
        moves.fold(0, (int sum, ExplorerMove m) => sum + m.total);
    if (totalGames == 0) return moves.first;
    int roll = _random.nextInt(totalGames);
    for (final ExplorerMove m in moves) {
      roll -= m.total;
      if (roll < 0) return m;
    }
    return moves.last;
  }

  void _endLine(String reason) {
    setState(() {
      _opponentThinking = false;
      _lineOver = true;
      _lineOverReason = reason;
    });
    _boardController.updatePosition(_gameForCurrent());
  }

  // Whose turn it is has been checkmated / it's a draw — phrase it from your POV.
  String _outcomeText() {
    if (_position.isCheckmate) {
      final bool youGotMated = _position.turn == _playerSide;
      return youGotMated
          ? 'Checkmate — you got mated.'
          : 'Checkmate — you delivered mate!';
    }
    return 'Game over — a draw (stalemate or insufficient material).';
  }

  // Switching the opponent pool changes both grading and replies, so restart
  // the line from the top on the new database.
  void _changeSource(ExplorerSource next) {
    setState(() {
      _source = next;
    });
    _reset();
  }

  void _reset() {
    _position = Chess.fromSetup(Setup.parseFen(widget.fen));
    setState(() {
      _currentFen = widget.fen;
      _sans.clear();
      _gradedResult = null;
      _played = null;
      _moved = false;
      _playedInDb = false;
      _opponentThinking = false;
      _lineOver = false;
      _lineOverReason = null;
      _hintLocked = false;
      _hintShapes = <Shape>{};
    });
    _boardController.updatePosition(_gameForCurrent());
  }

  @override
  Widget build(BuildContext context) {
    final ExplorerQuery query = (fen: _currentFen, source: _source);
    final AsyncValue<ExplorerResult> explorer =
        ref.watch(explorerProvider(query));
    final ExplorerResult? data = explorer.asData?.value;
    final bool yourTurn = _position.turn == _playerSide;
    // The board only accepts moves when it's your live turn and the explorer
    // for this position has loaded (we need it to grade against).
    final bool canMove = yourTurn &&
        !_lineOver &&
        !_opponentThinking &&
        !_hintLocked &&
        data != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Play the line'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Restart line',
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
          ),
        ],
      ),
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
                shapes: _hintShapes,
                onMove: !canMove
                    ? null
                    : (Move move, {bool? viaDragAndDrop}) =>
                        _onUserMove(data, move),
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
                gradedResult: _gradedResult,
                played: _played,
                moved: _moved,
                playedInDb: _playedInDb,
                whiteToMove: _playerSide == Side.white,
                opponentThinking: _opponentThinking,
                lineOver: _lineOver,
                lineOverReason: _lineOverReason,
                sans: _sans,
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

// Below-board panel: the verdict on the move you just played (or the line-over
// banner), plus the running move list.
class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({
    required this.gradedResult,
    required this.played,
    required this.moved,
    required this.playedInDb,
    required this.whiteToMove,
    required this.opponentThinking,
    required this.lineOver,
    required this.lineOverReason,
    required this.sans,
  });

  final ExplorerResult? gradedResult;
  final ExplorerMove? played;
  final bool moved;
  final bool playedInDb;
  final bool whiteToMove;
  final bool opponentThinking;
  final bool lineOver;
  final String? lineOverReason;
  final List<String> sans;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: <Widget>[
        _status(theme),
        if (sans.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          Text(
            'Line so far',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          _MoveList(sans: sans),
        ],
      ],
    );
  }

  // The one-line headline: line-over banner > opponent thinking > your verdict >
  // the initial prompt.
  Widget _status(ThemeData theme) {
    if (lineOver) {
      return _line(theme, Icons.flag_outlined, theme.colorScheme.primary,
          lineOverReason ?? 'Line over.');
    }
    if (opponentThinking) {
      return _line(theme, Icons.more_horiz, theme.colorScheme.onSurfaceVariant,
          'Opponent is replying…');
    }
    if (!moved || gradedResult == null) {
      return _line(theme, Icons.touch_app_outlined,
          theme.colorScheme.onSurfaceVariant,
          "Your move — play the move you'd make in a game.");
    }
    return _verdict(theme, gradedResult!);
  }

  Widget _verdict(ThemeData theme, ExplorerResult result) {
    final String? bestSan =
        result.moves.isNotEmpty ? result.moves.first.san : null;
    if (!playedInDb || played == null) {
      return _line(
        theme,
        Icons.help_outline,
        theme.colorScheme.onSurfaceVariant,
        bestSan == null
            ? 'That move is rare at this level.'
            : 'That move is rare at this level — the main move was $bestSan.',
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
      isTop ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
      isTop
          ? 'You played ${move.san} — the main move here '
              '($popularity%), scoring $score% for you.'
          : 'You played ${move.san} — a sideline ($popularity%, scoring '
              '$score% for you). The main move was $bestSan.',
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
      ],
    );
  }
}

// The line so far as mono SAN chips. Your moves (even plies) are gold, the
// opponent's (odd plies) muted — so at a glance you can see which were yours.
class _MoveList extends StatelessWidget {
  const _MoveList({required this.sans});

  final List<String> sans;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (int i = 0; i < sans.length; i++)
          Text(
            sans[i],
            style: AppTheme.mono(
              fontSize: 15,
              fontWeight: i.isEven ? FontWeight.w700 : FontWeight.w400,
              color: i.isEven
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
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
