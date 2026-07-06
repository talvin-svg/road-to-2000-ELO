// Which Lichess Opening Explorer database to query.
//   lichess — online games, filterable by rating band (what your opponents do)
//   masters — titled-player OTB games (canonical "book" theory)
enum ExplorerSource { lichess, masters }

// The opening the queried position belongs to (ECO code + name), if known.
class ExplorerOpening {
  const ExplorerOpening({required this.eco, required this.name});

  final String eco;
  final String name;
}

// One candidate move from a position, with the win/draw/loss split of games
// that continued with it. "white"/"black" are results by colour, not by player.
class ExplorerMove {
  const ExplorerMove({
    required this.uci,
    required this.san,
    required this.white,
    required this.draws,
    required this.black,
  });

  final String uci;
  final String san;
  final int white;
  final int draws;
  final int black;

  int get total => white + draws + black;
}

// The explorer's answer for one position: aggregate results, the opening name,
// and the ranked candidate moves.
class ExplorerResult {
  const ExplorerResult({
    required this.white,
    required this.draws,
    required this.black,
    required this.opening,
    required this.moves,
  });

  final int white;
  final int draws;
  final int black;
  final ExplorerOpening? opening;
  final List<ExplorerMove> moves;

  int get total => white + draws + black;
}
