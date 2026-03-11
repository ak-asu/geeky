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

  // Subscription
  static const String subscriptionTier = 'subscription_tier';

  // Search
  static const String recentSearches = 'recent_searches';
}
