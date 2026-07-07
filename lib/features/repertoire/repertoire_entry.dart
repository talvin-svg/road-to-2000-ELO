// One decision in your repertoire: "in THIS position, my move is X."
//
// [fen] is the normalized position key (see normalizeFen) so it lines up with
// the same position anywhere else in the app — the registry, a later lookup by
// the play-out loop. [uci] is the move the training loop checks your answer
// against ('e2e4'); [san] is the human-readable form for display ('e4').
class RepertoireEntry {
  const RepertoireEntry({
    required this.fen,
    required this.uci,
    required this.san,
  });

  final String fen;
  final String uci;
  final String san;
}
