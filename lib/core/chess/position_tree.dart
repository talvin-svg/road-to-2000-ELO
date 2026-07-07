import 'package:chess_trainer/core/chess/fen.dart';
import 'package:chess_trainer/core/chess/game_replay.dart';
import 'package:chess_trainer/core/chess/position_node.dart';
import 'package:dartchess/dartchess.dart';

// A flat registry of every unique opening position seen across all imported
// games, keyed by a normalized FEN. "Flat" (a Map, not a tree) is deliberate:
// it's the only way transpositions merge. The same position reached by
// different move orders is looked up under the same key and pools its results
// into one node. A tree keyed by FEN would NOT merge them, because tree nodes
// are reached by descending from a parent, and transpositions have different
// parents. (Name kept as "PositionTree" for now; it's really a registry.)
class PositionTree {
  PositionTree();

  final Map<String, PositionNode> _positions = <String, PositionNode>{};

  // 20 plies = the first 10 full moves per side; keeps analysis in the
  // opening phase where preparation gaps are most actionable.
  static const int _maxPly = 20;
  static const int _minPly = 4;

  static PositionTree build(List<GameReplay> games, String username) {
    final PositionTree tree = PositionTree();
    for (final GameReplay game in games) {
      tree._addGame(game, username);
    }
    return tree;
  }

  void _addGame(GameReplay game, String username) {
    // Which colour were you in THIS game? Compared case-insensitively because
    // Chess.com usernames aren't case-consistent across the PGN header.
    final bool playerIsWhite =
        game.whitePlayer.toLowerCase() == username.toLowerCase();

    // The position BEFORE the next move. Starts at the initial position; after
    // each ply it advances to that ply's resulting FEN.
    String currentFen = Chess.initial.fen;

    for (int i = 0; i < game.plies.length && i < _maxPly; i++) {
      // Even indices are White's moves (ply 0, 2, 4…), odd are Black's.
      final bool isWhitesTurn = i % 2 == 0;
      final bool isPlayersTurn = playerIsWhite == isWhitesTurn;

      // Record only on your own turns, onto the position you're ABOUT to move
      // in — that's the definition of a "problem spot": a position you faced
      // and had to find a move in. find-or-create the node under its FEN key so
      // this game merges with any other game (any move order) that reached the
      // same position; `i` is the ply depth.
      if (isPlayersTurn) {
        final PositionNode node = _positions.putIfAbsent(
          normalizeFen(currentFen),
          () => PositionNode(fen: currentFen, depth: i),
        );
        _recordOutcome(node, game.result, playerIsWhite);
      }

      currentFen = game.plies[i].fen; // advance to the position after this ply
    }
  }

  // Translates the PGN result string ("1-0" etc.) into a win/loss/draw from
  // YOUR side and bumps the right counter. The same "1-0" means a win if you
  // were White but a loss if you were Black, hence the playerIsWhite checks.
  // A non-standard/unfinished result (e.g. "*") matches no case and records
  // nothing — that game simply doesn't count toward this node.
  static void _recordOutcome(
    PositionNode node,
    String result,
    bool playerIsWhite,
  ) {
    switch (result) {
      case '1-0':
        if (playerIsWhite) {
          node.wins++;
        } else {
          node.losses++;
        }
      case '0-1':
        if (playerIsWhite) {
          node.losses++;
        } else {
          node.wins++;
        }
      case '1/2-1/2':
        node.draws++;
    }
  }

  // Worst problem positions for one colour, worst-first. With a flat registry
  // this is just a filter-and-sort over all positions — no tree walk needed.
  // Filters: past the opening (depth >= _minPly), enough games passed through
  // it (total >= minGames), and it's the requested colour's turn.
  List<PositionNode> worstPositions({
    required bool asWhite,
    int minGames = 3,
    int limit = 10,
  }) {
    final List<PositionNode> result = _positions.values
        .where((PositionNode node) =>
            node.depth >= _minPly &&
            node.total >= minGames &&
            node.isWhitesTurn == asWhite)
        .toList();
    result.sort(
      (PositionNode a, PositionNode b) => b.lossRate.compareTo(a.lossRate),
    );
    return result.take(limit).toList();
  }
}
