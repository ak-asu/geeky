import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/network/api_service.dart';

/// Manages two distinct first-launch flows in SharedPreferences:
///
/// **Feature Showcase** (`showcaseCompleted`): The 3-slide intro carousel
/// shown pre-auth on first launch. Tracked purely locally — no backend sync
/// needed. Set when the user taps "Get Started" or "Skip".
///
/// **User Preferences / Onboarding** (`onboardingCompleted`): Interest
/// selection shown post-auth to new users. Synced to the backend so the
/// personalisation engine has the user's preferences.
///
/// Interest data itself is owned by [AuthRepository.updateUser], which
/// PATCHes the full user profile to the backend and updates the local auth
/// cache. This repository only tracks the two completion flags.
class OnboardingRepository {
  OnboardingRepository(this._prefs, this._api);

  final SharedPreferences _prefs;
  final ApiService _api;

  // ── Feature Showcase (pre-auth intro) ─────────────────────────────────────

  bool get isShowcaseCompleted =>
      _prefs.getBool(StorageKeys.showcaseCompleted) ?? false;

  /// Marks the feature showcase as seen. Called when the user leaves the
  /// showcase screen (taps "Get Started" or "Skip").
  Future<void> completeShowcase() async {
    await _prefs.setBool(StorageKeys.showcaseCompleted, true);
  }

  // ── User Preferences / Onboarding (post-auth) ─────────────────────────────

  bool get isCompleted =>
      _prefs.getBool(StorageKeys.onboardingCompleted) ?? false;

  /// Marks user-preference onboarding complete locally and best-effort syncs
  /// to the backend. Called post-auth, so a valid token is always available.
  Future<void> completeOnboarding() async {
    await _prefs.setBool(StorageKeys.onboardingCompleted, true);
    _api.patch('${ApiConstants.users}/me', {
      'onboarding_completed': true,
    }, (j) => j).ignore();
  }

  /// Resets both completion flags. Useful for development and testing.
  Future<void> reset() async {
    await _prefs.setBool(StorageKeys.showcaseCompleted, false);
    await _prefs.setBool(StorageKeys.onboardingCompleted, false);
  }
}
