sealed class Failure {
  const Failure(this.message, [this.stackTrace]);

  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => 'Failure: $message';
}

final class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'Server error occurred',
    super.stackTrace,
  ]);
}

final class CacheFailure extends Failure {
  const CacheFailure([
    super.message = 'Cache error occurred',
    super.stackTrace,
  ]);
}

final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'No internet connection',
    super.stackTrace,
  ]);
}

final class AuthFailure extends Failure {
  const AuthFailure([
    super.message = 'Authentication failed',
    super.stackTrace,
  ]);
}

final class ValidationFailure extends Failure {
  const ValidationFailure([
    super.message = 'Validation failed',
    super.stackTrace,
  ]);
}
