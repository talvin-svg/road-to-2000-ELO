import 'package:chessground/chessground.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess_trainer/features/import_game/import_screen.dart';
import 'package:chess_trainer/features/replay/replay_controller.dart';
import 'package:chess_trainer/features/replay/replay_screen.dart';
import 'package:chess_trainer/features/replay/replay_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-load piece images so pieces aren't invisible on the board's first frame.
  await ChessgroundImages.instance.loadAll(
    PieceSet.cburnettAssets,
    devicePixelRatio:
        WidgetsBinding
            .instance
            .platformDispatcher
            .implicitView
            ?.devicePixelRatio,
  );
  runApp(const ProviderScope(child: ChessSensei()));
}

class ChessSensei extends StatelessWidget {
  const ChessSensei({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Trainer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      home: const AppRouter(),
    );
  }
}

class AppRouter extends ConsumerWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReplayState state = ref.watch(replayControllerProvider);
    return state.game == null ? const ImportScreen() : const ReplayScreen();
  }
}
