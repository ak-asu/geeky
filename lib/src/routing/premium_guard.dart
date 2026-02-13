import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/subscription/providers.dart';
import 'route_names.dart';

/// Checks if the current route requires premium and the user is free tier.
/// Returns redirect path if blocked, null if allowed.
String? checkPremiumAccess(Ref ref, String matchedLocation) {
  if (!premiumRoutes.contains(matchedLocation)) return null;

  final isPremium = ref.read(isPremiumProvider);
  if (!isPremium) return '/';

  return null;
}

/// Set of route paths that require premium access.
const premiumRoutes = {
  '/${RouteNames.knowledgeGraph}',
  '/${RouteNames.ragQuery}',
  '/${RouteNames.analytics}',
};
