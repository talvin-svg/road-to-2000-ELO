import 'package:chess_trainer/core/chess/position_node.dart';
import 'package:chess_trainer/core/chess/position_tree.dart';
import 'package:chess_trainer/features/games/games_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Plain container bundling the two finished baskets from worstPositions() —
// one per colour. Each list arrives already filtered and sorted worst-first, so
// the UI just maps worstAsWhite -> "As White" tab and worstAsBlack -> "As Black"
// tab. `empty()` is the no-games case; `hasData` lets the screen choose between
// showing the lists and showing the empty state.
class AnalysisResult {
  const AnalysisResult({
    required this.worstAsWhite,
    required this.worstAsBlack,
  });
  const AnalysisResult.empty()
      : worstAsWhite = const <PositionNode>[],
        worstAsBlack = const <PositionNode>[];

  final List<PositionNode> worstAsWhite;
  final List<PositionNode> worstAsBlack;

  bool get hasData => worstAsWhite.isNotEmpty || worstAsBlack.isNotEmpty;
}

/// Derived provider: rebuilds automatically whenever [gamesControllerProvider]
/// changes (i.e. a new month is imported). The tree is computed once per
/// change and cached until the next one.
final Provider<AnalysisResult> analysisProvider =
    Provider<AnalysisResult>((Ref ref) {
  final GamesState state = ref.watch(gamesControllerProvider);
  if (state.games.isEmpty) return const AnalysisResult.empty();

  final PositionTree tree = PositionTree.build(state.games, state.username);
  return AnalysisResult(
    worstAsWhite: tree.worstPositions(asWhite: true),
    worstAsBlack: tree.worstPositions(asWhite: false),
  );
});
