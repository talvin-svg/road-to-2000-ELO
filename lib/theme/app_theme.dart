import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Central theme: "Slate + Antique Gold" — a dark, old-world chess-club look.
// Cool blue-slate surfaces, a restrained antique-gold accent, serif titles
// (Fraunces), a clean sans body (Inter), and monospace for numbers/FENs
// (JetBrains Mono) as the "techy" tell. Everything else inherits from here, so
// screens stay free of hard-coded colours and fonts.
abstract final class AppTheme {
  // ── Palette ────────────────────────────────────────────────────────────
  static const Color _background = Color(0xFF12151C); // blue-slate, near-black
  static const Color _surface = Color(0xFF1C212B);
  static const Color _surfaceHigh = Color(0xFF262C38);
  static const Color _text = Color(0xFFECECEC);
  static const Color _muted = Color(0xFF7C8493);
  static const Color _gold = Color(0xFFC9A24B); // antique gold accent
  static const Color _error = Color(0xFFD9646B); // warm red for loss rates

  static const ColorScheme _scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _gold,
    onPrimary: _background, // dark text sits on the gold
    secondary: _gold,
    onSecondary: _background,
    surface: _surface,
    onSurface: _text,
    surfaceContainerHighest: _surfaceHigh,
    onSurfaceVariant: _muted,
    outline: _muted,
    error: _error,
    onError: _background,
  );

  // ── Chess board ──────────────────────────────────────────────────────
  // Cool slate squares with gold move highlights, to match the app chrome
  // instead of chessground's default brown/green.
  static const Color _boardLight = Color(0xFFC6CBD4);
  static const Color _boardDark = Color(0xFF4A5160);

  static const ChessboardColorScheme board = ChessboardColorScheme(
    lightSquare: _boardLight,
    darkSquare: _boardDark,
    background: SolidColorChessboardBackground(
      lightSquare: _boardLight,
      darkSquare: _boardDark,
    ),
    whiteCoordBackground: SolidColorChessboardBackground(
      lightSquare: _boardLight,
      darkSquare: _boardDark,
      coordinates: true,
    ),
    blackCoordBackground: SolidColorChessboardBackground(
      lightSquare: _boardLight,
      darkSquare: _boardDark,
      coordinates: true,
      orientation: Side.black,
    ),
    lastMove: HighlightDetails(solidColor: Color(0x80C9A24B)),
    selected: HighlightDetails(solidColor: Color(0x60C9A24B)),
    validMoves: Color(0x40C9A24B),
    validPremoves: Color(0x40203085),
  );

  // Convenience: board settings carrying the custom colour scheme.
  static const ChessboardSettings boardSettings =
      ChessboardSettings(colorScheme: board);

  // Monospace style for stats/FENs — exposed so widgets can opt in.
  static TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  static ThemeData get dark {
    // Inter for everything, then serif (Fraunces) over the display/headline/
    // title slots for that classic chess-club feel.
    final TextTheme base = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );
    final TextTheme textTheme = base.copyWith(
      displayLarge: GoogleFonts.fraunces(textStyle: base.displayLarge),
      displayMedium: GoogleFonts.fraunces(textStyle: base.displayMedium),
      displaySmall: GoogleFonts.fraunces(textStyle: base.displaySmall),
      headlineLarge: GoogleFonts.fraunces(textStyle: base.headlineLarge),
      headlineMedium: GoogleFonts.fraunces(textStyle: base.headlineMedium),
      headlineSmall: GoogleFonts.fraunces(textStyle: base.headlineSmall),
      titleLarge: GoogleFonts.fraunces(textStyle: base.titleLarge),
    ).apply(bodyColor: _text, displayColor: _text);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _scheme,
      scaffoldBackgroundColor: _background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _background,
        foregroundColor: _text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: _text,
        ),
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _surfaceHigh),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      listTileTheme: const ListTileThemeData(iconColor: _muted),
      dividerTheme: const DividerThemeData(color: _surfaceHigh, thickness: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: _gold),
      tabBarTheme: const TabBarThemeData(
        labelColor: _gold,
        unselectedLabelColor: _muted,
        indicatorColor: _gold,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: _background,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _gold),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _gold),
        ),
      ),
    );
  }
}
