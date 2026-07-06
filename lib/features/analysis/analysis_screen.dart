import 'package:chess_trainer/core/chess/position_node.dart';
import 'package:chess_trainer/features/analysis/analysis_provider.dart';
import 'package:chess_trainer/features/analysis/position_detail_screen.dart';
import 'package:chess_trainer/theme/app_theme.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AnalysisResult result = ref.watch(analysisProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Problem Positions'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'As White'),
              Tab(text: 'As Black'),
            ],
          ),
        ),
        body: !result.hasData
            ? const _EmptyState()
            : TabBarView(
                children: <Widget>[
                  _PositionList(positions: result.worstAsWhite),
                  _PositionList(positions: result.worstAsBlack),
                ],
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      icon: Icons.insights_outlined,
      title: 'No positions yet',
      body: 'Import games to surface the openings you lose from most.',
    );
  }
}

// Shared empty/placeholder layout: a muted icon, a serif title, muted body.
class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionList extends StatelessWidget {
  const _PositionList({required this.positions});

  final List<PositionNode> positions;

  @override
  Widget build(BuildContext context) {
    if (positions.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.search_off_outlined,
        title: 'Nothing to show here',
        body: 'No problem positions for this colour yet — import more games.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: positions.length,
      itemBuilder: (BuildContext context, int index) {
        final PositionNode node = positions[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PositionCard(
            node: node,
            rank: index + 1,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => PositionDetailScreen(fen: node.fen),
              ),
            ),
          ),
        );
      },
    );
  }
}

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

  static const double _boardSize = 120;

  @override
  void initState() {
    super.initState();
    final String fen = widget.node.fen;
    final Side sideToMove = fen.split(' ')[1] == 'w' ? Side.white : Side.black;
    // Show the board from the perspective of the side that has to move —
    // that's always Talvin's side, since stats are only recorded at his turns.
    final Side orientation = sideToMove;
    _boardController = ChessboardController(
      game: GameData(
        fen: fen,
        playerSide: PlayerSide.none, // view-only; no move interaction
        sideToMove: sideToMove,
        validMoves: const {},
      ),
    );
    _orientation = orientation;
  }

  late final Side _orientation;

  @override
  void dispose() {
    _boardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PositionNode node = widget.node;
    final ThemeData theme = Theme.of(context);
    final double lossRate = node.lossRate;
    final int lossPercent = (lossRate * 100).round();

    return Card(
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      // Serif gold rank badge.
                      Text(
                        '#${widget.rank}',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                      const Spacer(),
                      // Big monospace loss percentage — the "techy" tell.
                      Text(
                        '$lossPercent%',
                        style: AppTheme.mono(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'loss rate',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  // Visual loss bar.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: lossRate,
                      minHeight: 6,
                      color: theme.colorScheme.error,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${node.total} games',
                    style: AppTheme.mono(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${node.wins}W  ${node.draws}D  ${node.losses}L',
                    style: AppTheme.mono(fontSize: 13),
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
