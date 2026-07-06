import 'package:chess_trainer/core/chess/game_replay.dart';

sealed class ImportState {
  const ImportState();
}

class EnteringUsername extends ImportState {
  const EnteringUsername({required this.username});

  final String username;
}

class SelectingMonth extends ImportState {
  const SelectingMonth({
    required this.archives,
    required this.username,
    this.addingArchive,
  });

  final List<String> archives;
  final String username;

  // The archive URL currently being fetched for an "Add", if any. Lets the UI
  // show a spinner on just that row instead of blanking the whole screen.
  // (Which months are *already* added is read from the registry, not stored
  // here, so there's a single source of truth.)
  final String? addingArchive;
}

class SelectingGame extends ImportState {
  const SelectingGame({
    required this.games,
    required this.username,
    required this.archives,
  });

  final List<GameReplay> games;
  final String username;
  final List<String> archives;
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
