import 'package:chess_trainer/core/lichess/explorer_result.dart';
import 'package:chess_trainer/core/lichess/lichess_explorer_client.dart';
import 'package:chess_trainer/utils/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// FutureProviderFamily lives in misc.dart, not the main barrel — needed to
// annotate the provider's type explicitly.
import 'package:flutter_riverpod/misc.dart';

// The argument identifying one explorer query: a position (FEN) + which
// database. A record gives value-equality for free — exactly what
// FutureProvider.family needs to use the argument as a cache key.
typedef ExplorerQuery = ({String fen, ExplorerSource source});

// A family of async providers, one per ExplorerQuery. Watching it yields an
// AsyncValue<ExplorerResult> (loading / data / error). Each distinct query is
// fetched and cached independently. In Riverpod 3 providers auto-dispose by
// default, so a query's cache is freed once no widget watches it (i.e. you
// leave the detail screen) — no explicit .autoDispose needed.
final FutureProviderFamily<ExplorerResult, ExplorerQuery> explorerProvider =
    FutureProvider.family<ExplorerResult, ExplorerQuery>(
  (Ref ref, ExplorerQuery query) async {
    final Result<ExplorerResult> result =
        await LichessExplorerClient.explore(query.fen, source: query.source);
    // FutureProvider signals failure via a thrown error (surfaced as
    // AsyncValue.error); translate our Result sealed type into that convention.
    return switch (result) {
      Success<ExplorerResult>(:final ExplorerResult value) => value,
      Failure<ExplorerResult>(:final String message) =>
        throw Exception(message),
    };
  },
);
