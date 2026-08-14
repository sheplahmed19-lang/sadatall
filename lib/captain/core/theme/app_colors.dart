import 'package:flutter/material.dart';

class AppColors {
  // Primary colors - Teal theme (matches user app)
  static const Color primary = Color(0xFF00BFA5);
  static const Color primaryDark = Color(0xFF007B6E);
  static const Color primaryLight = Color(0xFFE0F7FA);

  // Secondary colors
  static const Color secondary = Color(0xFF2A2A2A);
  static const Color secondaryLight = Color(0xFF6D6D6D);
  static const Color secondaryDark = Color(0xFF1A1A1A);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Order status colors
  static const Color pending = Color(0xFFFF9800);
  static const Color accepted = Color(0xFF2196F3);
  static const Color delivered = Color(0xFF4CAF50);
  static const Color cancelled = Color(0xFFF44336);

  // Background colors
  static const Color background = Color(0xFFE8F8F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFFAFAFA);

  // Text colors
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // Text-on-surface colours are resolved per theme rather than being const:
  // they are referenced directly in ~90 places (often inside `const` widget
  // trees with no BuildContext to hand), so a fixed dark value left every one
  // of them near-black on the dark background. Resolving them here keeps all
  // those call sites working unchanged while still flipping with the theme.
  //
  // The flag is set by ThemeModeNotifier rather than read from the device
  // brightness, so it follows the app's own dark-mode toggle — the same
  // source of truth MaterialApp uses to pick light/dark ThemeData. Reading
  // the platform brightness instead would disagree with the toggle whenever
  // the two differ, leaving this text dark on a dark background.
  static bool isDarkMode = false;

  static Color get onSurface =>
      isDarkMode ? darkOnSurface : const Color(0xFF1A1A1A);
  static Color get onSurfaceVariant =>
      isDarkMode ? darkOnSurfaceVariant : const Color(0xFF757575);

  // Surfaces follow the same flag, so cards/among containers that reference
  // these directly do not stay white behind the now-light text.
  static Color get themedSurface => isDarkMode ? darkSurface : surface;
  static Color get themedBackground =>
      isDarkMode ? darkBackground : background;

  // Border colors
  static const Color outline = Color(0xFFCCECE9);
  static const Color outlineVariant = Color(0xFFDDF2F0);

  // Disabled colors
  static const Color disabled = Color(0xFFBDBDBD);
  static const Color onDisabled = Color(0xFF9E9E9E);

  // Dark theme colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF262626);
  static const Color darkOnSurface = Color(0xFFECECEC);
  static const Color darkOnSurfaceVariant = Color(0xFFB0B0B0);
  static const Color darkOutline = Color(0xFF3A3A3A);
}