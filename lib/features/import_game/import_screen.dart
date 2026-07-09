import 'package:chess_trainer/core/chess/game_replay.dart';
import 'package:chess_trainer/core/chess_com/chess_com_client.dart';
import 'package:chess_trainer/features/analysis/analysis_screen.dart';
import 'package:chess_trainer/features/analysis/position_detail_screen.dart';
import 'package:chess_trainer/features/games/games_controller.dart';
import 'package:chess_trainer/features/import_game/import_controller.dart';
import 'package:chess_trainer/features/import_game/import_state.dart';
import 'package:chess_trainer/features/replay/replay_controller.dart';
import 'package:chess_trainer/theme/app_theme.dart';
import 'package:chess_trainer/widgets/knight_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _startFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

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

    // The username step is a full-bleed landing screen with no app bar; every
    // other step keeps the standard chrome.
    final bool isEntry = state is EnteringUsername;

    return PopScope<void>(
      canPop: state is! SelectingGame,
      onPopInvokedWithResult: (bool didPop, void result) {
        if (!didPop) controller.backToMonths();
      },
      child: Scaffold(
        appBar: isEntry
            ? null
            : AppBar(
                title: Text(switch (state) {
                  SelectingGame() => 'Pick a game',
                  _ => 'Import games',
                }),
                leading: state is SelectingGame
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: controller.backToMonths,
                      )
                    : null,
                actions: <Widget>[
                  IconButton(
                    tooltip: 'Play vs Stockfish',
                    icon: const Icon(Icons.smart_toy_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const PositionDetailScreen(fen: _startFen),
                      ),
                    ),
                  ),
                ],
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
            :final String username,
            :final String? addingArchive,
          ) =>
            _MonthList(
              username: username,
              archives: archives,
              addedArchives: ref.watch(gamesControllerProvider).addedMonths,
              gameCounts: <String, int>{
                for (final MapEntry<String, List<GameReplay>> e
                    in ref.watch(gamesControllerProvider).gamesByMonth.entries)
                  e.key: e.value.length,
              },
              addingArchive: addingArchive,
              gamesInPool: ref.watch(gamesControllerProvider).games.length,
              onAdd: controller.addMonth,
              onRemove: controller.removeMonth,
              onBrowse: controller.browseArchive,
              onAnalyze: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const AnalysisScreen()),
              ),
            ),
          SelectingGame(:final List<GameReplay> games) => _GameList(
            games: games,
            onSelect: (GameReplay game) {
              ref.read(replayControllerProvider.notifier).loadGame(game);
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

// ── Screen 01 · Username entry ─────────────────────────────────────────────
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
    final ColorScheme colors = theme.colorScheme;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 34),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Center(child: KnightMark(size: 52)),
                const SizedBox(height: 26),
                Text(
                  'Road to 2000',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Train the openings you actually lose from.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant, height: 1.5),
                ),
                const SizedBox(height: 40),
                const _FieldLabel('Chess.com username'),
                const SizedBox(height: 9),
                TextField(
                  controller: controller,
                  autocorrect: false,
                  textInputAction: TextInputAction.go,
                  decoration: const InputDecoration(
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(left: 14, right: 4),
                      child: Text(
                        '@',
                        style: TextStyle(color: AppTheme.faint, fontSize: 16),
                      ),
                    ),
                    prefixIconConstraints: BoxConstraints(minWidth: 0),
                    hintText: 'rookslide_92',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 6, vertical: 15),
                  ),
                  onSubmitted: onSearch,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => onSearch(controller.text.trim()),
                  child: const Text('Begin analysis'),
                ),
                if (savedUsername.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: onClear,
                    child: Text('Clear @$savedUsername'),
                  ),
                ],
                const SizedBox(height: 22),
                Text(
                  'Reads your public archives only.\nNothing is posted or shared.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppTheme.faint, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Screen 02 · Import games ───────────────────────────────────────────────
class _MonthList extends StatelessWidget {
  const _MonthList({
    required this.username,
    required this.archives,
    required this.addedArchives,
    required this.gameCounts,
    required this.addingArchive,
    required this.gamesInPool,
    required this.onAdd,
    required this.onRemove,
    required this.onBrowse,
    required this.onAnalyze,
  });

  final String username;
  final List<String> archives;
  final Set<String> addedArchives;
  final Map<String, int> gameCounts;
  final String? addingArchive;
  final int gamesInPool;
  final void Function(String) onAdd;
  final void Function(String) onRemove;
  final void Function(String) onBrowse;
  // Opens the analysis (Problem Positions) view over the current pool. Only
  // wired up once the pool has games — see the pinned bar below.
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        // Handle for the active user, echoing the design's header subtitle.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '@$username',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
        ),
        // Pool count pill — gold-tinted, makes it obvious "Add" fills the pool.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: _PoolPill(gamesInPool: gamesInPool),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: <Widget>[
              const _FieldLabel('Monthly archives'),
              for (int index = 0; index < archives.length; index++)
                // Reverse so the most recent month appears first.
                _MonthRow(
                  archive: archives[archives.length - 1 - index],
                  addedArchives: addedArchives,
                  gameCounts: gameCounts,
                  addingArchive: addingArchive,
                  onAdd: onAdd,
                  onRemove: onRemove,
                  onBrowse: onBrowse,
                ),
            ],
          ),
        ),
        // Pinned analysis entry point: only meaningful once the pool has games.
        if (gamesInPool > 0)
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.line)),
              ),
              child: FilledButton(
                onPressed: onAnalyze,
                child: const Text('Find my problem positions'),
              ),
            ),
          ),
      ],
    );
  }
}

class _PoolPill extends StatelessWidget {
  const _PoolPill({required this.gamesInPool});

  final int gamesInPool;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color gold = theme.colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.10),
        border: Border.all(color: gold.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: gold, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: gamesInPool == 0
                ? Text(
                    'No games in your pool yet — add a month below.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  )
                : Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: '$gamesInPool',
                          style: TextStyle(
                            color: gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: ' games in your analysis pool'),
                      ],
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.archive,
    required this.addedArchives,
    required this.gameCounts,
    required this.addingArchive,
    required this.onAdd,
    required this.onRemove,
    required this.onBrowse,
  });

  final String archive;
  final Set<String> addedArchives;
  final Map<String, int> gameCounts;
  final String? addingArchive;
  final void Function(String) onAdd;
  final void Function(String) onRemove;
  final void Function(String) onBrowse;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isAdded = addedArchives.contains(archive);
    final bool isAdding = addingArchive == archive;
    final int? count = gameCounts[archive];

    return InkWell(
      onTap: () => onBrowse(archive),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.line)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    ChessDotComClient.formatArchive(archive),
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAdded && count != null
                        ? '$count games'
                        : 'Tap to browse a game',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            _AddTrailing(
              isAdded: isAdded,
              isAdding: isAdding,
              onAdd: () => onAdd(archive),
              onRemove: () => onRemove(archive),
            ),
          ],
        ),
      ),
    );
  }
}

// The trailing control on a month row: a spinner while fetching, a green
// "Added" pill once added, or a gold-outline "Add" pill otherwise. Its own tap
// targets, so pressing them does not trigger the row's browse tap.
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

  static final BorderRadius _pill = BorderRadius.circular(9);

  @override
  Widget build(BuildContext context) {
    if (isAdding) {
      return const SizedBox(
        width: 34,
        height: 18,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final Color gold = Theme.of(context).colorScheme.primary;
    if (isAdded) {
      // Green "Added" pill; tapping it removes the month from the pool.
      return InkWell(
        onTap: onRemove,
        borderRadius: _pill,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.12),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.5)),
            borderRadius: _pill,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.check, size: 15, color: AppTheme.success),
              SizedBox(width: 6),
              Text(
                'Added',
                style: TextStyle(
                  color: AppTheme.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return InkWell(
      onTap: onAdd,
      borderRadius: _pill,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: gold),
          borderRadius: _pill,
        ),
        child: Text(
          'Add',
          style: TextStyle(
            color: gold,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
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
          children: <Widget>[
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

// Small uppercase label used above form fields and list sections in the design.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.faint,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}
