import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/storage_keys.dart';

class OnboardingRepository {
  OnboardingRepository(this._prefs);

  final SharedPreferences _prefs;

  bool get isCompleted =>
      _prefs.getBool(StorageKeys.onboardingCompleted) ?? false;

  List<String> get selectedInterests {
    final json = _prefs.getString(StorageKeys.selectedInterests);
    if (json == null) return [];
    return (jsonDecode(json) as List<dynamic>).cast<String>();
  }

  Future<void> completeOnboarding() async {
    await _prefs.setBool(StorageKeys.onboardingCompleted, true);
  }

  Future<void> saveInterests(List<String> interests) async {
    await _prefs.setString(
      StorageKeys.selectedInterests,
      jsonEncode(interests),
    );
  }

  Future<void> reset() async {
    await _prefs.setBool(StorageKeys.onboardingCompleted, false);
    await _prefs.remove(StorageKeys.selectedInterests);
  }
}
