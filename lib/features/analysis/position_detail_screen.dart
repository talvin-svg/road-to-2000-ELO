import 'package:chess_trainer/core/engine/stockfish_engine.dart';
import 'package:chess_trainer/theme/app_theme.dart';
import 'package:chess_trainer/widgets/transport_button.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Standalone screen: wraps DrillBody with an AppBar whose restart button calls
// DrillBodyState.reset() via a GlobalKey. The shell uses DrillBody directly,
// with restart wired through ShellNotifier.restartDrill() → a new ValueKey.
class PositionDetailScreen extends ConsumerStatefulWidget {
  const PositionDetailScreen({
    required this.fen,
    this.openingPositions,
    this.openingFens,
    this.openingSans,
    super.key,
  });

  final String fen;
  // Pre-loaded opening moves from the chosen game (positions[0] = initial,
  // positions.last = the problem position). When provided the board starts at
  // move 1 so the user can step through the opening before drilling.
  final List<Position>? openingPositions;
  final List<String>? openingFens;
  final List<String>? openingSans;

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
      body: DrillBody(
        key: _drillKey,
        fen: widget.fen,
        openingPositions: widget.openingPositions,
        openingFens: widget.openingFens,
        openingSans: widget.openingSans,
      ),
    );
  }
}

// Reusable body — used by PositionDetailScreen and AppShell's drill section.
// The shell restarts by giving this widget a new ValueKey (drillKey counter),
// which tears it down and rebuilds it fresh including the Stockfish engine.
class DrillBody extends ConsumerStatefulWidget {
  const DrillBody({
    required this.fen,
    this.openingPositions,
    this.openingFens,
    this.openingSans,
    super.key,
  });

  final String fen;
  final List<Position>? openingPositions;
  final List<String>? openingFens;
  final List<String>? openingSans;

  @override
  ConsumerState<DrillBody> createState() => DrillBodyState();
}

class DrillBodyState extends ConsumerState<DrillBody> {
  final StockfishEngine _engine = StockfishEngine();

  bool _engineReady = false;

  // Live position — always the latest position in the game regardless of what
  // the user is currently viewing.
  late Position _position;
  late final Side _playerSide;
  late String _currentFen;
  late final ChessboardController _boardController;

  // History: index 0 = starting position (or problem position if no opening),
  // index k = position after k moves. Parallel lists so we can look up both
  // Position (for legal moves) and FEN (for the board) at any point.
  final List<Position> _posHistory = <Position>[];
  final List<String> _fenHistory = <String>[];

  // Which history slot the board is currently showing. At the end = live play;
  // stepped back = reviewing (board is non-interactive).
  int _viewIndex = 0;

  bool get _isLive => _viewIndex == _fenHistory.length - 1;

  // Number of pre-loaded opening moves before the drill started. Moves at
  // indices 0..<_openingLength are game moves; indices >= _openingLength are
  // drill moves. Used to style the move grid correctly.
  int _openingLength = 0;

  final List<String> _sans = <String>[];

  EngineEval? _lastEval;

  bool _engineThinking = false;
  bool _lineOver = false;
  // Incremented on every reset() so stale in-flight _engineTurn calls can
  // detect they belong to a previous game and discard their result.
  int _generation = 0;
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
    _seedHistory();
    _boardController = ChessboardController(game: _gameForCurrent());
    _startEngine();
  }

  void _seedHistory() {
    _posHistory.clear();
    _fenHistory.clear();
    _sans.clear();
    if (widget.openingPositions != null) {
      _posHistory.addAll(widget.openingPositions!);
      _fenHistory.addAll(widget.openingFens!);
      _sans.addAll(widget.openingSans!);
      _openingLength = widget.openingSans!.length;
    } else {
      _posHistory.add(_position);
      _fenHistory.add(_currentFen);
      _openingLength = 0;
    }
    // Start at the beginning so the user steps through the opening, or at the
    // problem position when there is no opening to review.
    _viewIndex = 0;
  }

  @override
  void dispose() {
    _generation++;
    _engine.dispose();
    _boardController.dispose();
    super.dispose();
  }

  Future<void> _startEngine() async {
    // Retry until the previous native Stockfish process has fully exited.
    // Flutter can call initState() on the new widget before dispose() on the
    // old one, so stockfishAsync() may throw "only one instance" briefly.
    while (true) {
      try {
        await _engine.start();
        break;
      } on Object catch (_) {
        if (!mounted) return;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
      }
    }
    if (!mounted) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final int raw = prefs.getInt(_prefKey) ?? 1000;
    final int savedElo = _eloToSkill.containsKey(raw) ? raw : 1000;
    _engine.setSkillLevel(_eloToSkill[savedElo]!);
    setState(() {
      _strengthElo = savedElo;
      _engineReady = true;
    });
    _boardController.updatePosition(_gameForCurrent());
  }

  GameData _gameForCurrent() {
    final Position viewedPos = _posHistory[_viewIndex];
    final String viewedFen = _fenHistory[_viewIndex];
    // Only allow moves when at the live end of the line, it's the player's
    // turn, and neither the engine nor the line is blocking input.
    final bool interactive = _isLive &&
        _engineReady &&
        !_engineThinking &&
        !_lineOver &&
        _position.turn == _playerSide;
    return GameData(
      fen: viewedFen,
      playerSide: interactive
          ? (_playerSide == Side.white ? PlayerSide.white : PlayerSide.black)
          : PlayerSide.none,
      sideToMove: viewedPos.turn,
      validMoves:
          interactive ? makeLegalMoves(_position) : <Square, Set<Square>>{},
    );
  }

  void _applyMove(Move move) {
    final (Position next, String san) = _position.makeSan(move);
    setState(() {
      _position = next;
      _currentFen = _position.fen;
      _sans.add(san);
      _posHistory.add(next);
      _fenHistory.add(next.fen);
      // Always snap to the latest position when a move is played so the user
      // sees the engine reply even if they were reviewing an earlier move.
      _viewIndex = _fenHistory.length - 1;
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
    final int gen = _generation;
    setState(() => _engineThinking = true);
    _boardController.updatePosition(_gameForCurrent());

    try {
      final EngineEval eval = await _engine.evaluate(
        _currentFen,
        moveTimeMs: _eloToMoveTimeMs[_strengthElo]!,
      );
      if (!mounted || _generation != gen) return;

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
      if (!mounted || _generation != gen) return;
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

  // ── Navigation ────────────────────────────────────────────────────────────

  void _goBack() {
    if (_viewIndex > 0) {
      setState(() => _viewIndex--);
      _boardController.updatePosition(_gameForCurrent());
    }
  }

  void _goForward() {
    if (_viewIndex < _fenHistory.length - 1) {
      setState(() => _viewIndex++);
      _boardController.updatePosition(_gameForCurrent());
    }
  }

  void _jumpToMove(int sanIndex) {
    // sanIndex is the index into _sans; history index = sanIndex + 1 because
    // history[0] is the starting position before any moves.
    final int histIndex = sanIndex + 1;
    if (histIndex >= 0 && histIndex < _posHistory.length) {
      setState(() => _viewIndex = histIndex);
      _boardController.updatePosition(_gameForCurrent());
    }
  }

  // Public so PositionDetailScreen can call it from the AppBar restart button,
  // and so callers can trigger a reset programmatically.
  void reset() {
    _generation++;
    _position = Chess.fromSetup(Setup.parseFen(widget.fen));
    setState(() {
      _currentFen = widget.fen;
      _lastEval = null;
      _engineThinking = false;
      _lineOver = false;
      _lineOverReason = null;
    });
    _seedHistory();
    _boardController.updatePosition(_gameForCurrent());
  }

  @override
  Widget build(BuildContext context) {
    final bool yourTurn = !_lineOver &&
        !_engineThinking &&
        _engineReady &&
        _position.turn == _playerSide;

    // Hide the eval when reviewing a past position — it belongs to the live end.
    final EngineEval? displayEval = _isLive ? _lastEval : null;

    // The move index the user is currently viewing (-1 = before any moves).
    final int viewedSanIndex = _viewIndex - 1;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Column(
            children: <Widget>[
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _EvalBar(
                      eval: displayEval,
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
                        onMove: (yourTurn && _isLive) ? _onUserMove : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _StrengthSelector(
                selected: _strengthElo,
                options: _eloOptions,
                onChanged: (int elo) => _changeStrength(elo),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        Expanded(
          child: _StatusPanel(
            engineReady: _engineReady,
            engineThinking: _engineThinking,
            lineOver: _lineOver,
            lineOverReason: _lineOverReason,
            isReviewing: !_isLive,
            sans: _sans,
            openingLength: _openingLength,
            playerSide: _playerSide,
            viewedSanIndex: viewedSanIndex,
            onMoveTap: _jumpToMove,
          ),
        ),
        _DrillTransportBar(
          canBack: _viewIndex > 0,
          canForward: !_isLive,
          onFirst: _viewIndex > 0
              ? () {
                  setState(() => _viewIndex = 0);
                  _boardController.updatePosition(_gameForCurrent());
                }
              : null,
          onBack: _goBack,
          onForward: _goForward,
          onLast: !_isLive
              ? () {
                  setState(() => _viewIndex = _fenHistory.length - 1);
                  _boardController.updatePosition(_gameForCurrent());
                }
              : null,
        ),
      ],
    );
  }
}

// ── Drill transport bar ───────────────────────────────────────────────────────
class _DrillTransportBar extends StatelessWidget {
  const _DrillTransportBar({
    required this.canBack,
    required this.canForward,
    required this.onFirst,
    required this.onBack,
    required this.onForward,
    required this.onLast,
  });

  final bool canBack;
  final bool canForward;
  final VoidCallback? onFirst;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback? onLast;

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
              onPressed: canBack ? onFirst : null,
            ),
            const SizedBox(width: 8),
            TransportButton(
              icon: Icons.chevron_left,
              flex: 1,
              onPressed: canBack ? onBack : null,
            ),
            const SizedBox(width: 8),
            TransportButton(
              icon: Icons.chevron_right,
              flex: 2,
              primary: true,
              onPressed: canForward ? onForward : null,
            ),
            const SizedBox(width: 8),
            TransportButton(
              icon: Icons.last_page,
              flex: 1,
              onPressed: canForward ? onLast : null,
            ),
          ],
        ),
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
    required this.isReviewing,
    required this.sans,
    required this.openingLength,
    required this.playerSide,
    required this.viewedSanIndex,
    required this.onMoveTap,
  });

  final bool engineReady;
  final bool engineThinking;
  final bool lineOver;
  final String? lineOverReason;
  // True when the board is showing a past position (not the live end).
  final bool isReviewing;
  final List<String> sans;
  // Number of pre-loaded opening moves at the start of the sans list.
  final int openingLength;
  final Side playerSide;
  // Index into sans of the move currently shown on the board (-1 = start).
  final int viewedSanIndex;
  final ValueChanged<int> onMoveTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
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
          _MoveGrid(
            sans: sans,
            openingLength: openingLength,
            playerSide: playerSide,
            selectedIndex: viewedSanIndex,
            onTap: onMoveTap,
          ),
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
    if (isReviewing) {
      return _row(theme, Icons.history, theme.colorScheme.onSurfaceVariant,
          'Reviewing — press ▶ to reach your position.');
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

// Numbered 3-column grid: move number · white move · black move.
// Opening moves (index < openingLength) use the replay screen's neutral styling
// since both sides are from the actual game. Drill moves use gold for the
// player's colour and muted for the engine's.
class _MoveGrid extends StatelessWidget {
  const _MoveGrid({
    required this.sans,
    required this.openingLength,
    required this.playerSide,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<String> sans;
  final int openingLength;
  final Side playerSide;
  // Index into sans of the currently viewed move (-1 = no move selected).
  final int selectedIndex;
  final ValueChanged<int> onTap;

  // A white-column move is at an even san index; black is odd.
  bool _isPlayerMove(int sanIndex) {
    final bool isWhiteMove = sanIndex % 2 == 0;
    return playerSide == Side.white ? isWhiteMove : !isWhiteMove;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < sans.length; i += 2) {
      final int moveNum = i ~/ 2 + 1;
      final String white = sans[i];
      final String? black = i + 1 < sans.length ? sans[i + 1] : null;
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
              child: _MoveCell(
                san: white,
                sanIndex: i,
                isSelected: selectedIndex == i,
                isOpeningMove: i < openingLength,
                isPlayerMove: _isPlayerMove(i),
                theme: theme,
                onTap: onTap,
              ),
            ),
            Expanded(
              child: black != null
                  ? _MoveCell(
                      san: black,
                      sanIndex: i + 1,
                      isSelected: selectedIndex == i + 1,
                      isOpeningMove: i + 1 < openingLength,
                      isPlayerMove: _isPlayerMove(i + 1),
                      theme: theme,
                      onTap: onTap,
                    )
                  : const SizedBox(),
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

class _MoveCell extends StatelessWidget {
  const _MoveCell({
    required this.san,
    required this.sanIndex,
    required this.isSelected,
    required this.isOpeningMove,
    required this.isPlayerMove,
    required this.theme,
    required this.onTap,
  });

  final String san;
  final int sanIndex;
  final bool isSelected;
  // Opening moves (both sides from the actual game) use neutral colours.
  final bool isOpeningMove;
  // Whether this move belongs to the player (vs the engine).
  final bool isPlayerMove;
  final ThemeData theme;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final Color gold = theme.colorScheme.primary;

    final Color textColor;
    final FontWeight weight;
    if (isSelected) {
      textColor = gold;
      weight = FontWeight.w700;
    } else if (isOpeningMove) {
      // Both sides' opening moves: white slightly bolder, black muted.
      textColor = isPlayerMove
          ? theme.colorScheme.onSurface
          : theme.colorScheme.onSurfaceVariant;
      weight = isPlayerMove ? FontWeight.w600 : FontWeight.w400;
    } else {
      // Drill moves: player = gold, engine = muted.
      textColor =
          isPlayerMove ? gold : theme.colorScheme.onSurfaceVariant;
      weight = isPlayerMove ? FontWeight.w700 : FontWeight.w400;
    }

    return GestureDetector(
      onTap: () => onTap(sanIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: isSelected
            ? BoxDecoration(
                color: gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        child: Text(
          san,
          style: AppTheme.mono(
            fontSize: 14,
            fontWeight: weight,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
