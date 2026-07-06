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

  // Source of truth for which months are already in the registry this session.
  // Kept here (not only in the state) so it survives a browse round-trip
  // (month list → game list → back) without threading it through SelectingGame.
  final Set<String> _addedArchives = <String>{};

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
    // New username / fresh archive list — nothing added yet.
    _addedArchives.clear();
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
  ({String username, int year, int month}) _parseArchive(String archiveUrl) {
    final List<String> segments = archiveUrl.split('/');
    return (
      username: segments[segments.length - 4],
      year: int.parse(segments[segments.length - 2]),
      month: int.parse(segments[segments.length - 1]),
    );
  }

  // Adds a month's games to the analysis registry, staying on the month list.
  // Shows a per-row spinner while fetching, then marks the row added. This is
  // now the ONLY path that pushes games into the registry.
  Future<void> addMonth(String archiveUrl) async {
    final ImportState current = state;
    if (current is! SelectingMonth) return;
    // Already added — don't fetch again or double-count its games.
    if (_addedArchives.contains(archiveUrl)) return;

    final ({String username, int year, int month}) parsed =
        _parseArchive(archiveUrl);

    // Spinner on just this row; keep the list visible.
    state = SelectingMonth(
      archives: current.archives,
      username: current.username,
      addedArchives: Set<String>.of(_addedArchives),
      addingArchive: archiveUrl,
    );

    final Result<String> result = await ChessDotComClient.getMonthlyGames(
      parsed.username,
      parsed.year,
      parsed.month,
    );
    switch (result) {
      case Success<String>(:final String value):
        final List<GameReplay> games = GameReplay.fromPgnCollection(value);
        ref.read(gamesControllerProvider.notifier).addGames(games, parsed.username);
        _addedArchives.add(archiveUrl);
        state = SelectingMonth(
          archives: current.archives,
          username: current.username,
          addedArchives: Set<String>.of(_addedArchives),
        );
      case Failure<String>(:final String message):
        state = ImportError(message: message);
    }
  }

  // Opens a month's games so one can be picked and replayed. Does NOT touch the
  // registry — adding is the Add button's job.
  Future<void> browseArchive(String archiveUrl) async {
    final ({String username, int year, int month}) parsed =
        _parseArchive(archiveUrl);

    final List<String> archives = switch (state) {
      SelectingMonth(:final List<String> archives) => archives,
      _ => const <String>[],
    };

    state = LoadingGames(
      username: parsed.username,
      year: parsed.year,
      month: parsed.month,
    );
    final Result<String> result = await ChessDotComClient.getMonthlyGames(
      parsed.username,
      parsed.year,
      parsed.month,
    );
    switch (result) {
      case Success<String>(:final String value):
        final List<GameReplay> games = GameReplay.fromPgnCollection(value);
        state = SelectingGame(
          games: games,
          username: parsed.username,
          archives: archives,
        );
      case Failure<String>(:final String message):
        state = ImportError(message: message);
    }
  }

  Future<void> clearUser() async {
    _lastUsername = '';
    _addedArchives.clear();
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
        // Restore the ✓ marks — games browsed here didn't touch the registry,
        // so anything added earlier is still added.
        addedArchives: Set<String>.of(_addedArchives),
      );
    }
  }

  void reset() => state = EnteringUsername(username: _lastUsername);
}

final NotifierProvider<ImportController, ImportState> importControllerProvider =
    NotifierProvider<ImportController, ImportState>(ImportController.new);
