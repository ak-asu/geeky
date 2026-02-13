class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => 'AppException: $message';
}

class PremiumRequiredException extends AppException {
  const PremiumRequiredException(String feature)
    : super('$feature requires a premium subscription');

  String get feature => message.split(' requires')[0];
}

class DownloadLimitException extends AppException {
  const DownloadLimitException(int limit)
    : super('Free tier limited to $limit downloads');
}

class SourceLimitException extends AppException {
  const SourceLimitException(int limit)
    : super('Free tier limited to $limit sources');
}
