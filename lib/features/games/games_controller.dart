import 'package:chess_trainer/core/chess/game_replay.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GamesState {
  const GamesState({required this.gamesByMonth, required this.username});
  const GamesState.empty()
      : gamesByMonth = const <String, List<GameReplay>>{},
        username = '';

  // Games grouped by the Chess.com archive URL (one month) they came from.
  // Grouping — rather than one flat list — is what lets a month be removed
  // again, and makes "which months are added" just `gamesByMonth.keys`.
  final Map<String, List<GameReplay>> gamesByMonth;
  final String username;

  // Flattened view for anything that just wants "all games" (e.g. the tree).
  List<GameReplay> get games => <GameReplay>[
        for (final List<GameReplay> monthGames in gamesByMonth.values)
          ...monthGames,
      ];

  // The set of months currently in the pool — the single source of truth for
  // the ✓ marks in the import UI.
  Set<String> get addedMonths => gamesByMonth.keys.toSet();
}

class GamesController extends Notifier<GamesState> {
  @override
  GamesState build() => const GamesState.empty();

  // Adds (or replaces) one month's games. Keyed by archive URL, so re-adding
  // the same month overwrites rather than double-counts.
  void addMonth(String archiveUrl, List<GameReplay> games, String username) {
    state = GamesState(
      gamesByMonth: <String, List<GameReplay>>{
        ...state.gamesByMonth,
        archiveUrl: games,
      },
      username: username,
    );
  }

  void removeMonth(String archiveUrl) {
    final Map<String, List<GameReplay>> next =
        Map<String, List<GameReplay>>.of(state.gamesByMonth)..remove(archiveUrl);
    state = GamesState(gamesByMonth: next, username: state.username);
  }

  void clearGames() => state = const GamesState.empty();
}

final NotifierProvider<GamesController, GamesState> gamesControllerProvider =
    NotifierProvider<GamesController, GamesState>(GamesController.new);
