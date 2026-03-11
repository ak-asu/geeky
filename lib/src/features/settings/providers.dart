import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/network/api_service.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/shared_preferences_provider.dart';
import 'data/settings_repository.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) {
  return SettingsRepository(
    ref.read(apiServiceProvider),
    ref.read(appDatabaseProvider),
  );
}

// --- Theme Mode ---

@Riverpod(keepAlive: true)
class ThemeModeNotifier extends _$ThemeModeNotifier {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  ThemeMode build() {
    final stored = _prefs.getString(StorageKeys.themeMode);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(StorageKeys.themeMode, mode.name);
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}

// --- Font Size ---

enum FontSizeOption { small, medium, large }

@Riverpod(keepAlive: true)
class FontSizeNotifier extends _$FontSizeNotifier {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  FontSizeOption build() {
    final stored = _prefs.getString(StorageKeys.fontSize);
    return switch (stored) {
      'small' => FontSizeOption.small,
      'large' => FontSizeOption.large,
      _ => FontSizeOption.medium,
    };
  }

  Future<void> setFontSize(FontSizeOption size) async {
    state = size;
    await _prefs.setString(StorageKeys.fontSize, size.name);
  }

  double get scaleFactor => switch (state) {
    FontSizeOption.small => 0.9,
    FontSizeOption.medium => 1.0,
    FontSizeOption.large => 1.15,
  };
}
