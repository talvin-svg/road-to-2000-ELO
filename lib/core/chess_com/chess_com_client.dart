import 'dart:convert';

import 'package:chess_trainer/utils/result.dart';
import 'package:http/http.dart' as http;

class ChessDotComClient {
  static const String _baseUrl = 'https://api.chess.com/pub';

  Future<Result<List<String>>> getArchives(String username) async {
    http.Response response;
    try {
      response = await http.get(
        Uri.parse('$_baseUrl/player/$username/games/archives'),
      );
      if (response.statusCode != 200) {
        return Failure(
          message: 'Failed to fetch archives: ${response.statusCode}',
        );
      }
      final List<String> archives = List<String>.from(
        json.decode(response.body)['archives'],
      );
      return Success(value: archives);
    } catch (e) {
      return Failure(message: 'Failed to fetch archives: $e');
    }
  }

  // TODO: Implement getMonthlyGames(String username, int year, int month) -> Future<Result<String>>
  // Steps:
  //   1. Use the http package to GET: $_baseUrl/player/$username/games/$year/$month/pgn
  //      (note: /pgn at the end — this endpoint returns raw PGN text, not JSON)
  //   2. If the response status code is not 200, return Failure with a message
  //   3. If status is 200, return Success wrapping response.body directly (it's already a PGN string)

  Future<Result<String>> getMonthlyGames(
    String username,
    int year,
    int month,
  ) async {
    http.Response response;
    try {
      response = await http.get(
        Uri.parse('$_baseUrl/player/$username/games/$year/$month/pgn'),
      );
      if (response.statusCode != 200) {
        return Failure(
          message: 'Failed to fetch monthly games: ${response.statusCode}',
        );
      }
      return Success(value: response.body);
    } catch (e) {
      return Failure(message: 'Failed to fetch monthly games: $e');
    }
  }
}
