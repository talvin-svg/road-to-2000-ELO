import 'package:chess_trainer/core/chess/game_replay.dart';
import 'package:chess_trainer/core/chess/position_node.dart';
import 'package:chess_trainer/core/chess_com/chess_com_client.dart';
import 'package:chess_trainer/features/analysis/analysis_provider.dart';
import 'package:chess_trainer/features/analysis/analysis_screen.dart';
import 'package:chess_trainer/features/analysis/position_detail_screen.dart';
import 'package:dartchess/dartchess.dart';
import 'package:chess_trainer/features/games/games_controller.dart';
import 'package:chess_trainer/features/import_game/import_controller.dart';
import 'package:chess_trainer/features/import_game/import_state.dart';
import 'package:chess_trainer/features/replay/replay_controller.dart';
import 'package:chess_trainer/features/replay/replay_screen.dart';
import 'package:chess_trainer/features/shell/shell_provider.dart';
import 'package:chess_trainer/theme/app_theme.dart';
import 'package:chess_trainer/widgets/knight_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Shell ─────────────────────────────────────────────────────────────────────
//
// Desktop-first layout: persistent left sidebar (250 px) + scrollable content
// area. The sidebar owns navigation; the content area renders the active section.
// All existing screen bodies (AnalysisBody, ReplayBody, DrillBody) are reused
// here so there is no duplicated display logic.

// Responsive entry point. The two design mockups (mobile + macOS) are the two
// ends of one responsive range, so we pick a layout by width rather than
// shipping two disconnected apps: phones get a bottom-nav layout; tablets and
// desktop get the macOS sidebar shell. Both branches render the *same* section
// bodies, so there's a single source of screen logic.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  // Below this width the 250px sidebar would swallow most of the screen, so we
  // drop it for a bottom NavigationBar. ~720 keeps phones (portrait) on mobile
  // while tablets/desktop get the sidebar.
  static const double _wideBreakpoint = 720;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return constraints.maxWidth >= _wideBreakpoint
            ? const _DesktopShell()
            : const _MobileShell();
      },
    );
  }
}

// Section titles/subtitles, shared by the desktop header and the mobile app bar.
const Map<AppSection, (String, String)> _sectionTitles =
    <AppSection, (String, String)>{
  AppSection.importGames: ('Import games', 'Build your analysis pool'),
  AppSection.problems: ('Problem positions', 'Where you keep losing'),
  AppSection.replay: ('Game replay', 'Step through an imported game'),
  AppSection.drill: ('Play the line', 'Drill against Stockfish'),
};

// ── Desktop / tablet: persistent macOS-style sidebar ────────────────────────────
class _DesktopShell extends ConsumerWidget {
  const _DesktopShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ShellState shell = ref.watch(shellProvider);
    final ShellNotifier shellNotifier = ref.read(shellProvider.notifier);
    final ReplayController replayController =
        ref.read(replayControllerProvider.notifier);

    return Scaffold(
      body: Row(
        children: <Widget>[
          _Sidebar(
            currentSection: shell.section,
            onNavigate: shellNotifier.switchSection,
          ),
          const VerticalDivider(width: 1, thickness: 1, color: AppTheme.line),
          Expanded(
            child: Column(
              children: <Widget>[
                _ShellHeader(
                  section: shell.section,
                  onRestart: shell.section == AppSection.drill
                      ? shellNotifier.restartDrill
                      : null,
                  onFlip: shell.section == AppSection.replay
                      ? replayController.flipBoard
                      : null,
                ),
                const Divider(height: 1, thickness: 1, color: AppTheme.line),
                Expanded(
                  child: _SectionBody(shell: shell, shellNotifier: shellNotifier),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Phone: bottom NavigationBar + native scaffolding ────────────────────────────
class _MobileShell extends ConsumerWidget {
  const _MobileShell();

  // Bottom-nav destinations, in order. Drill is intentionally absent: it's a
  // state you push *into* from a problem card, not a top-level destination.
  static const List<AppSection> _navSections = <AppSection>[
    AppSection.problems,
    AppSection.replay,
    AppSection.importGames,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ShellState shell = ref.watch(shellProvider);
    final ShellNotifier shellNotifier = ref.read(shellProvider.notifier);
    final ReplayController replayController =
        ref.read(replayControllerProvider.notifier);
    final ThemeData theme = Theme.of(context);

    final bool drilling = shell.section == AppSection.drill;
    final (String title, String subtitle) = _sectionTitles[shell.section]!;
    // While drilling, keep "Problems" lit — that's where Back returns you.
    final int selectedIndex =
        drilling ? 0 : _navSections.indexOf(shell.section);

    // Scaffold's AppBar + bottomNavigationBar already inset the body from the
    // status bar and home indicator, so per-screen SafeArea isn't needed here.
    return Scaffold(
      appBar: AppBar(
        leading: drilling
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to problems',
                onPressed: () =>
                    shellNotifier.switchSection(AppSection.problems),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: <Widget>[
          if (drilling)
            IconButton(
              tooltip: 'Restart line',
              icon: const Icon(Icons.refresh),
              onPressed: shellNotifier.restartDrill,
            ),
          if (shell.section == AppSection.replay)
            IconButton(
              tooltip: 'Flip board',
              icon: const Icon(Icons.swap_vert),
              onPressed: replayController.flipBoard,
            ),
        ],
      ),
      body: _SectionBody(shell: shell, shellNotifier: shellNotifier),
      bottomNavigationBar: drilling
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onDestinationSelected: (int index) =>
                  shellNotifier.switchSection(_navSections[index]),
              destinations: const <Widget>[
                NavigationDestination(
                  icon: Icon(Icons.crisis_alert),
                  label: 'Problems',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history),
                  label: 'Replay',
                ),
                NavigationDestination(
                  icon: Icon(Icons.download),
                  label: 'Import',
                ),
              ],
            ),
    );
  }
}

// ── Section body ──────────────────────────────────────────────────────────────
class _SectionBody extends ConsumerWidget {
  const _SectionBody({
    required this.shell,
    required this.shellNotifier,
  });

  final ShellState shell;
  final ShellNotifier shellNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (shell.section) {
      AppSection.importGames => _ImportSection(
          onSwitchSection: shellNotifier.switchSection,
          onGameSelected: (GameReplay game) {
            ref.read(replayControllerProvider.notifier).loadGame(game);
            shellNotifier.switchSection(AppSection.replay);
          },
        ),
      AppSection.problems => AnalysisBody(
          onDrill: (PositionNode node, GameReplay game) {
            final ({
              List<Position> positions,
              List<String> fens,
              List<String> sans,
            }) opening = game.openingUpToDepth(node.depth);
            shellNotifier.startDrill(
              node.fen,
              openingPositions: opening.positions,
              openingFens: opening.fens,
              openingSans: opening.sans,
            );
          },
          onImport: () => shellNotifier.switchSection(AppSection.importGames),
        ),
      AppSection.replay => const ReplayBody(),
      AppSection.drill => shell.drillFen == null
          ? const _NoDrillState()
          : DrillBody(
              key: ValueKey<int>(shell.drillKey),
              fen: shell.drillFen!,
              openingPositions: shell.openingPositions,
              openingFens: shell.openingFens,
              openingSans: shell.openingSans,
            ),
    };
  }
}

class _NoDrillState extends StatelessWidget {
  const _NoDrillState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          'Tap "Play the line" on a problem card to start drilling.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

// ── Shell header ──────────────────────────────────────────────────────────────
class _ShellHeader extends StatelessWidget {
  const _ShellHeader({
    required this.section,
    this.onRestart,
    this.onFlip,
  });

  final AppSection section;
  final VoidCallback? onRestart;
  final VoidCallback? onFlip;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (String title, String subtitle) = _sectionTitles[section]!;

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Row(
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
            ),
            const SizedBox(width: 12),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const Spacer(),
            if (onRestart != null)
              OutlinedButton.icon(
                onPressed: onRestart,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Restart line'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  side: const BorderSide(color: AppTheme.line),
                ),
              ),
            if (onFlip != null)
              OutlinedButton.icon(
                onPressed: onFlip,
                icon: const Icon(Icons.swap_vert, size: 16),
                label: const Text('Flip board'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  side: const BorderSide(color: AppTheme.line),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────
class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.currentSection,
    required this.onNavigate,
  });

  final AppSection currentSection;
  final void Function(AppSection) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ImportState importState = ref.watch(importControllerProvider);
    final GamesState gamesState = ref.watch(gamesControllerProvider);
    final AnalysisResult analysis = ref.watch(analysisProvider);
    final int gamesInPool = gamesState.games.length;
    final int problemCount =
        analysis.worstAsWhite.length + analysis.worstAsBlack.length;
    final String username = _username(importState, gamesState);

    return SizedBox(
      width: 250,
      child: ColoredBox(
        color: AppTheme.sidebarBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // macOS traffic lights (decorative)
            const _TrafficLights(),
            // Brand
            _Brand(),
            const SizedBox(height: 2),
            // User card
            if (username.isNotEmpty) _UserCard(username: username),
            const SizedBox(height: 14),
            // Nav label
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'STUDY',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 10,
                  letterSpacing: 1.6,
                  color: AppTheme.faint,
                ),
              ),
            ),
            // Nav items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: <Widget>[
                  _NavItem(
                    glyph: '◈',
                    label: 'Problem positions',
                    section: AppSection.problems,
                    current: currentSection,
                    badge: problemCount > 0 ? '$problemCount' : null,
                    onTap: () => onNavigate(AppSection.problems),
                  ),
                  _NavItem(
                    glyph: '↺',
                    label: 'Game replay',
                    section: AppSection.replay,
                    current: currentSection,
                    onTap: () => onNavigate(AppSection.replay),
                  ),
                  _NavItem(
                    glyph: '⇩',
                    label: 'Import games',
                    section: AppSection.importGames,
                    current: currentSection,
                    onTap: () => onNavigate(AppSection.importGames),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Pool count pill
            _PoolPill(gamesInPool: gamesInPool, theme: theme),
          ],
        ),
      ),
    );
  }

  String _username(ImportState importState, GamesState gamesState) {
    return switch (importState) {
      SelectingMonth(:final String username) => username,
      SelectingGame(:final String username) => username,
      LoadingArchives(:final String username) => username,
      LoadingGames(:final String username) => username,
      _ => gamesState.username,
    };
  }
}

// Three macOS-style colored dots — purely decorative.
class _TrafficLights extends StatelessWidget {
  const _TrafficLights();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.only(left: 18),
        child: Row(
          children: <Widget>[
            _Dot(color: const Color(0xFFFF5F57)),
            const SizedBox(width: 8),
            _Dot(color: const Color(0xFFFEBC2E)),
            const SizedBox(width: 8),
            _Dot(color: const Color(0xFF28C840)),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

// Brand mark: KnightMark + "Road to 2000" / "Opening trainer".
class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
      child: Row(
        children: <Widget>[
          const KnightMark(size: 34),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Road to 2000',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Opening trainer',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// User card: avatar initial + username + "Chess.com" subtitle.
class _UserCard extends StatelessWidget {
  const _UserCard({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color gold = theme.colorScheme.primary;
    final String initial =
        username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.trackFill,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: AppTheme.mono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: gold,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    username,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Chess.com',
                    style: AppTheme.mono(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A single sidebar nav button.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.glyph,
    required this.label,
    required this.section,
    required this.current,
    required this.onTap,
    this.badge,
  });

  final String glyph;
  final String label;
  final AppSection section;
  final AppSection current;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color gold = theme.colorScheme.primary;
    final bool active = section == current;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: active ? gold.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 20,
                  child: Text(
                    glyph,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: active
                          ? const Color(0xFF7D6330)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? const Color(0xFF7D6330)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (badge != null)
                  Text(
                    badge!,
                    style: AppTheme.mono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.danger,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Gold-tinted pill at the bottom of the sidebar showing pool game count.
class _PoolPill extends StatelessWidget {
  const _PoolPill({required this.gamesInPool, required this.theme});

  final int gamesInPool;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Color gold = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              gold.withValues(alpha: 0.12),
              gold.withValues(alpha: 0.04),
            ],
          ),
          border: Border.all(color: gold.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$gamesInPool',
              style: AppTheme.mono(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: gold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'games in analysis pool',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Import section ────────────────────────────────────────────────────────────
//
// Handles the full ImportController state machine (minus username entry, which
// is shown as a standalone screen before the shell mounts).
class _ImportSection extends ConsumerWidget {
  const _ImportSection({
    required this.onSwitchSection,
    required this.onGameSelected,
  });

  final void Function(AppSection) onSwitchSection;
  final void Function(GameReplay) onGameSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ImportState state = ref.watch(importControllerProvider);
    final ImportController controller =
        ref.read(importControllerProvider.notifier);
    final GamesState gamesState = ref.watch(gamesControllerProvider);

    if (state is LoadingArchives || state is LoadingGames) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is ImportError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: controller.reset,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (state is SelectingGame) {
      return _GameListSection(
        games: state.games,
        onBack: controller.backToMonths,
        onSelect: onGameSelected,
      );
    }

    if (state is SelectingMonth) {
      final int gamesInPool = gamesState.games.length;
      return _MonthGridSection(
        archives: state.archives,
        addingArchive: state.addingArchive,
        addedArchives: gamesState.addedMonths,
        gameCounts: <String, int>{
          for (final MapEntry<String, List<GameReplay>> e
              in gamesState.gamesByMonth.entries)
            e.key: e.value.length,
        },
        gamesInPool: gamesInPool,
        onAdd: controller.addMonth,
        onRemove: controller.removeMonth,
        onBrowse: controller.browseArchive,
        onAnalyze: () => onSwitchSection(AppSection.problems),
      );
    }

    // EnteringUsername shouldn't appear once the shell is mounted, but handle
    // it defensively so the section doesn't show a blank white box.
    return const Center(child: CircularProgressIndicator());
  }
}

// 2-column grid of month cards, matching the design's desktop import layout.
class _MonthGridSection extends StatelessWidget {
  const _MonthGridSection({
    required this.archives,
    required this.addingArchive,
    required this.addedArchives,
    required this.gameCounts,
    required this.gamesInPool,
    required this.onAdd,
    required this.onRemove,
    required this.onBrowse,
    required this.onAnalyze,
  });

  final List<String> archives;
  final String? addingArchive;
  final Set<String> addedArchives;
  final Map<String, int> gameCounts;
  final int gamesInPool;
  final void Function(String) onAdd;
  final void Function(String) onRemove;
  final void Function(String) onBrowse;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final double cardExtent =
        (110 * MediaQuery.textScalerOf(context).scale(1.0)).clamp(110.0, 180.0);
    return Column(
      children: <Widget>[
        Expanded(
          child: CustomScrollView(
            slivers: <Widget>[
              // Pool count banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 16, 26, 14),
                  child: _PoolBanner(gamesInPool: gamesInPool),
                ),
              ),
              // "Monthly archives" label
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 0, 26, 10),
                  child: Text(
                    'MONTHLY ARCHIVES',
                    style: AppTheme.mono(
                      fontSize: 10,
                      color: AppTheme.faint,
                    ).copyWith(letterSpacing: 1.6),
                  ),
                ),
              ),
              // Month grid — scrolls with the rest of the page.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: cardExtent,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: archives.length,
                  itemBuilder: (BuildContext context, int index) {
                    // Most recent month first.
                    final String archive = archives[archives.length - 1 - index];
                    final bool isAdded = addedArchives.contains(archive);
                    final bool isAdding = addingArchive == archive;
                    final int? count = gameCounts[archive];
                    return _MonthCard(
                      archive: archive,
                      isAdded: isAdded,
                      isAdding: isAdding,
                      gameCount: count,
                      onAdd: () => onAdd(archive),
                      onRemove: () => onRemove(archive),
                      onBrowse: () => onBrowse(archive),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Pinned at the bottom — always visible regardless of scroll position.
        if (gamesInPool > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(26, 12, 26, 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.line)),
            ),
            child: FilledButton(
              onPressed: onAnalyze,
              child: const Text('Find my problem positions'),
            ),
          ),
      ],
    );
  }
}

// A single month card with Add/spinner/Added trailing control.
class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.archive,
    required this.isAdded,
    required this.isAdding,
    required this.gameCount,
    required this.onAdd,
    required this.onRemove,
    required this.onBrowse,
  });

  final String archive;
  final bool isAdded;
  final bool isAdding;
  final int? gameCount;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onBrowse,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    ChessDotComClient.formatArchive(archive),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAdded && gameCount != null
                        ? '$gameCount games'
                        : 'Tap to browse',
                    style: AppTheme.mono(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _MonthAction(
              isAdded: isAdded,
              isAdding: isAdding,
              onAdd: onAdd,
              onRemove: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthAction extends StatelessWidget {
  const _MonthAction({
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
        width: 42,
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
      return GestureDetector(
        onTap: onRemove,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.12),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.5)),
            borderRadius: _pill,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.check, size: 14, color: AppTheme.success),
              SizedBox(width: 4),
              Text(
                'Added',
                style: TextStyle(
                  color: AppTheme.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: gold),
          borderRadius: _pill,
        ),
        child: Text(
          'Add',
          style: TextStyle(
            color: gold,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// Gold pool-count banner shown above the month grid.
class _PoolBanner extends StatelessWidget {
  const _PoolBanner({required this.gamesInPool});

  final int gamesInPool;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color gold = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.10),
        border: Border.all(color: gold.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: gold, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
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
                          style: AppTheme.mono(
                            fontWeight: FontWeight.w700,
                            color: gold,
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

// Shown when the user browses a month — lists games and lets them pick one for replay.
class _GameListSection extends StatelessWidget {
  const _GameListSection({
    required this.games,
    required this.onBack,
    required this.onSelect,
  });

  final List<GameReplay> games;
  final VoidCallback onBack;
  final void Function(GameReplay) onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 26, 4),
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Monthly archives'),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(26, 4, 26, 26),
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final GameReplay game = games[index];
              return InkWell(
                onTap: () => onSelect(game),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border.all(color: AppTheme.line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${game.whitePlayer} vs ${game.blackPlayer}',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${GameReplay.formatResult(game.result)} · ${game.length ~/ 2} moves',
                              style: AppTheme.mono(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
