import 'dart:async';

import 'package:stockfish_chess_engine/stockfish_chess_engine.dart';

// A typed evaluation of a position, always from White's point of view so the
// number is stable ply to ply (UCI reports scores from the side-to-move's POV,
// which would otherwise flip sign every move — see _buildEval).
class EngineEval {
  const EngineEval({
    required this.bestMove,
    this.centipawns,
    this.mateIn,
  });

  // Best move the engine found, in UCI (e.g. "e2e4", "e7e8q"). Empty only if
  // the position is already terminal (engine replies "bestmove (none)").
  final String bestMove;
  // Evaluation in centipawns, + = better for White. Null when it's a forced
  // mate (then read mateIn instead).
  final int? centipawns;
  // Signed distance to mate, + = White is mating, - = Black is mating. Null
  // unless the engine reports a forced mate.
  final int? mateIn;
}

// A thin, typed wrapper over the raw UCI text protocol the stockfish package
// speaks (write command strings to `stdin`, read reply lines off `stdout`).
// The whole point is that callers never touch that protocol: they call
// evaluate(fen) and get an EngineEval back. Native only (the package is FFI);
// web is out of scope for this project.
class StockfishEngine {
  Stockfish? _engine;
  StreamSubscription<String>? _subscription;

  // Handshake plumbing: during start() we send a command and wait for a
  // specific reply token (uciok, readyok). Only one is outstanding at a time.
  Completer<void>? _handshake;
  String? _handshakeToken;

  // Search plumbing: the completer for the search currently running, plus the
  // last score seen on an `info` line before `bestmove` closes the search.
  Completer<EngineEval>? _pending;
  int? _lastCp;
  int? _lastMate;
  bool _whiteToMove = true;

  // A promise chain used as a mutex. UCI is a single conversation — you can't
  // run two `go` searches at once — so each evaluate() waits for the previous
  // one to finish before it issues its commands.
  Future<void> _lock = Future<void>.value();

  // Boot the engine and run the UCI readiness handshake. stockfishAsync()
  // resolves once the native process is up; then the protocol's own "are you
  // ready?" exchange (isready -> readyok) tells us it's ready to search — no
  // guessing with a timer.
  Future<void> start() async {
    _engine = await stockfishAsync();
    _subscription = _engine!.stdout.listen(_onLine);
    await _handshakeStep('uci', 'uciok');
    await _handshakeStep('isready', 'readyok');
  }

  Future<void> _handshakeStep(String command, String token) {
    final Completer<void> step = Completer<void>();
    _handshake = step;
    _handshakeToken = token;
    _send(command);
    return step.future;
  }

  // Evaluate a position for a fixed wall-clock duration. Using movetime rather
  // than depth keeps response latency consistent across hardware — depth-based
  // searches finish faster on powerful machines, making the feel inconsistent.
  Future<EngineEval> evaluate(String fen, {int moveTimeMs = 1000}) {
    final Future<EngineEval> result =
        _lock.then((_) => _runSearch(fen, moveTimeMs));
    // The next caller waits for this search; swallow errors so one failed
    // search doesn't poison the whole chain.
    _lock = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<EngineEval> _runSearch(String fen, int moveTimeMs) {
    // The FEN's second field is the side to move ("w"/"b") — needed to
    // normalise the score to White's POV when the search ends.
    _whiteToMove = fen.split(' ')[1] == 'w';
    _lastCp = null;
    _lastMate = null;
    final Completer<EngineEval> search = Completer<EngineEval>();
    _pending = search;
    _send('position fen $fen');
    _send('go movetime $moveTimeMs');
    return search.future;
  }

  // Every line the engine emits lands here.
  void _onLine(String line) {
    // Handshake reply we're waiting for (uciok / readyok).
    if (_handshake != null &&
        _handshakeToken != null &&
        line.startsWith(_handshakeToken!)) {
      final Completer<void> step = _handshake!;
      _handshake = null;
      _handshakeToken = null;
      step.complete();
      return;
    }
    // Running eval: `info depth 18 ... score cp 34 ...` — keep the latest.
    if (line.startsWith('info') && line.contains(' score ')) {
      _parseScore(line);
      return;
    }
    // `bestmove e2e4 ponder e7e5` — the search is done. Resolve with the last
    // score we saw plus this move.
    if (line.startsWith('bestmove')) {
      final List<String> parts = line.split(' ');
      final String uci = parts.length > 1 ? parts[1] : '';
      final Completer<EngineEval>? search = _pending;
      _pending = null;
      search?.complete(_buildEval(uci == '(none)' ? '' : uci));
    }
  }

  void _parseScore(String line) {
    final List<String> tokens = line.split(' ');
    final int scoreIndex = tokens.indexOf('score');
    if (scoreIndex < 0 || scoreIndex + 2 >= tokens.length) return;
    final String kind = tokens[scoreIndex + 1];
    final int? value = int.tryParse(tokens[scoreIndex + 2]);
    if (value == null) return;
    if (kind == 'cp') {
      _lastCp = value;
      _lastMate = null;
    } else if (kind == 'mate') {
      _lastMate = value;
      _lastCp = null;
    }
  }

  EngineEval _buildEval(String bestMove) {
    // Scores arrive from the side-to-move's POV; flip to White's when Black was
    // on move, so callers get one consistent frame of reference.
    final int sign = _whiteToMove ? 1 : -1;
    return EngineEval(
      bestMove: bestMove,
      centipawns: _lastCp == null ? null : _lastCp! * sign,
      mateIn: _lastMate == null ? null : _lastMate! * sign,
    );
  }

  // Map a Skill Level (0–20) onto the engine before the next search.
  // UCI setoption takes effect immediately; no response is emitted, so this
  // is fire-and-forget (no awaiting needed).
  void setSkillLevel(int level) {
    _send('setoption name Skill Level value $level');
  }

  void _send(String command) {
    _engine?.stdin = command;
  }

  // Cancel our stdout subscription and tell the engine to quit. Must be called
  // before creating another engine (the package allows only one at a time).
  // Completing _pending with an error first unblocks any coroutine that is
  // currently awaiting evaluate() — otherwise that future would hang forever
  // because _onLine will never fire again after the subscription is cancelled.
  void dispose() {
    final Completer<EngineEval>? pending = _pending;
    _pending = null;
    _subscription?.cancel();
    _subscription = null;
    _engine?.dispose();
    _engine = null;
    pending?.completeError(StateError('Engine disposed'));
  }
}
