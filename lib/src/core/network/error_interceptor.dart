import 'package:dio/dio.dart';

import 'api_exceptions.dart';

/// Maps Dio errors and non-2xx responses to typed exceptions.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        throw const NetworkException('Connection failed — check your internet');

      case DioExceptionType.badResponse:
        final response = err.response;
        if (response == null) {
          throw const ApiException(message: 'No response from server');
        }

        // Parse backend error envelope: { "error": { "code", "message", "detail" } }
        String message = 'Server error';
        String? code;
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final error = data['error'];
          if (error is Map<String, dynamic>) {
            message = (error['message'] as String?) ?? message;
            code = error['code'] as String?;
          }
        }

        throw ApiException(
          statusCode: response.statusCode,
          message: message,
          code: code,
        );

      case DioExceptionType.cancel:
        // Request was cancelled — don't throw, just pass through
        break;

      case DioExceptionType.badCertificate:
        throw const NetworkException('SSL certificate error');

      case DioExceptionType.unknown:
        if (err.error.toString().contains('SocketException')) {
          throw const NetworkException();
        }
        throw ApiException(message: err.message ?? 'Unknown error');
    }

    handler.next(err);
  }
}
