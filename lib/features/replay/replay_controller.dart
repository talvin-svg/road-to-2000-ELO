import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess_trainer/core/chess/game_replay.dart';
import 'package:chess_trainer/features/replay/replay_state.dart';

/// Drives step-through navigation of the currently loaded game.
///
/// A plain [Notifier] (no code generation) is enough for Milestone 1's state.
/// Later milestones (repertoire building, drilling) will add their own
/// notifiers alongside this one rather than growing this class.
class ReplayController extends Notifier<ReplayState> {
  @override
  ReplayState build() {
    return const ReplayState(
      game: null,
      currentPly: 0,
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

  void goToEnd() => state = state.copyWith(currentPly: state.game?.length ?? 0);

  void jumpTo(int ply) {
    final int maxPly = state.game?.length ?? 0;
    if (ply >= 0 && ply <= maxPly) {
      state = state.copyWith(currentPly: ply);
    }
  }

  void flipBoard() {
    state = state.copyWith(
      orientation: state.orientation == Side.white ? Side.black : Side.white,
    );
  }

  void loadGame(GameReplay game) {
    state = ReplayState(
      game: game,
      currentPly: 0,
      orientation: state.orientation,
    );
  }
}

final NotifierProvider<ReplayController, ReplayState> replayControllerProvider =
    NotifierProvider<ReplayController, ReplayState>(ReplayController.new);
