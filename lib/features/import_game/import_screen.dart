import 'package:chess_trainer/core/chess/game_replay.dart';
import 'package:chess_trainer/core/chess_com/chess_com_client.dart';
import 'package:chess_trainer/features/import_game/import_controller.dart';
import 'package:chess_trainer/features/import_game/import_state.dart';
import 'package:chess_trainer/features/replay/replay_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  late final TextEditingController _usernameController;

  @override
  void initState() {
    super.initState();
    final ImportState initial = ref.read(importControllerProvider);
    final String initialUsername =
        initial is EnteringUsername ? initial.username : '';
    _usernameController = TextEditingController(text: initialUsername);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ImportState>(importControllerProvider, (
      ImportState? previous,
      ImportState next,
    ) {
      if (next is EnteringUsername && next.username.isNotEmpty) {
        _usernameController.text = next.username;
      }
    });

    final ImportState state = ref.watch(importControllerProvider);
    final ImportController controller = ref.read(
      importControllerProvider.notifier,
    );

    return PopScope<void>(
      canPop: state is! SelectingGame,
      onPopInvokedWithResult: (bool didPop, void result) {
        if (!didPop) controller.backToMonths();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Import Game'),
          leading: state is SelectingGame
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: controller.backToMonths,
                )
              : null,
        ),
        body: switch (state) {
          EnteringUsername(:final String username) => _UsernameEntry(
            controller: _usernameController,
            savedUsername: username,
            onSearch: (String username) => controller.fetchArchives(username),
            onClear: () {
              controller.clearUser();
              _usernameController.clear();
            },
          ),
          LoadingArchives() ||
          LoadingGames() => const Center(child: CircularProgressIndicator()),
          SelectingMonth(:final List<String> archives) => _ArchiveList(
            archives: archives,
            onSelect: (String url) => controller.selectArchive(url),
          ),
          SelectingGame(:final List<GameReplay> games) => _GameList(
            games: games,
            onSelect: (GameReplay game) {
              ref.read(replayControllerProvider.notifier).loadGame(game);
              // Pop when shown as a modal (changing games from replay screen).
              // At first launch ImportScreen is the root, so there's nothing to
              // pop — AppRouter switches to ReplayScreen via state change instead.
              if (Navigator.canPop(context)) Navigator.pop(context);
            },
          ),
          ImportError(:final String message) => _ErrorView(
            message: message,
            onReset: controller.reset,
          ),
        },
      ),
    );
  }
}

class _UsernameEntry extends StatelessWidget {
  const _UsernameEntry({
    required this.controller,
    required this.savedUsername,
    required this.onSearch,
    required this.onClear,
  });

  final TextEditingController controller;
  final String savedUsername;
  final void Function(String) onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Chess.com username',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: onSearch,
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => onSearch(controller.text.trim()),
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Import'),
              ),
            ],
          ),
          if (savedUsername.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 16),
                label: Text('Clear $savedUsername'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArchiveList extends StatelessWidget {
  const _ArchiveList({required this.archives, required this.onSelect});

  final List<String> archives;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: archives.length,
      itemBuilder: (BuildContext context, int index) {
        // Reverse so the most recent month appears first.
        final String archive = archives[archives.length - 1 - index];
        return ListTile(
          title: Text(ChessDotComClient.formatArchive(archive)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onSelect(archive),
        );
      },
    );
  }
}

class _GameList extends StatelessWidget {
  const _GameList({required this.games, required this.onSelect});

  final List<GameReplay> games;
  final void Function(GameReplay) onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: games.length,
      itemBuilder: (BuildContext context, int index) {
        final GameReplay game = games[index];
        return ListTile(
          title: Text('${game.whitePlayer} vs ${game.blackPlayer}'),
          subtitle: Text(
            '${GameReplay.formatResult(game.result)} • ${game.length ~/ 2} moves',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onSelect(game),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onReset});

  final String message;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onReset, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
