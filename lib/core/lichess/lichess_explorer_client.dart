import 'dart:convert';

import 'package:chess_trainer/core/lichess/explorer_result.dart';
import 'package:chess_trainer/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Client for the Lichess Opening Explorer (https://explorer.lichess.ovh).
// Static + Result<T>, mirroring ChessDotComClient. Supports both the /lichess
// and /masters databases via [ExplorerSource].
class LichessExplorerClient {
  static const String _baseUrl = 'https://explorer.lichess.ovh';

  // Compile-time token, injected via --dart-define(-from-file); never in source.
  // Empty by default → no auth header, the correct behaviour for the public
  // explorer. Supplied locally only to work around this machine's IP being
  // blocked by explorer.lichess.ovh (see LEARNING.md open questions).
  static const String _token = String.fromEnvironment('LICHESS_TOKEN');

  // Not const: the collection-if condition (_token.isNotEmpty) isn't a const
  // expression, so this is a computed getter instead of a const literal.
  static Map<String, String> get _headers => <String, String>{
    'User-Agent': 'chess_trainer/0.1 (learning project)',
    if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

  // Defaults for the /lichess database — rating bands bracketing the player's
  // current level (~1200 rapid), so candidate-move scores reflect the opponents
  // actually faced now, not far-stronger players. Valid Lichess bands are
  // 0,1000,1200,1400,1600,1800,2000,2200,2500. Widen these upward as the player
  // climbs toward the 2000 goal. (Ignored by /masters, which has no filters.)
  static const String _defaultRatings = '1000,1200,1400,1600';
  static const String _defaultSpeeds = 'blitz,rapid,classical';

  static Future<Result<ExplorerResult>> explore(
    String fen, {
    ExplorerSource source = ExplorerSource.lichess,
    int moves = 12,
  }) async {
    try {
      final Uri uri = _buildUri(fen, source, moves);
      // TEMP diagnostic: confirms the --dart-define token reached this build.
      // Logs presence + length only, never the token itself.
      debugPrint(
        '[LichessExplorerClient] token present: ${_token.isNotEmpty} '
        '(len ${_token.length})',
      );
      debugPrint('[LichessExplorerClient] GET $uri');
      // No default timeout on http.get — without this a stalled request spins
      // the loading UI forever instead of surfacing as an error.
      final http.Response response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 12));
      debugPrint('[LichessExplorerClient] status ${response.statusCode}');
      if (response.statusCode != 200) {
        return Failure<ExplorerResult>(
          message: 'Explorer request failed: ${response.statusCode}',
        );
      }
      final Map<String, dynamic> body =
          json.decode(response.body) as Map<String, dynamic>;
      return Success<ExplorerResult>(value: _parse(body));
    } on Object catch (e) {
      debugPrint('[LichessExplorerClient] explore failed: $e');
      return Failure<ExplorerResult>(message: 'Explorer request failed: $e');
    }
  }

  static Uri _buildUri(String fen, ExplorerSource source, int moves) {
    final Map<String, String> params = <String, String>{
      'fen': fen,
      'moves': '$moves',
    };
    // Only the /lichess database honours these filters.
    if (source == ExplorerSource.lichess) {
      params['variant'] = 'standard';
      params['speeds'] = _defaultSpeeds;
      params['ratings'] = _defaultRatings;
    }
    final String path = switch (source) {
      ExplorerSource.lichess => '/lichess',
      ExplorerSource.masters => '/masters',
    };
    return Uri.parse('$_baseUrl$path').replace(queryParameters: params);
  }

  static ExplorerResult _parse(Map<String, dynamic> body) {
    final List<dynamic> rawMoves =
        (body['moves'] as List<dynamic>?) ?? <dynamic>[];
    final List<ExplorerMove> moves = <ExplorerMove>[
      for (final dynamic m in rawMoves)
        ExplorerMove(
          uci: m['uci'] as String,
          san: m['san'] as String,
          white: (m['white'] as num?)?.toInt() ?? 0,
          draws: (m['draws'] as num?)?.toInt() ?? 0,
          black: (m['black'] as num?)?.toInt() ?? 0,
        ),
    ];
    final Map<String, dynamic>? rawOpening =
        body['opening'] as Map<String, dynamic>?;
    return ExplorerResult(
      white: (body['white'] as num?)?.toInt() ?? 0,
      draws: (body['draws'] as num?)?.toInt() ?? 0,
      black: (body['black'] as num?)?.toInt() ?? 0,
      opening: rawOpening == null
          ? null
          : ExplorerOpening(
              eco: rawOpening['eco'] as String? ?? '',
              name: rawOpening['name'] as String? ?? '',
            ),
      moves: moves,
    );
  }
}
