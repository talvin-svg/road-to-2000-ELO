import 'package:chess_trainer/core/chess/game_replay.dart';

// One node = one unique chess position, identified by its normalized FEN. It
// holds the position's full FEN (for the board display), how deep in the game
// it occurs, a W/L/D scoreboard of how your games ended when you faced it, and
// references to every game that passed through it (for opening replay).
//
// There are no parent/child links: positions live in a flat registry keyed by
// FEN (see PositionTree). That flat keying is the whole point — it lets
// transpositions (the same position reached via different move orders) merge
// into ONE node and pool their results, instead of being counted separately.
class PositionNode {
  PositionNode({required this.fen, required this.depth});

  // Full FEN (all 6 fields) of the position — kept for rendering the board.
  final String fen;

  // How many plies (half-moves) had been played when this position was first
  // reached — i.e. how deep in the opening it sits. Used to skip the first few
  // near-universal opening plies.
  final int depth;

  // Scoreboard from YOUR perspective, tallied only on your turns. Mutable
  // because the registry is built by bumping these in place as games are walked.
  int wins = 0;
  int losses = 0;
  int draws = 0;

  // Every game that passed through this position — used to let the user pick
  // one and replay the opening moves that led here before drilling.
  final List<GameReplay> games = <GameReplay>[];

  int get total => wins + losses + draws;

  // Whose turn it is here — read from the FEN's side-to-move field ("w"/"b").
  bool get isWhitesTurn => fen.split(' ')[1] == 'w';

  // Sort key for "worst positions". Guarded so an unplayed node (total 0)
  // returns 0.0 instead of dividing by zero.
  double get lossRate => total == 0 ? 0.0 : losses / total;
}
