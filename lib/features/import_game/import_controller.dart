import 'package:chess_trainer/core/chess/game_replay.dart';
import 'package:chess_trainer/core/chess_com/chess_com_client.dart';
import 'package:chess_trainer/features/import_game/import_state.dart';
import 'package:chess_trainer/utils/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ImportController extends Notifier<ImportState> {
  @override
  ImportState build() => const EnteringUsername(username: '');

  void updateUsername(String username) {
    state = EnteringUsername(username: username);
  }

  Future<void> fetchArchives(String username) async {
    state = LoadingArchives(username: username);
    final Result<List<String>> result = await ChessDotComClient.getArchives(username);
    switch (result) {
      case Success<List<String>>(:final List<String> value):
        state = SelectingMonth(archives: value);
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
    state = LoadingGames(username: username, year: year, month: month);
    final Result<String> result = await ChessDotComClient.getMonthlyGames(
      username,
      year,
      month,
    );
    switch (result) {
      case Success<String>(:final String value):
        state = SelectingGame(games: GameReplay.fromPgnCollection(value));
      case Failure<String>(:final String message):
        state = ImportError(message: message);
    }
  }

  void reset() => state = const EnteringUsername(username: '');
}

final NotifierProvider<ImportController, ImportState> importControllerProvider =
    NotifierProvider<ImportController, ImportState>(ImportController.new);
