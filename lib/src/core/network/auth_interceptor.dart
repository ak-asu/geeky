import 'package:dio/dio.dart';

import '../../features/auth/data/auth_repository.dart';

/// Attaches Firebase ID token to every outgoing request.
/// On 401 response, attempts a single token refresh + retry.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._getAuthRepo);

  final AuthRepository Function() _getAuthRepo;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final repo = _getAuthRepo();
    final token = await repo.getIdToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      // Try force-refreshing the token once
      try {
        final repo = _getAuthRepo();
        final newToken = await repo.getIdToken(forceRefresh: true);
        if (newToken != null) {
          // Retry the original request with the new token
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $newToken';

          final dio = Dio();
          final response = await dio.fetch(options);
          return handler.resolve(response);
        }
      } catch (_) {
        // Token refresh failed — fall through to error
      }
    }
    handler.next(err);
  }
}
