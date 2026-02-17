/// Exception thrown for API-level errors (non-2xx responses).
class ApiException implements Exception {
  const ApiException({
    this.statusCode,
    this.message = 'An API error occurred',
    this.code,
  });

  final int? statusCode;
  final String message;
  final String? code;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isRateLimited => statusCode == 429;
  bool get isServerError => (statusCode ?? 0) >= 500;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// Thrown when the device has no network connectivity.
class NetworkException implements Exception {
  const NetworkException([this.message = 'No internet connection']);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}
