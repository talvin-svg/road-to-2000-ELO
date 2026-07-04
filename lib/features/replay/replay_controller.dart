import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/chess/game_replay.dart';
import '../../core/chess/sample_games.dart';
import 'replay_state.dart';

/// Drives step-through navigation of the currently loaded game.
///
/// A plain [Notifier] (no code generation) is enough for Milestone 1's state.
/// Later milestones (repertoire building, drilling) will add their own
/// notifiers alongside this one rather than growing this class.
class ReplayController extends Notifier<ReplayState> {
  @override
  ReplayState build() {
    return ReplayState(
      game: GameReplay.fromPgn(samplePgn),
      currentPly: 0,
      // Most losses happen playing Black, so default to Black's viewpoint.
      orientation: Side.black,
    );
  }

  void goToNext() {
    if (state.canGoToNext) {
      state = state.copyWith(currentPly: state.currentPly + 1);
    }
  }

  void goToPrevious() {
    if (state.canGoToPrevious) {
      state = state.copyWith(currentPly: state.currentPly - 1);
    }
  }

  void goToStart() => state = state.copyWith(currentPly: 0);

  void goToEnd() => state = state.copyWith(currentPly: state.game.length);

  void jumpTo(int ply) {
    if (ply >= 0 && ply <= state.game.length) {
      state = state.copyWith(currentPly: ply);
    }
  }

  void flipBoard() {
    state = state.copyWith(
      orientation: state.orientation == Side.white ? Side.black : Side.white,
    );
  }
}

final replayControllerProvider = NotifierProvider<ReplayController, ReplayState>(
  ReplayController.new,
);
