import 'package:chess_trainer/core/chess/game_replay.dart';
import 'package:chess_trainer/core/chess/position_node.dart';
import 'package:chess_trainer/features/analysis/analysis_provider.dart';
import 'package:chess_trainer/features/analysis/position_detail_screen.dart';
import 'package:chess_trainer/theme/app_theme.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Standalone screen: wraps AnalysisBody with an AppBar, using Navigator-push
// for the drill action. The shell uses AnalysisBody directly with its own callbacks.
class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Problem positions'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Openings ranked by how often you lose',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        ),
      ),
      body: AnalysisBody(
        onDrill: (PositionNode node, GameReplay game) {
          final ({List<Position> positions, List<String> fens, List<String> sans}) opening =
              game.openingUpToDepth(node.depth);
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PositionDetailScreen(
                fen: node.fen,
                openingPositions: opening.positions,
                openingFens: opening.fens,
                openingSans: opening.sans,
              ),
            ),
          );
        },
      ),
    );
  }
}

// Reusable body — used by AnalysisScreen (standalone) and AppShell (problems section).
// onDrill: called with the node and the chosen game when a card is tapped. If the
//          node has only one game the picker is skipped; if it has several a bottom
//          sheet lets the user pick. The caller receives both so it can build the
//          opening history and launch the drill with the right context.
// onImport: called when the empty-state "Import games" button is tapped; defaults
//           to Navigator.maybePop so the standalone screen pops back to Import.
class AnalysisBody extends ConsumerStatefulWidget {
  const AnalysisBody({
    required this.onDrill,
    this.onImport,
    super.key,
  });

  final void Function(PositionNode node, GameReplay game) onDrill;
  final VoidCallback? onImport;

  @override
  ConsumerState<AnalysisBody> createState() => _AnalysisBodyState();
}

class _AnalysisBodyState extends ConsumerState<AnalysisBody> {
  bool _showWhite = true;

  // If the node has only one game, skip the picker and drill immediately.
  // Otherwise show a bottom sheet so the user can choose which game to replay.
  Future<void> _handleCardTap(PositionNode node) async {
    if (node.games.isEmpty) return;
    final GameReplay game;
    if (node.games.length == 1) {
      game = node.games.first;
    } else {
      final GameReplay? picked = await showModalBottomSheet<GameReplay>(
        context: context,
        showDragHandle: true,
        builder: (_) => _GamePickerSheet(
          node: node,
          playerIsWhite: node.isWhitesTurn,
        ),
      );
      if (picked == null) return;
      if (!context.mounted) return;
      game = picked;
    }
    widget.onDrill(node, game);
  }

  @override
  Widget build(BuildContext context) {
    final AnalysisResult result = ref.watch(analysisProvider);
    final List<PositionNode> positions =
        _showWhite ? result.worstAsWhite : result.worstAsBlack;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
          child: _ColorTabs(
            showWhite: _showWhite,
            enabled: result.hasData,
            onChanged: (bool white) => setState(() => _showWhite = white),
          ),
        ),
        Expanded(
          child: !result.hasData
              ? _EmptyState(
                  onImport: widget.onImport ??
                      () => Navigator.of(context).maybePop(),
                )
              : _PositionList(
                  positions: positions,
                  onCardTap: _handleCardTap,
                ),
        ),
      ],
    );
  }
}

// ── Rounded segmented control ─────────────────────────────────────────────────
class _ColorTabs extends StatelessWidget {
  const _ColorTabs({
    required this.showWhite,
    required this.enabled,
    required this.onChanged,
  });

  final bool showWhite;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: <Widget>[
            _TabButton(
              label: 'As White',
              selected: showWhite,
              onTap: enabled ? () => onChanged(true) : null,
            ),
            _TabButton(
              label: 'As Black',
              selected: !showWhite,
              onTap: enabled ? () => onChanged(false) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color gold = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? gold.withValues(alpha: 0.16) : Colors.transparent,
            border: Border.all(
              color: selected
                  ? gold.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.line),
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: GridView.count(
                crossAxisCount: 4,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  for (int i = 0; i < 16; i++)
                    ColoredBox(
                      color: (i + i ~/ 4).isEven
                          ? AppTheme.trackFill
                          : theme.colorScheme.surface,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('No positions yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Import games to surface the openings you lose from most.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onImport,
              child: const Text('Import games'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Position list ─────────────────────────────────────────────────────────────
class _PositionList extends StatelessWidget {
  const _PositionList({
    required this.positions,
    required this.onCardTap,
  });

  final List<PositionNode> positions;
  final void Function(PositionNode node) onCardTap;

  @override
  Widget build(BuildContext context) {
    if (positions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            'No problem positions for this colour yet — import more games.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: positions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final PositionNode node = positions[index];
        return _PositionCard(
          node: node,
          rank: index + 1,
          onTap: () => onCardTap(node),
        );
      },
    );
  }
}

// ── Position card ─────────────────────────────────────────────────────────────
class _PositionCard extends StatefulWidget {
  const _PositionCard({
    required this.node,
    required this.rank,
    required this.onTap,
  });

  final PositionNode node;
  final int rank;
  final VoidCallback onTap;

  @override
  State<_PositionCard> createState() => _PositionCardState();
}

class _PositionCardState extends State<_PositionCard> {
  late final ChessboardController _boardController;
  late final Side _orientation;

  static const double _boardSize = 82;

  @override
  void initState() {
    super.initState();
    final String fen = widget.node.fen;
    final Side sideToMove = fen.split(' ')[1] == 'w' ? Side.white : Side.black;
    _boardController = ChessboardController(
      game: GameData(
        fen: fen,
        playerSide: PlayerSide.none,
        sideToMove: sideToMove,
        validMoves: const {},
      ),
    );
    _orientation = sideToMove;
  }

  @override
  void dispose() {
    _boardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PositionNode node = widget.node;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final double lossRate = node.lossRate;
    final int lossPercent = (lossRate * 100).round();
    final int moveNumber = (node.depth / 2).ceil();

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          height: _boardSize,
          child: Row(
            children: <Widget>[
              SizedBox(
                width: _boardSize,
                height: _boardSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Chessboard(
                        size: _boardSize,
                        settings: AppTheme.boardSettings,
                        controller: _boardController,
                        orientation: _orientation,
                      ),
                    ),
                    Positioned(
                      top: -7,
                      left: -7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(7),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x40000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '#${widget.rank}',
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                node.isWhitesTurn
                                    ? 'White to move'
                                    : 'Black to move',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'after move $moveNumber',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$lossPercent%',
                          style: AppTheme.mono(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: colors.error,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: lossRate,
                        minHeight: 6,
                        color: colors.error,
                        backgroundColor: AppTheme.trackFill,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${node.wins}W · ${node.draws}D · ${node.losses}L · ${node.total} games',
                      style: AppTheme.mono(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Game picker bottom sheet ──────────────────────────────────────────────────
// Shows when a problem position has been reached via multiple games so the user
// can choose which one to replay the opening from.
class _GamePickerSheet extends StatelessWidget {
  const _GamePickerSheet({
    required this.node,
    required this.playerIsWhite,
  });

  final PositionNode node;
  final bool playerIsWhite;

  String _opponent(GameReplay game) =>
      playerIsWhite ? game.blackPlayer : game.whitePlayer;

  // W / D / L from the player's perspective.
  (String, Color) _result(GameReplay game, ColorScheme colors) {
    final String r = game.result;
    if ((playerIsWhite && r == '1-0') || (!playerIsWhite && r == '0-1')) {
      return ('W', AppTheme.success);
    }
    if ((playerIsWhite && r == '0-1') || (!playerIsWhite && r == '1-0')) {
      return ('L', AppTheme.danger);
    }
    if (r == '1/2-1/2') return ('D', colors.onSurfaceVariant);
    return ('?', colors.onSurfaceVariant);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: <Widget>[
                Text(
                  'Choose a game',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${node.games.length} games',
                  style: AppTheme.mono(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.line),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              itemCount: node.games.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (BuildContext ctx, int i) {
                final GameReplay game = node.games[i];
                final (String label, Color color) = _result(game, colors);
                final int movesPlayed = game.length ~/ 2;

                return InkWell(
                  onTap: () => Navigator.pop(ctx, game),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: AppTheme.line),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            label,
                            style: AppTheme.mono(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'vs ${_opponent(game)}',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '$movesPlayed moves',
                                style: AppTheme.mono(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
