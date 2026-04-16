import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static ThemeMode _themeMode = ThemeMode.dark;

  static void applyThemeMode(ThemeMode mode) {
    _themeMode = mode;
  }

  static const _AppPalette _darkPalette = _AppPalette(
    background: Color(0xFF07121E),
    surface: Color(0xFF0F1C2C),
    surfaceHigh: Color(0xFF16263A),
    border: Color(0xFF23364B),
    borderStrong: Color(0xFF32506D),
    positive: Color(0xFF22C55E),
    positiveDim: Color(0xFF103C28),
    warning: Color(0xFFF59E0B),
    warningDim: Color(0xFF553A0A),
    danger: Color(0xFFEF4444),
    dangerDim: Color(0xFF51212B),
    accent: Color(0xFF3B82F6),
    accentHover: Color(0xFF2563EB),
    accentDim: Color(0xFF132F53),
    info: Color(0xFF38BDF8),
    disabled: Color(0xFF5B6E84),
    textPrimary: Color(0xFFF6F9FD),
    textSecondary: Color(0xFFB8C6D8),
    textMuted: Color(0xFF74869C),
    gradientAccent: Color(0xFF173A63),
    dialogSurface: Color(0xFF142236),
    secondaryAccent: Color(0xFF14B8A6),
    shadowSoft: Color(0xB3000000),
    shadowStrong: Color(0xE6000000),
  );

  static const _AppPalette _lightPalette = _AppPalette(
    background: Color(0xFFEDF3F9),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF2F6FB),
    border: Color(0xFFC9D5E3),
    borderStrong: Color(0xFF9FB1C6),
    positive: Color(0xFF15803D),
    positiveDim: Color(0xFFE7F7EE),
    warning: Color(0xFFD97706),
    warningDim: Color(0xFFFFF4E0),
    danger: Color(0xFFDC2626),
    dangerDim: Color(0xFFFDECEC),
    accent: Color(0xFF2563EB),
    accentHover: Color(0xFF1D4ED8),
    accentDim: Color(0xFFDDE9FF),
    info: Color(0xFF0284C7),
    disabled: Color(0xFF8194AB),
    textPrimary: Color(0xFF0E1B2D),
    textSecondary: Color(0xFF41556A),
    textMuted: Color(0xFF667A91),
    gradientAccent: Color(0xFFD5E5FB),
    dialogSurface: Color(0xFFFFFFFF),
    secondaryAccent: Color(0xFF0B8E80),
    shadowSoft: Color(0x160A1220),
    shadowStrong: Color(0x260A1220),
  );

  static _AppPalette get _palette =>
      _themeMode == ThemeMode.light ? _lightPalette : _darkPalette;

  static bool get isDarkMode => _themeMode != ThemeMode.light;

  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get surfaceHigh => _palette.surfaceHigh;
  static Color get border => _palette.border;
  static Color get borderStrong => _palette.borderStrong;
  static Color get positive => _palette.positive;
  static Color get positiveDim => _palette.positiveDim;
  static Color get warning => _palette.warning;
  static Color get warningDim => _palette.warningDim;
  static Color get danger => _palette.danger;
  static Color get dangerDim => _palette.dangerDim;
  static Color get accent => _palette.accent;
  static Color get accentHover => _palette.accentHover;
  static Color get accentDim => _palette.accentDim;
  static Color get info => _palette.info;
  static Color get disabled => _palette.disabled;
  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.textSecondary;
  static Color get textMuted => _palette.textMuted;
  static Color get gradientAccent => _palette.gradientAccent;
  static Color get dialogSurface => _palette.dialogSurface;
  static Color get secondaryAccent => _palette.secondaryAccent;
  static Color get shadowSoft => _palette.shadowSoft;
  static Color get shadowStrong => _palette.shadowStrong;

  static Color get darkBlue => background;
  static Color get deepBlue => surface;
  static Color get midBlue => surfaceHigh;
  static Color get emerald => positive;
  static Color get emeraldDim => positiveDim;
  static Color get amber => warning;
  static Color get glassBorder => border;
  static Color get glassFill => surfaceHigh;

  static Color get onAccent => const Color(0xFFFFFFFF);
  static Color get onPositive => const Color(0xFFFFFFFF);
  static Color get onDanger => const Color(0xFFFFFFFF);

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  static const double cardRadiusVal = 18.0;
  static const double inputRadiusVal = 14.0;
  static const double chipRadiusVal = 12.0;

  static const BorderRadius cardRadius =
      BorderRadius.all(Radius.circular(cardRadiusVal));
  static const BorderRadius inputRadius =
      BorderRadius.all(Radius.circular(inputRadiusVal));
  static const BorderRadius chipRadius =
      BorderRadius.all(Radius.circular(chipRadiusVal));

  static const double radius = chipRadiusVal;
  static const BorderRadius borderRadius = chipRadius;

  static TextTheme _buildTextTheme(_AppPalette palette) {
    return GoogleFonts.interTextTheme(
      TextTheme(
        displayLarge: TextStyle(
          color: palette.textPrimary,
          fontSize: 36,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        displayMedium: TextStyle(
          color: palette.textPrimary,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        displaySmall: TextStyle(
          color: palette.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: palette.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: TextStyle(
          color: palette.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: palette.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: palette.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: palette.textSecondary,
          fontSize: 15,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          color: palette.textSecondary,
          fontSize: 13,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: palette.textMuted,
          fontSize: 12,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          color: palette.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        labelSmall: TextStyle(
          color: palette.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  static ThemeData _buildTheme({
    required _AppPalette palette,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.accent,
      onPrimary: const Color(0xFFFFFFFF),
      secondary: palette.secondaryAccent,
      onSecondary: const Color(0xFFFFFFFF),
      error: palette.danger,
      onError: const Color(0xFFFFFFFF),
      surface: palette.surface,
      onSurface: palette.textPrimary,
      tertiary: palette.warning,
      onTertiary: const Color(0xFFFFFFFF),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.surface,
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(palette),
      iconTheme: IconThemeData(color: palette.textSecondary),
      cardTheme: CardThemeData(
        color: palette.surface,
        margin: EdgeInsets.zero,
        shadowColor: palette.shadowSoft,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: cardRadius),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: const Color(0xFFFFFFFF),
          disabledBackgroundColor: palette.disabled.withOpacity(0.35),
          disabledForegroundColor: const Color(0xFFFFFFFF),
          shadowColor: palette.shadowStrong.withOpacity(isDark ? 0.32 : 0.16),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: cardRadius),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.borderStrong),
          shape: const RoundedRectangleBorder(borderRadius: cardRadius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          backgroundColor: isDark ? palette.surface : palette.surfaceHigh,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          shape: const RoundedRectangleBorder(borderRadius: chipRadius),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? palette.surface.withOpacity(0.92) : palette.surface,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: const Color(0x00000000),
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          color: palette.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.dialogSurface,
        shape: const RoundedRectangleBorder(borderRadius: cardRadius),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceHigh,
        selectedColor: palette.accentDim,
        side: BorderSide(color: palette.border),
        shape: const RoundedRectangleBorder(borderRadius: chipRadius),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: palette.accent,
        ),
        brightness: brightness,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? palette.surfaceHigh : palette.textPrimary,
        contentTextStyle:
            GoogleFonts.inter(color: const Color(0xFFFFFFFF), fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: cardRadius),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.accent),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? palette.surfaceHigh : palette.surface,
        hintStyle: GoogleFonts.inter(
          color: palette.textMuted,
          fontSize: 13,
        ),
        labelStyle: GoogleFonts.inter(
          color: palette.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          color: palette.accent,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        prefixIconColor: palette.textMuted,
        suffixIconColor: palette.textMuted,
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: palette.accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: palette.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: palette.danger, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: palette.border.withOpacity(0.7)),
        ),
        errorStyle: GoogleFonts.inter(color: palette.danger, fontSize: 11),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(palette.surfaceHigh),
        dividerThickness: 0.7,
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return palette.surfaceHigh.withOpacity(isDark ? 0.85 : 0.92);
          }
          return palette.surface;
        }),
        dataRowMinHeight: 50,
        headingRowHeight: 54,
      ),
    );
  }

  static ThemeData get darkTheme => _buildTheme(
        palette: _darkPalette,
        brightness: Brightness.dark,
      );

  static ThemeData get lightTheme => _buildTheme(
        palette: _lightPalette,
        brightness: Brightness.light,
      );
}

class _AppPalette {
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color borderStrong;
  final Color positive;
  final Color positiveDim;
  final Color warning;
  final Color warningDim;
  final Color danger;
  final Color dangerDim;
  final Color accent;
  final Color accentHover;
  final Color accentDim;
  final Color info;
  final Color disabled;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color gradientAccent;
  final Color dialogSurface;
  final Color secondaryAccent;
  final Color shadowSoft;
  final Color shadowStrong;

  const _AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.borderStrong,
    required this.positive,
    required this.positiveDim,
    required this.warning,
    required this.warningDim,
    required this.danger,
    required this.dangerDim,
    required this.accent,
    required this.accentHover,
    required this.accentDim,
    required this.info,
    required this.disabled,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.gradientAccent,
    required this.dialogSurface,
    required this.secondaryAccent,
    required this.shadowSoft,
    required this.shadowStrong,
  });
}
