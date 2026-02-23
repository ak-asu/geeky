import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/network/api_service.dart';

class OnboardingRepository {
  OnboardingRepository(this._prefs, this._api);

  final SharedPreferences _prefs;
  final ApiService _api;

  bool get isCompleted =>
      _prefs.getBool(StorageKeys.onboardingCompleted) ?? false;

  List<String> get selectedInterests {
    final json = _prefs.getString(StorageKeys.selectedInterests);
    if (json == null) return [];
    return (jsonDecode(json) as List<dynamic>).cast<String>();
  }

  Future<void> completeOnboarding() async {
    await _prefs.setBool(StorageKeys.onboardingCompleted, true);
    // Best-effort sync to backend — does not block onboarding completion
    _api.patch('${ApiConstants.users}/me', {
      'onboarding_completed': true,
    }, (j) => j).ignore();
  }

  Future<void> saveInterests(List<String> interests) async {
    await _prefs.setString(
      StorageKeys.selectedInterests,
      jsonEncode(interests),
    );
    // Best-effort sync to backend
    _api.patch('${ApiConstants.users}/me', {
      'interests': interests,
    }, (j) => j).ignore();
  }

  Future<void> reset() async {
    await _prefs.setBool(StorageKeys.onboardingCompleted, false);
    await _prefs.remove(StorageKeys.selectedInterests);
  }
}
