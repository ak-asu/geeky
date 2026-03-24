abstract final class StorageKeys {
  // Auth
  static const String isLoggedIn = 'is_logged_in';
  static const String currentUserId = 'current_user_id';
  static const String currentUserJson = 'current_user_json';

  // Intro / Feature Showcase (pre-auth, one-time)
  static const String showcaseCompleted = 'showcase_completed';

  // User Preferences / Onboarding (post-auth, new-user setup)
  static const String onboardingCompleted = 'onboarding_completed';

  // Settings
  static const String themeMode = 'theme_mode';
  static const String fontSize = 'font_size';
  static const String ttsEnabled = 'tts_enabled';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String locationEnabled = 'location_enabled';

  // Location cache (SharedPreferences, 30-min TTL)
  static const String locationCacheJson = 'location_cache_json';
  static const String locationCacheTimestampMs = 'location_cache_timestamp_ms';

  // Subscription
  static const String subscriptionTier = 'subscription_tier';

  // Search
  static const String recentSearches = 'recent_searches';

  // Location
  static const String locationEnabled = 'location_enabled';
  static const String homeRegion = 'home_region';
}
