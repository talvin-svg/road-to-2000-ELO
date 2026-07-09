import 'package:chess_trainer/core/engine/stockfish_engine.dart';
import 'package:chess_trainer/theme/app_theme.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Standalone screen: wraps DrillBody with an AppBar whose restart button calls
// DrillBodyState.reset() via a GlobalKey. The shell uses DrillBody directly,
// with restart wired through ShellNotifier.restartDrill() → a new ValueKey.
class PositionDetailScreen extends ConsumerStatefulWidget {
  const PositionDetailScreen({required this.fen, super.key});

  final String fen;

  @override
  ConsumerState<PositionDetailScreen> createState() =>
      _PositionDetailScreenState();
}

class _PositionDetailScreenState extends ConsumerState<PositionDetailScreen> {
  final GlobalKey<DrillBodyState> _drillKey = GlobalKey<DrillBodyState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Play the line'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Restart line',
            icon: const Icon(Icons.refresh),
            onPressed: () => _drillKey.currentState?.reset(),
          ),
        ],
      ),
      body: DrillBody(key: _drillKey, fen: widget.fen),
    );
  }
}

// Reusable body — used by PositionDetailScreen and AppShell's drill section.
// The shell restarts by giving this widget a new ValueKey (drillKey counter),
// which tears it down and rebuilds it fresh including the Stockfish engine.
class DrillBody extends ConsumerStatefulWidget {
  const DrillBody({required this.fen, super.key});

  final String fen;

  @override
  ConsumerState<DrillBody> createState() => DrillBodyState();
}

class DrillBodyState extends ConsumerState<DrillBody> {
  final StockfishEngine _engine = StockfishEngine();

  bool _engineReady = false;

  late Position _position;
  late final Side _playerSide;
  late String _currentFen;
  late final ChessboardController _boardController;

  final List<String> _sans = <String>[];

  EngineEval? _lastEval;

  bool _engineThinking = false;
  bool _lineOver = false;
  String? _lineOverReason;

  // ── Strength ──────────────────────────────────────────────────────────────
  static const String _prefKey = 'practice_strength_elo';
  static const List<int> _eloOptions = <int>[1000, 1200, 1400, 1600];
  static const Map<int, int> _eloToSkill = <int, int>{
    1000: 2,
    1200: 4,
    1400: 6,
    1600: 8,
  };
  static const Map<int, int> _eloToMoveTimeMs = <int, int>{
    1000: 150,
    1200: 300,
    1400: 500,
    1600: 800,
  };
  int _strengthElo = 1000;

  static const double _boardSize = 300;

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
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final int savedElo = prefs.getInt(_prefKey) ?? 1000;
    _engine.setSkillLevel(_eloToSkill[savedElo]!);
    setState(() {
      _strengthElo = savedElo;
      _engineReady = true;
    });
    _boardController.updatePosition(_gameForCurrent());
  }

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

  void _applyMove(Move move) {
    final (Position next, String san) = _position.makeSan(move);
    setState(() {
      _position = next;
      _currentFen = _position.fen;
      _sans.add(san);
    });
    _boardController.updatePosition(_gameForCurrent());
  }

  Future<void> _onUserMove(Move move, {bool? viaDragAndDrop}) async {
    _applyMove(move);
    await _engineTurn();
  }

  Future<void> _engineTurn() async {
    if (_position.isGameOver) {
      _endLine(_outcomeText());
      return;
    }
    setState(() => _engineThinking = true);
    _boardController.updatePosition(_gameForCurrent());

    try {
      final EngineEval eval = await _engine.evaluate(
        _currentFen,
        moveTimeMs: _eloToMoveTimeMs[_strengthElo]!,
      );
      if (!mounted) return;

      if (eval.bestMove.isEmpty) {
        _endLine(_outcomeText());
        return;
      }

      setState(() {
        _lastEval = eval;
        _engineThinking = false;
      });
      _applyMove(NormalMove.fromUci(eval.bestMove));

      if (_position.isGameOver) {
        _endLine(_outcomeText());
      }
    } on Object catch (e) {
      if (!mounted) return;
      _endLine('Engine error: $e');
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
      return _position.turn == _playerSide
          ? 'Checkmate — you got mated.'
          : 'Checkmate — you delivered mate!';
    }
    return 'Draw — stalemate or insufficient material.';
  }

  Future<void> _changeStrength(int elo) async {
    _engine.setSkillLevel(_eloToSkill[elo]!);
    setState(() => _strengthElo = elo);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, elo);
    reset();
  }

  // Public so PositionDetailScreen can call it from the AppBar restart button,
  // and so callers can trigger a reset programmatically.
  void reset() {
    _position = Chess.fromSetup(Setup.parseFen(widget.fen));
    setState(() {
      _currentFen = widget.fen;
      _sans.clear();
      _lastEval = null;
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: Column(
        children: <Widget>[
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _EvalBar(
                  eval: _lastEval,
                  boardSize: _boardSize,
                  playerSide: _playerSide,
                ),
                const SizedBox(width: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Chessboard(
                    size: _boardSize,
                    settings: AppTheme.boardSettings,
                    controller: _boardController,
                    orientation: _playerSide,
                    onMove: yourTurn ? _onUserMove : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _StrengthSelector(
            selected: _strengthElo,
            options: _eloOptions,
            onChanged: (int elo) => _changeStrength(elo),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _StatusPanel(
              engineReady: _engineReady,
              engineThinking: _engineThinking,
              lineOver: _lineOver,
              lineOverReason: _lineOverReason,
              sans: _sans,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Eval bar ──────────────────────────────────────────────────────────────────
class _EvalBar extends StatelessWidget {
  const _EvalBar({
    required this.eval,
    required this.boardSize,
    required this.playerSide,
  });

  final EngineEval? eval;
  final double boardSize;
  final Side playerSide;

  static const double _barWidth = 14.0;
  static const double _maxCp = 600.0;

  double _whiteFraction() {
    final EngineEval? e = eval;
    if (e == null) return 0.5;
    final int? mate = e.mateIn;
    if (mate != null) return mate > 0 ? 1.0 : 0.0;
    final double clamped =
        (e.centipawns ?? 0).clamp(-_maxCp, _maxCp).toDouble();
    return (clamped + _maxCp) / (2.0 * _maxCp);
  }

  String _label() {
    final EngineEval? e = eval;
    if (e == null) return '0.0';
    final int? mate = e.mateIn;
    if (mate != null) return mate > 0 ? '+M$mate' : '-M${-mate}';
    final int cp = e.centipawns ?? 0;
    final String sign = cp >= 0 ? '+' : '-';
    return '$sign${(cp.abs() / 100.0).toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final double whiteFraction = _whiteFraction();
    final double displayFraction =
        playerSide == Side.white ? whiteFraction : 1.0 - whiteFraction;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: _barWidth,
          height: boardSize,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: <Widget>[
                Container(color: const Color(0xFF1A2128)),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: displayFraction,
                    child: Container(color: const Color(0xFFDDD5B5)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _label(),
          style: AppTheme.mono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Strength selector ─────────────────────────────────────────────────────────
class _StrengthSelector extends StatelessWidget {
  const _StrengthSelector({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final int selected;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Opponent strength',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: options
              .map(
                (int elo) => ButtonSegment<int>(
                  value: elo,
                  label: Text('$elo'),
                ),
              )
              .toList(),
          selected: <int>{selected},
          onSelectionChanged: (Set<int> s) => onChanged(s.first),
        ),
      ],
    );
  }
}

// ── Status panel ──────────────────────────────────────────────────────────────
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.engineReady,
    required this.engineThinking,
    required this.lineOver,
    required this.lineOverReason,
    required this.sans,
  });

  final bool engineReady;
  final bool engineThinking;
  final bool lineOver;
  final String? lineOverReason;
  final List<String> sans;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
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
          _MoveGrid(sans: sans),
        ],
      ],
    );
  }

  Widget _headline(ThemeData theme) {
    if (!engineReady) {
      return _row(theme, Icons.memory_outlined,
          theme.colorScheme.onSurfaceVariant, 'Starting engine…');
    }
    if (lineOver) {
      return _row(theme, Icons.flag_outlined, theme.colorScheme.primary,
          lineOverReason ?? 'Line over.');
    }
    if (engineThinking) {
      return _row(theme, Icons.more_horiz, theme.colorScheme.onSurfaceVariant,
          'Stockfish is thinking…');
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

// Numbered 3-column grid: move number · your move (gold) · engine reply (muted).
class _MoveGrid extends StatelessWidget {
  const _MoveGrid({required this.sans});

  final List<String> sans;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < sans.length; i += 2) {
      final int moveNum = i ~/ 2 + 1;
      final String white = sans[i];
      final String black = i + 1 < sans.length ? sans[i + 1] : '';
      rows.add(
        Row(
          children: <Widget>[
            SizedBox(
              width: 28,
              child: Text(
                '$moveNum.',
                style: AppTheme.mono(
                  fontSize: 13,
                  color: AppTheme.faint,
                ),
              ),
            ),
            Expanded(
              child: Text(
                white,
                style: AppTheme.mono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                black,
                style: AppTheme.mono(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
      rows.add(const SizedBox(height: 6));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}
