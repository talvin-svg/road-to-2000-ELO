import 'package:chess_trainer/core/chess/game_replay.dart';
import 'package:chess_trainer/features/import_game/import_controller.dart';
import 'package:chess_trainer/features/import_game/import_state.dart';
import 'package:chess_trainer/features/replay/replay_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatArchive(String archiveUrl) {
  final List<String> segments = archiveUrl.split('/');
  final int year = int.parse(segments[segments.length - 2]);
  final int month = int.parse(segments[segments.length - 1]);
  return '${_monthNames[month - 1]} $year';
}

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
    _usernameController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ImportState state = ref.watch(importControllerProvider);
    final ImportController controller = ref.read(
      importControllerProvider.notifier,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Import Game')),
      body: switch (state) {
        EnteringUsername() => _UsernameEntry(
          controller: _usernameController,
          onSearch: (String username) => controller.fetchArchives(username),
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
            controller.reset();
            Navigator.pop(context);
          },
        ),
        ImportError(:final String message) => _ErrorView(
          message: message,
          onReset: controller.reset,
        ),
      },
    );
  }
}

class _UsernameEntry extends StatelessWidget {
  const _UsernameEntry({required this.controller, required this.onSearch});

  final TextEditingController controller;
  final void Function(String) onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Chess.com username',
              border: OutlineInputBorder(),
            ),
            onSubmitted: onSearch,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => onSearch(controller.text.trim()),
            child: const Text('Search'),
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
          title: Text(_formatArchive(archive)),
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
          title: Text('Game ${index + 1}'),
          subtitle: Text('${game.length ~/ 2} moves'),
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
