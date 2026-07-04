# Chess Opening Trainer — Project Journal

## What this is

A personal chess opening trainer, built in Flutter, in milestones. This is explicitly a **learning project** for Talvin — the goal isn't just working software, it's for Talvin to grow as a developer through building it. It's not a zero-to-hero tutorial, though: each milestone should produce something real and runnable, not toy exercises.

## Working agreement (read this before writing any code)

- Explain key decisions **as they happen** — pause at real decision points (architecture choices, API shapes, tricky bugs) and discuss them, don't just deliver a finished result with a summary attached at the end. This was explicitly called out as a miss during Milestone 1: work got done correctly but heads-down, with one large report at the end instead of real back-and-forth.
- Keep steps small. Prefer clear, idiomatic code over clever abstractions.
- Call out relevant `dartchess`/`chessground` APIs and Flutter concepts as they come up, in context, not as a glossary dump.
- Keep "Talvin's developer skill inventory" updated as work continues — this is part of the point of the project, not bookkeeping overhead. It tracks Talvin's actual growth as a developer, not what's been discussed in a session.

## End goal (full scope — do not build ahead of the current milestone)

Import Talvin's own games from Chess.com, aggregate them into a FEN-keyed position tree to find the specific opening positions where he keeps losing to higher-rated players, help him build a repertoire for those spots (using the Lichess Opening Explorer API for candidate moves), then drill them by playing out the line — first against the app, later against Stockfish — with spaced-repetition scheduling.

## Roadmap

1. **Board + game replay** — ✅ done, see "Current status"
2. Chess.com import (archives → monthly games → PGN)
3. Aggregate games into a FEN-keyed tree, surface worst positions
4. Build repertoire (Lichess Opening Explorer) + play-out training loop
5. Persistence + spaced repetition
6. Stockfish engine integration

Only build the current milestone. Don't scaffold later milestones early "for convenience" — the whole point is small, discussable steps.

## Current status

Milestone 1 is functionally complete and verified end-to-end (see "What's built"). However: **we are mid-retrospective**, going back through the Milestone 1 code together, piece by piece, because the first pass through it wasn't actually discussed as it was built.

**Where to resume:** we just finished discussing Part 1 — why the code is split into `core/chess/` (UI-agnostic chess logic) vs `features/replay/` (this screen's state + UI), and the dependency direction between them. Next up, in order:
1. The dartchess API used in `game_replay.dart` — `PgnGame.parsePgn`, `Position.parseSan`/`.play`, why `Position` is immutable.
2. The Riverpod controller (`replay_state.dart` / `replay_controller.dart`) — plain `Notifier`/`NotifierProvider`, no codegen.
3. The chessground widget wiring in `replay_screen.dart` — `ChessboardController`, `GameData`, and specifically `ref.watch` vs `ref.listen` (why the board update is driven through `listen`, not `watch`).

After the retrospective is done, the next real work is Milestone 2 (Chess.com import) — do not start it until the retrospective is finished, unless Talvin says otherwise.

## What's built (Milestone 1)

- `lib/core/chess/game_replay.dart` — wraps dartchess: PGN → indexable list of `{fen, san, move, checkedKingSquare}`, so stepping through a game is an O(1) lookup instead of re-parsing.
- `lib/core/chess/sample_games.dart` — placeholder PGN (Morphy's "Opera Game", 1858), isolated in its own file so swapping in a real Chess.com game in Milestone 2 is a one-line change.
- `lib/features/replay/replay_state.dart`, `replay_controller.dart` — Riverpod state for current ply + board orientation.
- `lib/features/replay/replay_screen.dart` — interactive `chessground` board, SAN move list (click to jump), next/previous/start/end controls, flip-board button.
- Runs on Chrome via `flutter run -d chrome --wasm` (the `--wasm` flag is required — see gotchas below). `.claude/launch.json` already has this wired up for the preview tooling.

## Environment gotchas — don't "fix" these away without understanding why they're there

- **Flutter is pinned to 3.32.0**, globally on this machine (not project-local) — macOS 13.0 can't run Flutter's tool binary on 3.4x+ (needs macOS 14+). If Flutter seems "out of date," that's why — upgrading will break the tool entirely on this OS.
- **`--wasm` is required** to run this app on web at all. `dartchess`'s `SquareSet` bitboard code uses raw 64-bit integer literals (e.g. `0xffffffffffffffff`) that the standard JS compiler (dart2js/dartdevc) rejects outright — only Dart's WASM compile target has real 64-bit integers. This isn't optional polish, the app does not compile for web without it.
- `pubspec.yaml` has a `dependency_overrides: meta: ^1.18.0` — chessground 10.x needs a newer `meta` package than Flutter 3.32.0's bundled `flutter_test` provides. Verified this override is safe by checking meta's changelog (the 1.17 → 1.18 diff is purely additive annotations, nothing removed).

## Talvin's developer skill inventory

This is about **Talvin's own knowledge as a developer** — not "what's been discussed in chat." The point is to track real skill growth over the life of this project: what he already brings, what he's shaky on or hasn't touched, and what he's actually picked up as a result of building this. Keep entries short and honest; move things between sections as they're genuinely learned, not just mentioned.

*(Baseline below is inferred from "some Flutter experience" at project start — Talvin should correct/fill this in, it's a guess, not a real assessment.)*

### What I already know (coming in)
- General Flutter app structure (widgets, `StatefulWidget`, basic layout) — has prior experience, level of depth unconfirmed.

### What I don't know yet / haven't done before
- Riverpod (any version) — first real use is this project.
- dartchess / chessground specifically, and chess-programming concepts generally (FEN, SAN, bitboards, position trees).
- Consuming a third-party REST API from Flutter (needed soon for Chess.com import).
- Anything about spaced-repetition scheduling algorithms.
- Flutter's rendering internals (`CustomPainter`, compile targets like wasm vs JS) beyond surface level.

### What I've actually learned so far (running log — append short entries as real understanding lands, not just exposure)
*(empty — nothing has been confirmed-learned yet; Milestone 1 was built without pausing to actually teach, so nothing here should be assumed. Fill this in as the retrospective happens.)*

## Open technical questions for the project (not skill-tracking — just unresolved research)

- [ ] Chess.com's public API shape (archives endpoint, monthly-games format) — needed for Milestone 2, not yet researched.
- [ ] Lichess Opening Explorer API shape — needed for Milestone 4, not yet researched.
- [ ] Spaced-repetition algorithm choice (e.g. SM-2 vs FSRS) — needed for Milestone 5, not yet decided.

---
*This is a living document. Update "Current status" and "Talvin's developer skill inventory" as work continues — an agent picking this up cold should read this whole file before touching code.*
