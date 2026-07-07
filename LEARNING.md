# Chess Opening Trainer — Project Journal

## What this is

A personal chess opening trainer, built in Flutter, in milestones. This is explicitly a **learning project** for Talvin — the goal isn't just working software, it's for Talvin to grow as a developer through building it. It's not a zero-to-hero tutorial, though: each milestone should produce something real and runnable, not toy exercises.

## Working agreement (read this before writing any code)

- Explain key decisions **as they happen** — pause at real decision points (architecture choices, API shapes, tricky bugs) and discuss them, don't just deliver a finished result with a summary attached at the end. This was explicitly called out as a miss during Milestone 1: work got done correctly but heads-down, with one large report at the end instead of real back-and-forth.
- **Never build ahead and reflect after.** Talvin must be part of the building process from the start — discuss architecture and design before writing any code, explain every decision as it is made, write code together step by step. The learning is in the decision making, not just the final result.
- Keep steps small. Prefer clear, idiomatic code over clever abstractions.
- All variables must be explicitly typed — never rely on type inference. Use `final Type name = ...` not `final name = ...`. This applies everywhere: local variables, loop variables, factory body locals.
- Always use absolute imports (`package:chess_trainer/...`) — never relative imports (`../../`). Package name is `chess_trainer`.
- Call out relevant `dartchess`/`chessground` APIs and Flutter concepts as they come up, in context, not as a glossary dump.
- Keep "Talvin's developer skill inventory" updated as work continues — this is part of the point of the project, not bookkeeping overhead. It tracks Talvin's actual growth as a developer, not what's been discussed in a session.

## End goal (full scope — do not build ahead of the current milestone)

Import Talvin's own games from Chess.com, aggregate them into a FEN-keyed position tree to find the specific opening positions where he keeps losing to higher-rated players, help him build a repertoire for those spots (using the Lichess Opening Explorer API for candidate moves), then drill them by playing out the line — first against the app, later against Stockfish — with spaced-repetition scheduling.

## Roadmap

1. **Board + game replay** — ✅ done
2. **Chess.com import** — ✅ done
3. **Aggregate games into a FEN-keyed position registry, surface worst positions** — ✅ done (flat FEN-keyed map so transpositions merge — see skill inventory), see "Current status"
4. Build repertoire (Lichess Opening Explorer) + play-out training loop — 🚧 in progress (explorer client, position-detail screen, and repertoire model + pick-a-move done; play-out loop next)
5. Persistence + spaced repetition
6. Stockfish engine integration

Only build the current milestone. Don't scaffold later milestones early "for convenience" — the whole point is small, discussable steps.

## Current status

Milestone 3 complete. Import games from Chess.com → app accumulates games into a FEN-keyed registry → "Problem Positions" screen shows boards ranked by loss rate, split by White/Black. Milestone 4 in progress: the Lichess Opening Explorer is wired up, and you can now **commit a candidate move to a repertoire** — tap a move row on the position-detail screen to pick it (tap again to clear), keyed by normalized FEN so it lines up with the registry. Stored in-memory for now (`RepertoireController`); persistence is M5.

**Flow restructured** so the two purposes are no longer tangled on the month row: tapping a month → browse its games → pick one → **replay** (the single-game path); **Add** → month joins the analysis pool; a **pinned "Analyze N games" bar** (shown once the pool is non-empty) opens Problem Positions → position detail → pick a move — analysis is no longer buried behind the replay screen. In replay, the old "Import game" button became **"Pick another game"**, which returns to the month list (`backToMonths()` then push).

Next: the play-out training loop — from a problem position, play the line out on an interactive board and check the move against your repertoire pick (this is what "play out the game" means; distinct from passive replay of an imported game).

**Post-M3 polish (in progress):**
- Import UX reworked: month list has an explicit **Add** button (adds that month to the pool, per-row spinner → ✓) separate from tapping a row to **browse games** to replay; added months show a **remove** (trash) button; a running "N games in your analysis pool" banner. Registry now stores games **grouped by month** (`Map<archiveUrl, games>`) so months can be removed and "added months" = the map keys (single source of truth — killed the old duplicate `_addedArchives` tracking).
- **Logout** action on the replay screen (confirm dialog → `clearUser()` → state-driven router returns to username entry).
- **UI overhaul** done: "Slate + Antique Gold" dark theme in `lib/theme/app_theme.dart` (Fraunces serif titles, Inter body, JetBrains Mono for stats, gold accent, slate surfaces) via `google_fonts`, plus a custom slate/gold chessground board colour scheme (`AppTheme.board`/`boardSettings`). Applied across all three screens: analysis cards (serif rank, mono loss %, loss bar), import (pool banner, styled month rows), replay (mono move list with gold current-move highlight). Note: `google_fonts` fetches fonts over the network on first run — bundle as assets later for offline/instant load.

## What's built (Milestone 2)

- `lib/core/chess_com/chess_com_client.dart` — static HTTP client for the Chess.com public API. Fetches the list of monthly archive URLs for a user (`getArchives`) and downloads a full month of games as a PGN string (`getMonthlyGames`). Both return a `Result<T>` sealed type so call sites pattern-match success vs failure explicitly.
- `lib/utils/result.dart` — `sealed class Result<T>` with `Success<T>` and `Failure<T>` subtypes. Replaces try/catch at call sites with exhaustive pattern matching.
- `lib/features/import_game/` — three-file feature: `import_state.dart` (sealed state machine: `EnteringUsername → LoadingArchives → SelectingMonth → LoadingGames → SelectingGame → back to SelectingMonth or EnteringUsername`), `import_controller.dart` (Riverpod `Notifier` driving the state machine), `import_screen.dart` (UI reacting to each state).
- `GameReplay` extended with `whitePlayer`, `blackPlayer`, `result` — parsed from PGN headers (`parsedGame.headers['White']` etc.) so the game list can show who played and who won.
- Platform support added: macOS (`flutter create --platforms=macos .`), iOS, Android. macOS required `com.apple.security.network.client` in both `DebugProfile.entitlements` and `Release.entitlements`. Android required `<uses-permission android:name="android.permission.INTERNET"/>` in `AndroidManifest.xml`.
- `.vscode/launch.json` — VS Code run configurations for macOS, iOS, Web (WASM), and Web (JS).

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
- **`core/` vs `features/` split** — `core/` is UI-agnostic chess logic, `features/` builds on top of it. Dependency flows one way: features → core, never the reverse.
- **PlyRecord and GameReplay** — why a flat indexed list of plies beats replaying moves on every jump; why FEN strings are stored instead of `Position` objects (cheaper, sufficient for the UI).
- **`Position` immutability** — `.play()` returns a new object rather than mutating in place; the loop discards old `Position`s because `PlyRecord` already captured everything the UI needs.
- **Riverpod basics** — `ref.read` (once, no subscription), `ref.watch` (rebuild on change), `ref.listen` (side effect on change without rebuild). `NotifierProvider` exposes state via `ref.watch` and the notifier itself via `.notifier`.
- **`copyWith` pattern** — produces a new state object with one field changed; required for Riverpod to detect the change and trigger a rebuild.
- **Sealed class state machines** — `sealed class ImportState` with subclasses for each step of the import flow. The UI `switch`es exhaustively on the state so every case is handled and the compiler catches missing ones.
- **Switch expressions with destructuring** — `switch (state) { SelectingMonth(:final List<String> archives) => archives, _ => [] }` pulls a field out of a subtype and produces a value inline. The `:fieldName` syntax is shorthand for "match this subtype and bind its field".
- **`PopScope`** — intercepts back navigation in Flutter. `canPop: false` blocks the default pop; `onPopInvokedWithResult` runs instead, letting you transition state (e.g. game list → month list) rather than leaving the screen entirely.
- **`ref.listen` for side effects** — when Riverpod state changes need to update something outside the state tree (like a `TextEditingController`), `ref.listen` runs a callback without triggering a rebuild.
- **`??` null coalescing** — `expr ?? fallback` returns `fallback` when `expr` is null. Used when reading optional PGN headers that may not exist in every game file.
- **Platform entitlements and permissions** — macOS sandboxes Flutter apps; outbound HTTP requires `com.apple.security.network.client` in the entitlements plist. Android requires an explicit `INTERNET` permission in `AndroidManifest.xml`. iOS allows HTTPS by default.
- **REST API consumption** — `http.get(Uri.parse(...))` for a GET request; check `response.statusCode` before reading `response.body`; `json.decode` to parse the JSON into a Dart map.
- **State-driven routing without a router package** — `AppRouter` is a plain `ConsumerWidget` that watches a Riverpod state and returns a different widget tree based on it. No `Navigator.push`, no `go_router` — the framework reconciles the widget tree automatically. Used here so `ImportScreen` is the root until a game is loaded, then `ReplayScreen` takes over.
- **`shared_preferences` for lightweight persistence** — key/value storage backed by platform APIs (UserDefaults on iOS/macOS, SharedPreferences on Android). `SharedPreferences.getInstance()` is async but cached after the first call. Load on Notifier `build()` via fire-and-forget async, save/clear alongside state mutations.
- **Fire-and-forget async in Notifier** — calling an `async` method from a synchronous `build()` without `await` is valid when you want the state to update immediately and the async work to follow. The synchronous state change triggers a rebuild right away; the `await` continuation runs later on the event loop.
- **Position registry (FEN-keyed, flat)** — every unique position is one node storing its full FEN, its ply depth, and a W/L/D scoreboard. Built by walking each imported game move by move; at each position where it's Talvin's turn, the outcome is recorded on the node *before* the move (the position he had to find a move in). Positions live in a flat `Map<String, PositionNode>` keyed by a **normalized FEN** (first 4 fields — pieces, side-to-move, castling, en passant — dropping the two move counters). This is what merges **transpositions**: the same position reached via different move orders is one node with pooled stats.
- **Why flat, not a tree (key lesson)** — the earlier version was a *tree* keyed by the move played, which counted transpositions as separate nodes. Switching the key to FEN alone would NOT have fixed it: in a tree you reach a node by descending from a parent, and transpositions have different parents, so they'd still split. Merging transpositions *requires* abandoning the tree for a flat FEN→node map. Naming matters: the class is still called `PositionTree` but is really a registry.
- **`worstPositions` is now filter-and-sort** — with a flat map there's no recursion: filter `_positions.values` on depth ≥ `_minPly`, total ≥ `minGames`, and matching colour-to-move; sort by loss rate descending; take top N. (The old recursive `_collectNodes` depth-first walk was only needed because the data was a tree.)
- **Derived `Provider`** — a `Provider<T>((Ref ref) { ... })` is a computed value that depends on other providers via `ref.watch(...)`. It re-evaluates only when its dependencies change, and caches the result between rebuilds. Used here to build the position tree once per import batch and share the result with any screen that needs it.
- **`cross-provider` reads in Notifier** — inside a `Notifier` method (not `build()`), `ref.read(otherProvider.notifier)` accesses another notifier to call its methods. Used in `ImportController` to push games into `GamesController` and to clear the replay state when the user resets.
- **`FutureProvider` + `AsyncValue`** — a provider that wraps an `async` function and exposes an `AsyncValue<T>` (the three states of a fetch: loading / data / error), unwrapped in the UI with `.when(loading:, error:, data:)`. Failure is signalled by *throwing* inside the provider (becomes `AsyncValue.error`), so we translate our `Result` `Failure` into a thrown `Exception`.
- **`FutureProvider.family`** — turns a provider into a function of an argument: `explorerProvider(query)` returns a provider dedicated to that argument, each cached independently. The argument is the cache key, so it needs value-equality — hence a **record** (`({String fen, ExplorerSource source})`) as the key. In Riverpod 3 providers auto-dispose by default, so leaving the screen frees the query's cache. Type `FutureProviderFamily<T, Arg>` is exported from `flutter_riverpod/misc.dart`, not the main barrel.
- **Extracting a shared rule to one source of truth** — the FEN normalization was private to `PositionTree`. The moment a *second* feature (the repertoire) needed to key positions the identical way, that private copy became a liability: two definitions of a rule that MUST stay byte-identical, or a picked move silently fails to match its position. Fix: pull it out to one top-level `normalizeFen(String)` in `core/chess/fen.dart` that both call. The trigger for extracting isn't "it might be reused someday" — it's "a second caller now needs the exact same behaviour."
- **`Notifier<Map<...>>` — state can be a plain collection** — a Riverpod `Notifier` doesn't need a bespoke state class. When the state is genuinely just one map (position key → chosen move), `Notifier<Map<String, RepertoireEntry>>` is cleaner than wrapping it. The immutability rule is unchanged: every mutation builds a NEW map (`{...state, k: v}` or `Map.of(state)..remove(k)`) so Riverpod detects the change — never mutate the existing map in place.
- **A controller as the normalization boundary** — `pick`/`remove` take whatever FEN the caller has and normalize *inside* the controller, so no call site can forget and store an un-normalized key. Reads are different: the widget `ref.watch`es the map (to rebuild on change) and normalizes its lookup key with the same shared `normalizeFen`. Writes centralize the rule; reads reuse the shared function.
- **`ref.read` vs `ref.watch` in a callback** — a tap handler that fires a one-shot action (`pick`/`remove`) uses `ref.read(provider.notifier)`, not `watch` — the callback performs an action, it doesn't need to rebuild when the value changes. `watch` is for the build method that renders from the value.
- **`InkWell` toggle + stable-width trailing slot** — wrapping a row in `InkWell(onTap:)` makes it tappable with a ripple; a picked row is shown via a tinted `BoxDecoration` + gold border, and a trailing `SizedBox(width: 32)` holds either a check icon or nothing, so picked/unpicked rows keep the same width (no content jump). `Color.withValues(alpha:)` replaced the deprecated `withOpacity` in Flutter 3.27+.
- **Environment variables — runtime vs compile-time (key distinction)** — an env var is a `KEY=value` entry in a process's environment dictionary, inherited from the parent process (the shell) and living only as long as that process. Normal runtime lookup in Dart is `Platform.environment['X']`. But `String.fromEnvironment('X')` is **different**: it's a *compile-time* constant baked in by `--dart-define=X=...` at build time, not read from the OS at runtime. Dart does this because Flutter's web/AOT targets have no OS process environment to read from — so the value is resolved when a shell definitely exists (build time) and hardcoded into the binary. `--dart-define-from-file=file.json` is the same mechanism fed from a JSON file. Because the source only ever contains the *name*, secrets stay out of git; the value flows gitignored file → build flag → binary → `fromEnvironment`. Used for `LICHESS_TOKEN`. (Enterprise scales this up: secret managers/Vault the running service reads via its own machine identity, per-env dev-vs-prod secrets, CI secret stores, short-lived credentials — but the core rule is the same: keep the value out of code, feed it from the environment.)

## Open technical questions for the project (not skill-tracking — just unresolved research)

- [x] Chess.com's public API shape (archives endpoint, monthly-games format) — resolved in Milestone 2.
- [x] **Move-keyed vs FEN-keyed tree** — resolved: switched to a flat FEN-keyed registry so transpositions merge into one problem spot. Trade-off accepted: move-order-specific stats are no longer distinguished (fine for "which position hurts me"). Minor known edge: normalized key drops move counters, so a position reached at different ply counts (e.g. via a knight shuffle) keeps the depth of whichever game hit it first; negligible for openings.
- [x] **Lichess Opening Explorer API shape** — resolved. Base `https://explorer.lichess.ovh`, no auth (wants a `User-Agent`). `/lichess` (online games, filter by `speeds` + `ratings` bands) and `/masters` (titled OTB). Query `?fen=&moves=N` (+`variant`/`speeds`/`ratings` for lichess). Returns `{white,draws,black, opening:{eco,name}, moves:[{uci,san,white,draws,black,averageRating}], topGames, recentGames}`.
- [x] **Explorer 401 on this machine** — resolved. `explorer.lichess.ovh` returns nginx `401` here, and confirmed it's **IP-level** (Talvin's own browser 401s on the same URL, no VPN; `lichess.org` itself loads fine). Not a datacenter-only block as first assumed. Workaround: a free **Lichess personal token** (no scopes needed — read-only public API) sent as `Authorization: Bearer <token>`. Token is injected at build via `--dart-define-from-file=dart_define.json` (gitignored) and read with `String.fromEnvironment('LICHESS_TOKEN')`; empty default → no auth header, so unblocked users need no token. Never committed.
- [ ] Spaced-repetition algorithm choice (e.g. SM-2 vs FSRS) — needed for Milestone 5, not yet decided.

---
*This is a living document. Update "Current status" and "Talvin's developer skill inventory" as work continues — an agent picking this up cold should read this whole file before touching code.*
