abstract final class AppConstants {
  static const String appName = 'Geeky';
  static const String appTagline = 'Notes Recall';
  static const String appVersion = '1.0.0';

  static const String privacyPolicyUrl = 'https://geeky.app/privacy';
  static const String termsOfServiceUrl = 'https://geeky.app/terms';

  /// Side action rail fade delay
  static const Duration railFadeDelay = Duration(seconds: 3);
  static const double railFadeOpacity = 0.4;

  /// Feed
  static const int maxFeedPreloadCount = 5;

  /// Search
  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const int maxRecentSearches = 10;

  /// Engagement
  static const Duration minReadTime = Duration(seconds: 3);
}

abstract final class FreeTierLimits {
  static const int maxSources = 3;
  static const int maxStoreModules = 3;
  static const int maxNotes = 50;
}

abstract final class PremiumFeatures {
  static const String shortsFeed = 'Shorts Feed';
  static const String knowledgeGraph = 'Knowledge Graph';
  static const String ragQuery = 'Ask Questions';
  static const String quiz = 'Quizzes & Review';
  static const String analytics = 'Analytics';
  static const String unlimitedSources = 'Unlimited Sources';
  static const String unlimitedStore = 'Unlimited Store Downloads';
}
