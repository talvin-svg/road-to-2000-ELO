import 'dart:convert';

import 'package:chess_trainer/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ChessDotComClient {
  static const String _baseUrl = 'https://api.chess.com/pub';

  static Future<Result<List<String>>> getArchives(String username) async {
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
    } on Object catch (e) {
      debugPrint('[ChessDotComClient] Failed to fetch archives: $e');
      return Failure(message: 'Failed to fetch archives: $e');
    }
  }

  static String formatArchive(String archiveUrl) {
    const List<String> monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final List<String> segments = archiveUrl.split('/');
    final int year = int.parse(segments[segments.length - 2]);
    final int month = int.parse(segments[segments.length - 1]);
    return '${monthNames[month - 1]} $year';
  }

  static Future<Result<String>> getMonthlyGames(
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
    } on Object catch (e) {
      debugPrint('[ChessDotComClient] Failed to fetch monthly games: $e');
      return Failure(message: 'Failed to fetch monthly games: $e');
    }
  }
}
