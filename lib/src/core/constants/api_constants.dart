abstract final class ApiConstants {
  /// Base URL — configurable via --dart-define=API_BASE_URL=...
  /// Defaults to Android emulator localhost (10.0.2.2).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // --- API paths ---
  static const String health = '/health';
  static const String notes = '/api/v1/notes';
  static const String shorts = '/api/v1/shorts';
  static const String modules = '/api/v1/modules';
  static const String knowledgeGraph = '/api/v1/kg';
  static const String rag = '/api/v1/rag';
  static const String quiz = '/api/v1/quiz';
  static const String search = '/api/v1/search';
  static const String analytics = '/api/v1/analytics';
  static const String bookmarks = '/api/v1/bookmarks';
  static const String sources = '/api/v1/sources';
  static const String notifications = '/api/v1/notifications';
  static const String users = '/api/v1/users';
  static const String sync = '/api/v1/sync';
  static const String recommendations = '/api/v1/recommendations';
  static const String subscription = '/api/v1/subscription';
}
