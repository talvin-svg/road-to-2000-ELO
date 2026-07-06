import 'package:chess_trainer/core/chess/game_replay.dart';
import 'package:chess_trainer/core/chess_com/chess_com_client.dart';
import 'package:chess_trainer/features/games/games_controller.dart';
import 'package:chess_trainer/features/import_game/import_state.dart';
import 'package:chess_trainer/features/replay/replay_controller.dart';
import 'package:chess_trainer/utils/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImportController extends Notifier<ImportState> {
  static const String _usernameKey = 'chess_com_username';
  String _lastUsername = '';

  @override
  ImportState build() {
    _loadSavedUsername();
    return const EnteringUsername(username: '');
  }

  Future<void> _loadSavedUsername() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString(_usernameKey);
    if (saved != null && saved.isNotEmpty) {
      _lastUsername = saved;
      state = EnteringUsername(username: saved);
    }
  }

  void updateUsername(String username) {
    state = EnteringUsername(username: username);
  }

  Future<void> fetchArchives(String username) async {
    _lastUsername = username;
    state = LoadingArchives(username: username);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
    final Result<List<String>> result = await ChessDotComClient.getArchives(username);
    switch (result) {
      case Success<List<String>>(:final List<String> value):
        state = SelectingMonth(archives: value, username: username);
      case Failure<List<String>>(:final String message):
        state = ImportError(message: message);
    }
  }

  // archiveUrl format: https://api.chess.com/pub/player/{username}/games/{year}/{month}
  Future<void> selectArchive(String archiveUrl) async {
    final List<String> segments = archiveUrl.split('/');
    final String username = segments[segments.length - 4];
    final int year = int.parse(segments[segments.length - 2]);
    final int month = int.parse(segments[segments.length - 1]);

    final List<String> archives = switch (state) {
      SelectingMonth(:final List<String> archives) => archives,
      _ => const <String>[],
    };

    state = LoadingGames(username: username, year: year, month: month);
    final Result<String> result = await ChessDotComClient.getMonthlyGames(
      username,
      year,
      month,
    );
    switch (result) {
      case Success<String>(:final String value):
        final List<GameReplay> games = GameReplay.fromPgnCollection(value);
        ref.read(gamesControllerProvider.notifier).addGames(games, username);
        state = SelectingGame(
          games: games,
          username: username,
          archives: archives,
        );
      case Failure<String>(:final String message):
        state = ImportError(message: message);
    }
  }

  Future<void> clearUser() async {
    _lastUsername = '';
    state = const EnteringUsername(username: '');
    ref.read(gamesControllerProvider.notifier).clearGames();
    ref.read(replayControllerProvider.notifier).clearGame();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
  }

  void backToMonths() {
    final ImportState current = state;
    if (current is SelectingGame) {
      state = SelectingMonth(
        archives: current.archives,
        username: current.username,
      );
    }
  }

  void reset() => state = EnteringUsername(username: _lastUsername);
}

final NotifierProvider<ImportController, ImportState> importControllerProvider =
    NotifierProvider<ImportController, ImportState>(ImportController.new);
