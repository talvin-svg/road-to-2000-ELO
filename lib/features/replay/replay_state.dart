import 'package:dartchess/dartchess.dart';

import 'package:chess_trainer/core/chess/game_replay.dart';

/// UI-facing state for the replay screen: which game, and where in it.
class ReplayState {
  const ReplayState({required this.game, required this.currentPly, required this.orientation});

  /// Null until the user imports a game for the first time.
  final GameReplay? game;

  /// How many plies into [game] we're currently showing. 0 = starting position.
  final int currentPly;

  /// Which side of the board is shown at the bottom.
  final Side orientation;

  String get fen => game?.fenAt(currentPly) ?? Chess.initial.fen;
  Move? get lastMove => game?.lastMoveAt(currentPly);
  Side get sideToMove => game?.sideToMoveAt(currentPly) ?? Side.white;
  Square? get checkedKingSquare => game?.checkedKingSquareAt(currentPly);

  bool get canGoToPrevious => currentPly > 0;
  bool get canGoToNext => currentPly < (game?.length ?? 0);

  ReplayState copyWith({int? currentPly, Side? orientation}) {
    return ReplayState(
      game: game,
      currentPly: currentPly ?? this.currentPly,
      orientation: orientation ?? this.orientation,
    );
  }
}
