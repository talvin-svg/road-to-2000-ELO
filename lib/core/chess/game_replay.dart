import 'package:dartchess/dartchess.dart';

/// A single played half-move (ply), with everything the UI needs to display
/// it: the resulting position, and enough of the resulting board state to
/// feed a [chessground] board without re-parsing FEN at render time.
class PlyRecord {
  const PlyRecord({
    required this.san,
    required this.move,
    required this.fen,
    required this.sideToMove,
    required this.checkedKingSquare,
  });

  /// Standard Algebraic Notation for this move, e.g. "Nf3" or "O-O".
  final String san;

  final Move move;

  /// Full FEN of the position after this move is played.
  final String fen;

  /// Side to move after this move is played.
  final Side sideToMove;

  /// Square of the king in check after this move, if any.
  final Square? checkedKingSquare;
}

/// A game parsed from PGN into a flat, indexable list of plies, so the UI can
/// jump to any point in the game in O(1) instead of replaying moves.
class GameReplay {
  GameReplay({required this.startingFen, required this.plies});

  /// Parses the mainline of [pgn] from the standard starting position.
  ///
  /// Variations and comments are ignored for now; only the mainline is kept.
  /// Parsing stops early if a SAN token isn't a legal move in sequence.
  factory GameReplay.fromPgn(String pgn) {
    final parsedGame = PgnGame.parsePgn(pgn);
    Position position = Chess.initial;
    final plies = <PlyRecord>[];

    for (final nodeData in parsedGame.moves.mainline()) {
      final move = position.parseSan(nodeData.san);
      if (move == null) break;
      position = position.play(move);
      plies.add(
        PlyRecord(
          san: nodeData.san,
          move: move,
          fen: position.fen,
          sideToMove: position.turn,
          checkedKingSquare: position.isCheck ? position.board.kingOf(position.turn) : null,
        ),
      );
    }

    return GameReplay(startingFen: Chess.initial.fen, plies: plies);
  }

  /// FEN of the starting position (ply 0).
  final String startingFen;

  /// One entry per half-move played, in order.
  final List<PlyRecord> plies;

  /// Number of plies in the game.
  int get length => plies.length;

  /// FEN of the position after [ply] half-moves (0 = starting position).
  String fenAt(int ply) => ply == 0 ? startingFen : plies[ply - 1].fen;

  /// The move that produced the position at [ply], or null at ply 0.
  Move? lastMoveAt(int ply) => ply == 0 ? null : plies[ply - 1].move;

  /// Side to move at [ply].
  Side sideToMoveAt(int ply) => ply == 0 ? Side.white : plies[ply - 1].sideToMove;

  /// Square of the king in check at [ply], if any.
  Square? checkedKingSquareAt(int ply) => ply == 0 ? null : plies[ply - 1].checkedKingSquare;
}
