import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/network/api_service.dart';
import '../../core/providers/shared_preferences_provider.dart';
import '../../core/services/location_service.dart';
import 'data/settings_repository.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) {
  return SettingsRepository(ref.read(apiServiceProvider));
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

// --- Location Preference ---

/// State for location-based content prioritization.
///
/// [enabled]: whether geographic boost is active.
/// [homeRegion]: human-readable label, e.g. "Arizona, US".
///              Null means no region has been set yet.
typedef LocationPreference = ({bool enabled, String? homeRegion});

@Riverpod(keepAlive: true)
class LocationPreferenceNotifier extends _$LocationPreferenceNotifier {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);
  final LocationService _locationService = LocationService();

  @override
  LocationPreference build() {
    final enabled = _prefs.getBool(StorageKeys.locationEnabled) ?? false;
    final region = _prefs.getString(StorageKeys.homeRegion);
    return (enabled: enabled, homeRegion: region);
  }

  /// Enable or disable geographic content prioritization.
  Future<void> setEnabled(bool value) async {
    state = (enabled: value, homeRegion: state.homeRegion);
    await _prefs.setBool(StorageKeys.locationEnabled, value);
    await _syncToBackend();
  }

  /// Manually set the home region label (no permission required).
  ///
  /// Useful when the user wants to set a specific region without granting
  /// location permission (e.g. typing "Texas, US").
  Future<void> setRegion(String region) async {
    final trimmed = region.trim();
    state = (
      enabled: state.enabled,
      homeRegion: trimmed.isEmpty ? null : trimmed,
    );
    if (trimmed.isEmpty) {
      await _prefs.remove(StorageKeys.homeRegion);
    } else {
      await _prefs.setString(StorageKeys.homeRegion, trimmed);
    }
    await _syncToBackend();
  }

  /// Auto-detect coarse location and populate homeRegion.
  ///
  /// Returns a [LocationResult] so the caller can show appropriate UI
  /// (e.g. a snackbar for denial or an error).
  Future<LocationResult> detectRegion() async {
    final result = await _locationService.detectRegion();
    if (result is LocationSuccess) {
      await setRegion(result.region);
    }
    return result;
  }

  /// Clear the stored region label.
  Future<void> clearRegion() async {
    state = (enabled: state.enabled, homeRegion: null);
    await _prefs.remove(StorageKeys.homeRegion);
    await _syncToBackend();
  }

  /// Push location preferences to the backend (Firestore via API).
  ///
  /// Fire-and-forget — failures are silently logged; local state is the
  /// source of truth for UX responsiveness.
  Future<void> _syncToBackend() async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.patchVoid('/users/me', {
        'locationEnabled': state.enabled,
        'homeRegion': state.homeRegion,
      });
    } catch (_) {
      // Non-critical: local preference is already saved; sync retried next time.
    }
  }
}
