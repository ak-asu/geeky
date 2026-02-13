import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/providers/shared_preferences_provider.dart';

part 'providers.g.dart';

enum SubscriptionTier { free, premium }

@Riverpod(keepAlive: true)
class SubscriptionNotifier extends _$SubscriptionNotifier {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  SubscriptionTier build() {
    final stored = _prefs.getString(StorageKeys.subscriptionTier);
    return stored == 'premium'
        ? SubscriptionTier.premium
        : SubscriptionTier.free;
  }

  /// Toggle for dev testing
  Future<void> togglePremium() async {
    final next = state == SubscriptionTier.premium
        ? SubscriptionTier.free
        : SubscriptionTier.premium;
    state = next;
    await _prefs.setString(StorageKeys.subscriptionTier, next.name);
  }

  Future<void> setTier(SubscriptionTier tier) async {
    state = tier;
    await _prefs.setString(StorageKeys.subscriptionTier, tier.name);
  }
}

@riverpod
bool isPremium(Ref ref) {
  return ref.watch(subscriptionProvider) == SubscriptionTier.premium;
}
