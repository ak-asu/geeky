import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/subscription/providers.dart';
import 'route_names.dart';

/// Checks if the current route requires premium and the user is free tier.
/// Returns redirect path if blocked, null if allowed.
String? checkPremiumAccess(Ref ref, String matchedLocation) {
  final isPremiumRoute =
      premiumRoutes.contains(matchedLocation) ||
      premiumPathPrefixes.any((p) => matchedLocation.startsWith(p));

  if (!isPremiumRoute) return null;

  // Read subscription state exactly once — isPremiumProvider is synchronous
  // (reads from in-memory Riverpod state) so there is no race condition.
  final isPremium = ref.read(isPremiumProvider);
  return isPremium ? null : '/${RouteNames.subscription}';
}

/// Exact route paths that require premium access.
const premiumRoutes = {
  '/${RouteNames.shortsFeed}',
  '/${RouteNames.knowledgeGraph}',
  '/${RouteNames.ragQuery}',
  '/${RouteNames.analytics}',
  '/${RouteNames.quiz}',
};

/// Path prefixes for premium deep-link routes (path-param routes cannot be
/// matched by exact string; use startsWith instead).
const premiumPathPrefixes = {'/shorts/'};
