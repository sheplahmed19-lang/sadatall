import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF00BFA5);
  static const Color primaryVariant = Color(0xFF007B6E);
  static const Color secondaryColor = Color(0xFF2A2A2A);
  static const Color secondaryVariant = Color(0xFF1A1A1A);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color backgroundColor = Color(0xFFE8F8F6);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF388E3C);
  static const Color warningColor = Color(0xFFF57C00);
  static const Color infoColor = Color(0xFF1976D2);

  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF4A4A4A);
  static const Color textDisabled = Color(0xFF9E9E9E);

  static const Color borderColor = Color(0xFFCCECE9);
  static const Color dividerColor = Color(0xFFDDF2F0);

  static const Color darkSurfaceColor = Color(0xFF1E1E1E);
  static const Color darkBackgroundColor = Color(0xFF121212);
  static const Color darkTextPrimary = Color(0xFFECECEC);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextDisabled = Color(0xFF6E6E6E);
  static const Color darkBorderColor = Color(0xFF3A3A3A);
  static const Color darkDividerColor = Color(0xFF2C2C2C);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        surface: surfaceColor,
        error: errorColor,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
      textTheme: _getTextTheme(),
      appBarTheme: _getAppBarTheme(),
      elevatedButtonTheme: _getElevatedButtonTheme(),
      outlinedButtonTheme: _getOutlinedButtonTheme(),
      textButtonTheme: _getTextButtonTheme(),
      inputDecorationTheme: _getInputDecorationTheme(),
      cardTheme: _getCardTheme(),
      dividerTheme: _getDividerTheme(),
      scaffoldBackgroundColor: surfaceColor,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        surface: darkSurfaceColor,
        error: errorColor,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
      textTheme: _getTextTheme(
        primary: darkTextPrimary,
        secondary: darkTextSecondary,
      ),
      appBarTheme: _getAppBarTheme(),
      elevatedButtonTheme: _getElevatedButtonTheme(),
      outlinedButtonTheme: _getOutlinedButtonTheme(),
      textButtonTheme: _getTextButtonTheme(),
      inputDecorationTheme: _getInputDecorationTheme(
        fill: darkSurfaceColor,
        border: darkBorderColor,
        labelColor: darkTextSecondary,
        hintColor: darkTextDisabled,
      ),
      // Without this, Card falls back to a light default and every order /
      // details card renders white behind light text in dark mode.
      cardTheme: _getCardTheme(
        color: darkSurfaceColor,
        shadowColor: Colors.black54,
      ),
      dividerTheme: _getDividerTheme(darkDividerColor),
      scaffoldBackgroundColor: darkBackgroundColor,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  static TextTheme _getTextTheme({
    Color primary = textPrimary,
    Color secondary = textSecondary,
  }) {
    return GoogleFonts.cairoTextTheme().copyWith(
      displayLarge: GoogleFonts.cairo(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: primary,
      ),
      displayMedium: GoogleFonts.cairo(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: primary,
      ),
      displaySmall: GoogleFonts.cairo(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: primary,
      ),
      headlineLarge: GoogleFonts.cairo(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      headlineMedium: GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      headlineSmall: GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleLarge: GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleSmall: GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: primary,
      ),
      bodyMedium: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: primary,
      ),
      bodySmall: GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: secondary,
      ),
      labelLarge: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      labelMedium: GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      labelSmall: GoogleFonts.cairo(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
    );
  }

  static AppBarTheme _getAppBarTheme() {
    return AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  static ElevatedButtonThemeData _getElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600),
        elevation: 2,
      ),
    );
  }

  static OutlinedButtonThemeData _getOutlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: primaryColor, width: 1.5),
        textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  static TextButtonThemeData _getTextButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  static InputDecorationTheme _getInputDecorationTheme({
    Color fill = surfaceColor,
    Color border = borderColor,
    Color labelColor = textSecondary,
    Color hintColor = textDisabled,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: GoogleFonts.cairo(color: labelColor, fontSize: 14),
      hintStyle: GoogleFonts.cairo(color: hintColor, fontSize: 14),
      errorStyle: GoogleFonts.cairo(color: errorColor, fontSize: 12),
    );
  }

  /// Card surface for one brightness.
  ///
  /// This used to hardcode the light `backgroundColor`, which is why it was
  /// commented out of the light theme and never wired into the dark one —
  /// leaving Card to fall back to a near-white default in dark mode, so every
  /// order card and details card stayed white while its text turned light.
  static CardThemeData _getCardTheme({
    Color color = backgroundColor,
    Color shadowColor = Colors.black12,
  }) {
    return CardThemeData(
      color: color,
      shadowColor: shadowColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(8),
    );
  }

  static DividerThemeData _getDividerTheme([Color color = dividerColor]) {
    return DividerThemeData(color: color, thickness: 1, space: 1);
  }
}
