import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppSection { importGames, problems, replay, drill }

class ShellState {
  const ShellState({
    this.section = AppSection.importGames,
    this.drillFen,
    this.drillKey = 0,
    this.openingPositions,
    this.openingFens,
    this.openingSans,
  });

  final AppSection section;
  // The FEN being drilled. Null until a problem card is tapped.
  final String? drillFen;
  // Incremented on restart — gives DrillBody a new ValueKey so it rebuilds fresh.
  final int drillKey;
  // Pre-loaded opening history from the chosen game. When non-null, DrillBody
  // seeds its position history with these before the drill starts, so the user
  // can navigate back through the moves that led to the problem position.
  final List<Position>? openingPositions;
  final List<String>? openingFens;
  final List<String>? openingSans;

  ShellState copyWith({
    AppSection? section,
    String? drillFen,
    int? drillKey,
    List<Position>? openingPositions,
    List<String>? openingFens,
    List<String>? openingSans,
  }) =>
      ShellState(
        section: section ?? this.section,
        drillFen: drillFen ?? this.drillFen,
        drillKey: drillKey ?? this.drillKey,
        openingPositions: openingPositions ?? this.openingPositions,
        openingFens: openingFens ?? this.openingFens,
        openingSans: openingSans ?? this.openingSans,
      );
}

class ShellNotifier extends Notifier<ShellState> {
  @override
  ShellState build() => const ShellState();

  void switchSection(AppSection section) =>
      state = state.copyWith(section: section);

  void startDrill(
    String fen, {
    List<Position>? openingPositions,
    List<String>? openingFens,
    List<String>? openingSans,
  }) =>
      state = ShellState(
        section: AppSection.drill,
        drillFen: fen,
        drillKey: state.drillKey,
        openingPositions: openingPositions,
        openingFens: openingFens,
        openingSans: openingSans,
      );

  void restartDrill() => state = state.copyWith(drillKey: state.drillKey + 1);
}

final NotifierProvider<ShellNotifier, ShellState> shellProvider =
    NotifierProvider<ShellNotifier, ShellState>(ShellNotifier.new);
