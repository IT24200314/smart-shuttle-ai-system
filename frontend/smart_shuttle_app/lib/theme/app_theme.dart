// ============================================================
// Smart Shuttle — App Theme (Redesigned)
// Near-black base, semantic color tokens, refined typography
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Core Palette ───────────────────────────────────────────
  /// Page/scaffold background — near-black with blue tint
  static const Color background  = Color(0xFF0A0E1A);
  /// Card surface
  static const Color surface     = Color(0xFF141928);
  /// Elevated card / dropdown
  static const Color surfaceHigh = Color(0xFF1C2236);
  /// Subtle card border
  static const Color border      = Color(0xFF1E2538);
  /// Strong border / divider
  static const Color borderStrong = Color(0xFF2A3350);

  // ── Semantic Colors ────────────────────────────────────────
  /// Positive / growth / active session
  static const Color positive  = Color(0xFF22C55E);
  static const Color positiveDim = Color(0xFF166534);
  /// Warning / caution
  static const Color warning   = Color(0xFFF59E0B);
  static const Color warningDim = Color(0xFF78350F);
  /// Critical / danger
  static const Color danger    = Color(0xFFEF4444);
  static const Color dangerDim = Color(0xFF7F1D1D);
  /// System / info / neutral accent (indigo)
  static const Color accent    = Color(0xFF6366F1);
  static const Color accentDim = Color(0xFF312E81);

  // ── Legacy aliases (kept for backward compat in widgets) ──
  static const Color darkBlue      = background;
  static const Color deepBlue      = surface;
  static const Color midBlue       = surfaceHigh;
  static const Color emerald       = positive;
  static const Color emeraldDim    = positiveDim;
  static const Color amber         = warning;
  static const Color glassBorder   = border;
  static const Color glassFill     = surfaceHigh;

  // ── Text Colors ────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF475569);

  // ── Radius ─────────────────────────────────────────────────
  static const double cardRadiusVal  = 14.0;
  static const double inputRadiusVal = 10.0;
  static const double chipRadiusVal  = 8.0;

  static const BorderRadius cardRadius  = BorderRadius.all(Radius.circular(cardRadiusVal));
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(inputRadiusVal));
  static const BorderRadius chipRadius  = BorderRadius.all(Radius.circular(chipRadiusVal));

  /// Legacy alias used widely in existing code
  static const double radius = chipRadiusVal;
  static const BorderRadius borderRadius = chipRadius;

  // ── Text Theme ─────────────────────────────────────────────
  static TextTheme _buildTextTheme() {
    return GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge:   TextStyle(color: textPrimary,   fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8),
        displayMedium:  TextStyle(color: textPrimary,   fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        displaySmall:   TextStyle(color: textPrimary,   fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        headlineMedium: TextStyle(color: textPrimary,   fontSize: 18, fontWeight: FontWeight.w600),
        headlineSmall:  TextStyle(color: textPrimary,   fontSize: 16, fontWeight: FontWeight.w600),
        titleLarge:     TextStyle(color: textPrimary,   fontSize: 14, fontWeight: FontWeight.w600),
        titleMedium:    TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
        bodyLarge:      TextStyle(color: textSecondary, fontSize: 14, height: 1.5),
        bodyMedium:     TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
        bodySmall:      TextStyle(color: textMuted,     fontSize: 11),
        labelLarge:     TextStyle(color: textPrimary,   fontSize: 14, fontWeight: FontWeight.w600),
        labelSmall:     TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.6),
      ),
    );
  }

  // ── ThemeData ──────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary:   accent,
        secondary: positive,
        surface:   surface,
        error:     danger,
      ),
      textTheme: _buildTextTheme(),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: cardRadius),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 0,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        shape: const RoundedRectangleBorder(borderRadius: chipRadius),
        labelStyle: GoogleFonts.inter(fontSize: 12, color: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: danger),
        ),
        errorStyle: GoogleFonts.inter(color: danger, fontSize: 11),
      ),
    );
  }
}
