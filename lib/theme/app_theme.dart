import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Central theme: "Slate + Antique Gold" — the light, old-paper reinterpretation
// from the Road to 2000 design. Warm cream surfaces, slate ink text, a
// restrained antique-gold accent, Figtree for all UI text, and JetBrains Mono
// for numbers/FENs (the "techy" tell). Everything else inherits from here, so
// screens stay free of hard-coded colours and fonts.
//
// Colours are lifted straight from the design's CSS custom properties so the
// app and the mock stay in lockstep.
abstract final class AppTheme {
  // ── Palette ────────────────────────────────────────────────────────────
  static const Color _background = Color(0xFFF3EFE6); // --bg, warm cream
  static const Color _surface = Color(0xFFFBF9F3); // --card, near-white paper
  static const Color _surfaceHigh = Color(0xFFEFEADD); // --card2, sunk panels
  static const Color _line = Color(0xFFDDD5C5); // --line, hairline borders
  static const Color _ink = Color(0xFF2B2E34); // --ink, primary text
  static const Color _muted = Color(0xFF6C717A); // --muted, secondary text
  static const Color _faint = Color(0xFFA29A8A); // --faint, labels/placeholders
  static const Color _gold = Color(0xFF9E7C38); // --gold, antique accent
  static const Color _onGold = Color(0xFF1C1608); // dark brown text on gold
  static const Color _red = Color(0xFFB64A42); // --red, loss rates / blunders
  static const Color _green = Color(0xFF4F8560); // --green, best moves / added

  // Accents with no natural ColorScheme slot — exposed for widgets to opt in.
  static const Color faint = _faint;
  static const Color line = _line;
  static const Color success = _green;
  static const Color danger = _red;
  // --surface:#ece7db from the design; the sidebar's background (slightly darker
  // than --card so the sidebar reads as a distinct panel).
  static const Color sidebarBg = Color(0xFFECE7DB);
  // Sunk-panel fill (progress-bar tracks, inactive segment backgrounds).
  static const Color trackFill = _surfaceHigh;

  static const ColorScheme _scheme = ColorScheme(
    brightness: Brightness.light,
    primary: _gold,
    onPrimary: _onGold, // dark brown text sits on the gold
    secondary: _gold,
    onSecondary: _onGold,
    surface: _surface,
    onSurface: _ink,
    surfaceContainerHighest: _surfaceHigh,
    onSurfaceVariant: _muted,
    outline: _line,
    error: _red,
    onError: _surface,
  );

  // ── Chess board ──────────────────────────────────────────────────────
  // Warm gold light squares with cool slate dark squares — the design's
  // "Board" palette defaults — plus gold move highlights to match the chrome.
  static const Color _boardLight = Color(0xFFC9B98F);
  static const Color _boardDark = Color(0xFF6B7482);

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
    lastMove: HighlightDetails(solidColor: Color(0x809E7C38)),
    selected: HighlightDetails(solidColor: Color(0x609E7C38)),
    validMoves: Color(0x409E7C38),
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

  static ThemeData get light {
    // Figtree across the whole UI — including headings, which the design uses
    // in place of a serif. Weights are set per-widget where it matters.
    final TextTheme base = GoogleFonts.figtreeTextTheme(
      ThemeData(brightness: Brightness.light).textTheme,
    ).apply(bodyColor: _ink, displayColor: _ink);
    final TextTheme textTheme = base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w600),
      displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w600),
      displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w600),
      headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w600),
      headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
      headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: _scheme,
      scaffoldBackgroundColor: _background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _background,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.figtree(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _line),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      listTileTheme: const ListTileThemeData(iconColor: _muted),
      dividerTheme: const DividerThemeData(color: _line, thickness: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: _gold),
      tabBarTheme: const TabBarThemeData(
        labelColor: _gold,
        unselectedLabelColor: _muted,
        indicatorColor: _gold,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: _onGold,
          textStyle: GoogleFonts.figtree(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _gold,
          textStyle: GoogleFonts.figtree(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        hintStyle: const TextStyle(color: _faint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _gold),
        ),
      ),
    );
  }
}
