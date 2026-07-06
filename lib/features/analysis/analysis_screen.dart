import 'package:chess_trainer/core/chess/position_node.dart';
import 'package:chess_trainer/features/analysis/analysis_provider.dart';
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Import games to see your problem positions.',
          textAlign: TextAlign.center,
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No problem positions found yet.\nImport more games to see results.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: positions.length,
      itemBuilder: (BuildContext context, int index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PositionCard(node: positions[index], rank: index + 1),
        );
      },
    );
  }
}

class _PositionCard extends StatefulWidget {
  const _PositionCard({required this.node, required this.rank});

  final PositionNode node;
  final int rank;

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
    final int lossPercent =
        node.total > 0 ? ((node.losses / node.total) * 100).round() : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Chessboard(
              size: _boardSize,
              controller: _boardController,
              orientation: _orientation,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '#${widget.rank}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$lossPercent% loss rate',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${node.total} games'),
                  const SizedBox(height: 2),
                  Text(
                    '${node.wins}W  ${node.draws}D  ${node.losses}L',
                    style: Theme.of(context).textTheme.bodySmall,
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
