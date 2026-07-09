import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppSection { importGames, problems, replay, drill }

class ShellState {
  const ShellState({
    this.section = AppSection.importGames,
    this.drillFen,
    this.drillKey = 0,
  });

  final AppSection section;
  // The FEN being drilled. Null until a problem card is tapped.
  final String? drillFen;
  // Incremented on restart — gives DrillBody a new ValueKey so it rebuilds fresh.
  final int drillKey;

  ShellState copyWith({AppSection? section, String? drillFen, int? drillKey}) =>
      ShellState(
        section: section ?? this.section,
        drillFen: drillFen ?? this.drillFen,
        drillKey: drillKey ?? this.drillKey,
      );
}

class ShellNotifier extends Notifier<ShellState> {
  @override
  ShellState build() => const ShellState();

  void switchSection(AppSection section) =>
      state = state.copyWith(section: section);

  void startDrill(String fen) => state = ShellState(
        section: AppSection.drill,
        drillFen: fen,
        drillKey: state.drillKey,
      );

  void restartDrill() => state = state.copyWith(drillKey: state.drillKey + 1);
}

final NotifierProvider<ShellNotifier, ShellState> shellProvider =
    NotifierProvider<ShellNotifier, ShellState>(ShellNotifier.new);
