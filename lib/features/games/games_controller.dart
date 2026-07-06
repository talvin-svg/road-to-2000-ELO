import 'package:chess_trainer/core/chess/game_replay.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GamesState {
  const GamesState({required this.games, required this.username});
  const GamesState.empty()
      : games = const <GameReplay>[],
        username = '';

  final List<GameReplay> games;
  final String username;
}

class GamesController extends Notifier<GamesState> {
  @override
  GamesState build() => const GamesState.empty();

  // Appends rather than replaces so multiple monthly imports accumulate.
  void addGames(List<GameReplay> games, String username) {
    state = GamesState(
      games: <GameReplay>[...state.games, ...games],
      username: username,
    );
  }

  void clearGames() => state = const GamesState.empty();
}

final NotifierProvider<GamesController, GamesState> gamesControllerProvider =
    NotifierProvider<GamesController, GamesState>(GamesController.new);
