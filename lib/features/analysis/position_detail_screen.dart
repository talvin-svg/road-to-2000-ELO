import 'package:chess_trainer/core/engine/stockfish_engine.dart';
import 'package:chess_trainer/theme/app_theme.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Play a problem position out as a whole line against Stockfish.
// You play the move you'd actually play; Stockfish replies. The line runs
// until mate/stalemate or the engine returns no move (terminal position).
// Nothing is saved — pure practice.
class PositionDetailScreen extends ConsumerStatefulWidget {
  const PositionDetailScreen({required this.fen, super.key});

  final String fen;

  @override
  ConsumerState<PositionDetailScreen> createState() =>
      _PositionDetailScreenState();
}

class _PositionDetailScreenState extends ConsumerState<PositionDetailScreen> {
  // Engine is created once per screen visit and disposed on exit. The package
  // is a hard singleton, so disposing on exit is required — the next visit
  // would throw if an instance were still alive.
  final StockfishEngine _engine = StockfishEngine();

  bool _engineReady = false;

  // The live position — advances as moves are played (was `late final` when
  // the board snapped back after every move; now mutable because the line plays out).
  late Position _position;
  // Whoever was on move in the starting position — your side for the whole line.
  late final Side _playerSide;
  // Always kept in sync with _position.fen after every _applyMove.
  late String _currentFen;
  late final ChessboardController _boardController;

  // The line so far in SAN. Even indices (0, 2, 4, …) are your moves;
  // odd indices are Stockfish's replies.
  final List<String> _sans = <String>[];

  // Board-lock flags. The board accepts moves only when all three are false
  // and it's your turn.
  bool _engineThinking = false;
  bool _lineOver = false;
  String? _lineOverReason;

  static const double _boardSize = 320;

  @override
  void initState() {
    super.initState();
    _position = Chess.fromSetup(Setup.parseFen(widget.fen));
    _playerSide = _position.turn;
    _currentFen = widget.fen;
    _boardController = ChessboardController(game: _gameForCurrent());
    _startEngine();
  }

  @override
  void dispose() {
    _engine.dispose();
    _boardController.dispose();
    super.dispose();
  }

  Future<void> _startEngine() async {
    await _engine.start();
    if (!mounted) return;
    setState(() => _engineReady = true);
    _boardController.updatePosition(_gameForCurrent());
  }

  // The board's live GameData: interactive only when the engine is ready,
  // it's your turn, and the line is still running.
  GameData _gameForCurrent() {
    final bool interactive = _engineReady &&
        !_engineThinking &&
        !_lineOver &&
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

  // Advance the live position by one move and record its SAN. makeSan returns
  // (newPosition, san) in one call — the SAN must be read before the move is
  // applied, which is why the API bundles both together.
  void _applyMove(Move move) {
    final (Position next, String san) = _position.makeSan(move);
    setState(() {
      _position = next;
      _currentFen = _position.fen;
      _sans.add(san);
    });
    _boardController.updatePosition(_gameForCurrent());
  }

  // chessground fires this when you complete a legal drag/click move.
  Future<void> _onUserMove(Move move, {bool? viaDragAndDrop}) async {
    _applyMove(move);
    await _engineTurn();
  }

  // Stockfish's turn: evaluate the current position, play the best move back,
  // then check if the game is over (for your next turn).
  Future<void> _engineTurn() async {
    if (_position.isGameOver) {
      _endLine(_outcomeText());
      return;
    }

    setState(() => _engineThinking = true);
    _boardController.updatePosition(_gameForCurrent());

    try {
      final EngineEval eval = await _engine.evaluate(_currentFen);

      if (!mounted) return;

      // Empty bestMove means the engine sees a terminal position (shouldn't
      // normally reach here after the isGameOver check, but handled defensively).
      if (eval.bestMove.isEmpty) {
        _endLine(_outcomeText());
        return;
      }

      setState(() => _engineThinking = false);
      _applyMove(NormalMove.fromUci(eval.bestMove));

      // Check if the game ended after Stockfish's reply.
      if (_position.isGameOver) {
        _endLine(_outcomeText());
      }
    } on Object catch (e) {
      if (!mounted) return;
      _endLine("Engine error: $e");
    }
  }

  void _endLine(String reason) {
    setState(() {
      _engineThinking = false;
      _lineOver = true;
      _lineOverReason = reason;
    });
    _boardController.updatePosition(_gameForCurrent());
  }

  String _outcomeText() {
    if (_position.isCheckmate) {
      final bool youGotMated = _position.turn == _playerSide;
      return youGotMated
          ? 'Checkmate — you got mated.'
          : 'Checkmate — you delivered mate!';
    }
    return 'Draw — stalemate or insufficient material.';
  }

  void _reset() {
    _position = Chess.fromSetup(Setup.parseFen(widget.fen));
    setState(() {
      _currentFen = widget.fen;
      _sans.clear();
      _engineThinking = false;
      _lineOver = false;
      _lineOverReason = null;
    });
    _boardController.updatePosition(_gameForCurrent());
  }

  @override
  Widget build(BuildContext context) {
    final bool yourTurn = !_lineOver &&
        !_engineThinking &&
        _engineReady &&
        _position.turn == _playerSide;

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
                onMove: yourTurn ? _onUserMove : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _StatusPanel(
              engineReady: _engineReady,
              engineThinking: _engineThinking,
              lineOver: _lineOver,
              lineOverReason: _lineOverReason,
              sans: _sans,
              playerSide: _playerSide,
            ),
          ),
        ],
      ),
    );
  }
}

// The panel below the board: engine-starting state, opponent-thinking state,
// line-over banner, or the running move list once play begins.
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.engineReady,
    required this.engineThinking,
    required this.lineOver,
    required this.lineOverReason,
    required this.sans,
    required this.playerSide,
  });

  final bool engineReady;
  final bool engineThinking;
  final bool lineOver;
  final String? lineOverReason;
  final List<String> sans;
  final Side playerSide;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: <Widget>[
        _headline(theme),
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

  Widget _headline(ThemeData theme) {
    if (!engineReady) {
      return _row(
        theme,
        Icons.memory_outlined,
        theme.colorScheme.onSurfaceVariant,
        'Starting engine…',
      );
    }
    if (lineOver) {
      return _row(
        theme,
        Icons.flag_outlined,
        theme.colorScheme.primary,
        lineOverReason ?? 'Line over.',
      );
    }
    if (engineThinking) {
      return _row(
        theme,
        Icons.more_horiz,
        theme.colorScheme.onSurfaceVariant,
        'Stockfish is thinking…',
      );
    }
    return _row(
      theme,
      Icons.touch_app_outlined,
      theme.colorScheme.onSurfaceVariant,
      "Your move — play the move you'd make in a game.",
    );
  }

  Widget _row(ThemeData theme, IconData icon, Color color, String text) {
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

// Move list: your moves (even indices) in gold, Stockfish's replies muted.
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
