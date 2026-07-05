import 'package:chess_trainer/core/chess/game_replay.dart';

sealed class ImportState {
  const ImportState();
}

class EnteringUsername extends ImportState {
  const EnteringUsername({required this.username});

  final String username;
}

class SelectingMonth extends ImportState {
  const SelectingMonth({required this.archives});

  final List<String> archives;
}

class SelectingGame extends ImportState {
  const SelectingGame({required this.games});

  final List<GameReplay> games;
}

class LoadingArchives extends ImportState {
  const LoadingArchives({required this.username});

  final String username;
}

class LoadingGames extends ImportState {
  const LoadingGames({
    required this.username,
    required this.year,
    required this.month,
  });

  final String username;
  final int year;
  final int month;
}

class ImportError extends ImportState {
  const ImportError({required this.message});

  final String message;
}
