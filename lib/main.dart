import 'package:chessground/chessground.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/replay/replay_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-load piece images so pieces aren't invisible on the board's first frame.
  await ChessgroundImages.instance.loadAll(
    PieceSet.cburnettAssets,
    devicePixelRatio:
        WidgetsBinding.instance.platformDispatcher.implicitView?.devicePixelRatio,
  );
  runApp(const ProviderScope(child: ChessTrainerApp()));
}

class ChessTrainerApp extends StatelessWidget {
  const ChessTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Trainer',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const ReplayScreen(),
    );
  }
}
