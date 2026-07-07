import 'package:chess_trainer/core/chess/fen.dart';
import 'package:chess_trainer/features/repertoire/repertoire_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Your repertoire: the positions you've committed a move to, keyed by the
// normalized FEN. Just a Map — one position has exactly one chosen move, and
// re-picking overwrites it. In-memory for now; persistence arrives in M5.
//
// This controller is the boundary that OWNS normalization on writes: pick/remove
// take whatever FEN the caller happens to hold and normalize it internally, so
// no call site can accidentally store an un-normalized key that would never
// match a lookup.
class RepertoireController extends Notifier<Map<String, RepertoireEntry>> {
  @override
  Map<String, RepertoireEntry> build() => const <String, RepertoireEntry>{};

  // Commit a move for a position (or replace the existing choice). A new map is
  // built rather than mutated so Riverpod detects the change and rebuilds.
  void pick({required String fen, required String uci, required String san}) {
    final String key = normalizeFen(fen);
    state = <String, RepertoireEntry>{
      ...state,
      key: RepertoireEntry(fen: key, uci: uci, san: san),
    };
  }

  // Drop the choice for a position (e.g. tapping the already-picked move again).
  void remove(String fen) {
    final String key = normalizeFen(fen);
    state = Map<String, RepertoireEntry>.of(state)..remove(key);
  }
}

final NotifierProvider<RepertoireController, Map<String, RepertoireEntry>>
    repertoireControllerProvider =
    NotifierProvider<RepertoireController, Map<String, RepertoireEntry>>(
  RepertoireController.new,
);
