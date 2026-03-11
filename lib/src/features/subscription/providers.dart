import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/network/api_service.dart';
import '../../core/providers/shared_preferences_provider.dart';

part 'providers.g.dart';

enum SubscriptionTier { free, premium }

@Riverpod(keepAlive: true)
class SubscriptionNotifier extends _$SubscriptionNotifier {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);
  ApiService get _api => ref.read(apiServiceProvider);

  @override
  SubscriptionTier build() {
    // Return cached value immediately for a fast, optimistic start.
    // A background fetch will update state when the backend responds.
    final cached = _prefs.getString(StorageKeys.subscriptionTier);
    final optimistic = cached == 'premium'
        ? SubscriptionTier.premium
        : SubscriptionTier.free;
    Future.microtask(_fetchFromBackend);
    return optimistic;
  }

  /// Re-fetch subscription status from backend (call after a purchase flow).
  Future<void> refresh() => _fetchFromBackend();

  Future<void> _fetchFromBackend() async {
    try {
      final json = await _api.get(
        '${ApiConstants.subscription}/status',
        (j) => j as Map<String, dynamic>,
      );
      final tier = (json['tier'] as String?) == 'premium'
          ? SubscriptionTier.premium
          : SubscriptionTier.free;
      await _prefs.setString(StorageKeys.subscriptionTier, tier.name);
      state = tier;
    } catch (_) {
      // Remain on cached/optimistic tier — no change
    }
  }
}

@riverpod
bool isPremium(Ref ref) {
  return ref.watch(subscriptionProvider) == SubscriptionTier.premium;
}
