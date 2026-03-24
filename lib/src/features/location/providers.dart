import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/providers/shared_preferences_provider.dart';
import 'data/location_service.dart';
import 'domain/location_context.dart';

part 'providers.g.dart';

const _cacheTtlMs = 30 * 60 * 1000; // 30 minutes

// ── Location enabled (user setting) ─────────────────────────────────────────

/// Whether location-based personalization is enabled.
///
/// Defaults to true (opt-out). Follows the [ThemeModeNotifier] pattern —
/// SharedPreferences as the source of truth, state exposed via Riverpod.
@Riverpod(keepAlive: true)
class LocationEnabled extends _$LocationEnabled {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  bool build() => _prefs.getBool(StorageKeys.locationEnabled) ?? true;

  Future<void> set(bool enabled) async {
    state = enabled;
    await _prefs.setBool(StorageKeys.locationEnabled, enabled);
    if (!enabled) {
      await ref.read(locationContextProvider.notifier).clear();
    }
  }
}

// ── Location context (resolved + cached) ─────────────────────────────────────

/// Resolves the user's city/state/country with a 30-minute SharedPreferences
/// cache. Returns null when: feature is disabled, permission denied, or any
/// platform/network error occurs — scoring functions treat null as +0.0.
///
/// keepAlive so a single resolution is shared across navigation.
@Riverpod(keepAlive: true)
class LocationContextNotifier extends _$LocationContextNotifier {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Future<LocationContext?> build() async {
    final enabled = ref.watch(locationEnabledProvider);
    if (!enabled) return null;

    final cached = _readCache();
    if (cached != null) return cached;

    final ctx = await LocationService.getCurrentContext();
    if (ctx != null && !ctx.isEmpty) _writeCache(ctx);
    return ctx;
  }

  /// Forces a fresh location lookup regardless of cache age.
  Future<void> refresh() async {
    state = const AsyncLoading();
    final ctx = await LocationService.getCurrentContext();
    if (ctx != null && !ctx.isEmpty) _writeCache(ctx);
    state = AsyncData(ctx);
  }

  /// Clears the cache and emits null to all watchers.
  Future<void> clear() async {
    await _prefs.remove(StorageKeys.locationCacheJson);
    await _prefs.remove(StorageKeys.locationCacheTimestampMs);
    state = const AsyncData(null);
  }

  // ── Cache helpers ───────────────────────────────────────────────────────

  LocationContext? _readCache() {
    final ts = _prefs.getInt(StorageKeys.locationCacheTimestampMs);
    final raw = _prefs.getString(StorageKeys.locationCacheJson);
    if (ts == null || raw == null) return null;

    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > _cacheTtlMs) return null;

    try {
      return LocationContext.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  void _writeCache(LocationContext ctx) {
    _prefs.setString(StorageKeys.locationCacheJson, jsonEncode(ctx.toJson()));
    _prefs.setInt(
      StorageKeys.locationCacheTimestampMs,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
