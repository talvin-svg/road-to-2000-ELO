import 'package:chessground/chessground.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess_trainer/features/import_game/import_controller.dart';
import 'package:chess_trainer/features/import_game/import_screen.dart';
import 'package:chess_trainer/features/import_game/import_state.dart';
import 'package:chess_trainer/features/shell/app_shell.dart';
import 'package:chess_trainer/theme/app_theme.dart';

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
      theme: AppTheme.light,
      home: const AppRouter(),
    );
  }
}

// Shows the username entry screen until the user is logged in, then replaces it
// with the persistent sidebar shell.
class AppRouter extends ConsumerWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ImportState importState = ref.watch(importControllerProvider);
    return importState is EnteringUsername
        ? const ImportScreen()
        : const AppShell();
  }
}
