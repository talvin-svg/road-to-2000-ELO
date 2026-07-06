import 'package:chess_trainer/core/chess/game_replay.dart';
import 'package:chess_trainer/core/chess_com/chess_com_client.dart';
import 'package:chess_trainer/features/games/games_controller.dart';
import 'package:chess_trainer/features/import_game/import_controller.dart';
import 'package:chess_trainer/features/import_game/import_state.dart';
import 'package:chess_trainer/features/replay/replay_controller.dart';
import 'package:chess_trainer/theme/app_theme.dart';
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
          leading:
              state is SelectingGame
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
          SelectingMonth(
            :final List<String> archives,
            :final String? addingArchive,
          ) =>
            _MonthList(
              archives: archives,
              addedArchives: ref.watch(gamesControllerProvider).addedMonths,
              addingArchive: addingArchive,
              gamesInPool: ref.watch(gamesControllerProvider).games.length,
              onAdd: controller.addMonth,
              onRemove: controller.removeMonth,
              onBrowse: controller.browseArchive,
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
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chess Trainer', style: theme.textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(
            'Import your Chess.com games to find the openings you lose from.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
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

class _MonthList extends StatelessWidget {
  const _MonthList({
    required this.archives,
    required this.addedArchives,
    required this.addingArchive,
    required this.gamesInPool,
    required this.onAdd,
    required this.onRemove,
    required this.onBrowse,
  });

  final List<String> archives;
  final Set<String> addedArchives;
  final String? addingArchive;
  final int gamesInPool;
  final void Function(String) onAdd;
  final void Function(String) onRemove;
  final void Function(String) onBrowse;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        // Running total — makes it obvious that "Add" is what fills the pool.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: <Widget>[
              Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              if (gamesInPool == 0)
                Expanded(
                  child: Text(
                    'No games in your analysis pool yet — add a month below.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              else ...<Widget>[
                Text(
                  '$gamesInPool',
                  style: AppTheme.mono(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'games in your analysis pool',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: archives.length,
            itemBuilder: (BuildContext context, int index) {
              // Reverse so the most recent month appears first.
              final String archive = archives[archives.length - 1 - index];
              final bool isAdded = addedArchives.contains(archive);
              final bool isAdding = addingArchive == archive;
              return ListTile(
                title: Text(ChessDotComClient.formatArchive(archive)),
                subtitle: const Text('Tap to browse games'),
                trailing: _AddTrailing(
                  isAdded: isAdded,
                  isAdding: isAdding,
                  onAdd: () => onAdd(archive),
                  onRemove: () => onRemove(archive),
                ),
                onTap: () => onBrowse(archive),
              );
            },
          ),
        ),
      ],
    );
  }
}

// The trailing control on a month row: a spinner while fetching, a ✓ once
// added, or an Add button otherwise. Its own tap target, so pressing Add does
// not trigger the row's browse tap.
class _AddTrailing extends StatelessWidget {
  const _AddTrailing({
    required this.isAdded,
    required this.isAdding,
    required this.onAdd,
    required this.onRemove,
  });

  final bool isAdded;
  final bool isAdding;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (isAdding) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (isAdded) {
      // ✓ plus a remove button that takes this month back out of the pool.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.check_circle,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          IconButton(
            tooltip: 'Remove from pool',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onRemove,
          ),
        ],
      );
    }
    return TextButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add'),
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
