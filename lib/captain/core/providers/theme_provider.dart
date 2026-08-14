import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(StorageService()),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final StorageService _storageService;

  ThemeModeNotifier(this._storageService) : super(ThemeMode.light) {
    _loadThemeMode();
  }

  /// Large parts of the captain UI reference [AppColors] statically instead of
  /// going through Theme.of(context), so the palette has to be told which mode
  /// is active or its text stays dark on the dark background.
  void _syncPalette(ThemeMode mode) {
    AppColors.isDarkMode = mode == ThemeMode.dark;
  }

  Future<void> _loadThemeMode() async {
    final saved = await _storageService.getThemeMode();
    if (saved == 'dark') {
      state = ThemeMode.dark;
    }
    _syncPalette(state);
  }

  Future<void> setDarkMode(bool isDark) async {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;
    _syncPalette(mode);
    state = mode;
    await _storageService.saveThemeMode(isDark ? 'dark' : 'light');
  }
}
