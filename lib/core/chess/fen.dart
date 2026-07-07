// The one and only rule for turning a full FEN into a position key.
//
// Keep it here, in one place: both the position registry (PositionTree) and the
// repertoire key positions by this. If the two ever normalized differently — by
// so much as a stray space — a move you picked for a position would silently
// fail to match the same position elsewhere. One function, one rule.
//
// The key is the first 4 FEN fields (piece placement, side to move, castling
// rights, en-passant square) and NOT the halfmove clock or fullmove number.
// Those last two only count moves: two transpositions can differ on them while
// being the exact same position, so dropping them is what lets them merge.
String normalizeFen(String fen) => fen.split(' ').take(4).join(' ');
