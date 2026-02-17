import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'api_client.dart';

part 'api_service.g.dart';

/// Typed wrapper around Dio for clean API calls.
/// Handles response envelope parsing (`{ "data": ... }`).
class ApiService {
  ApiService(this._dio);

  final Dio _dio;

  /// GET a single resource.
  Future<T> get<T>(
    String path,
    T Function(dynamic json) fromJson, {
    Map<String, dynamic>? queryParams,
  }) async {
    final response = await _dio.get(path, queryParameters: queryParams);
    return fromJson(_unwrap(response.data));
  }

  /// GET a list of resources.
  Future<List<T>> getList<T>(
    String path,
    T Function(dynamic json) fromJson, {
    Map<String, dynamic>? queryParams,
  }) async {
    final response = await _dio.get(path, queryParameters: queryParams);
    final data = _unwrap(response.data);
    if (data is List) {
      return data.map((item) => fromJson(item)).toList();
    }
    return [];
  }

  /// POST (create) a resource.
  Future<T> post<T>(
    String path,
    dynamic body,
    T Function(dynamic json) fromJson,
  ) async {
    final response = await _dio.post(path, data: body);
    return fromJson(_unwrap(response.data));
  }

  /// POST without parsing a typed response.
  Future<void> postVoid(String path, dynamic body) async {
    await _dio.post(path, data: body);
  }

  /// PUT (update) a resource.
  Future<T> put<T>(
    String path,
    dynamic body,
    T Function(dynamic json) fromJson,
  ) async {
    final response = await _dio.put(path, data: body);
    return fromJson(_unwrap(response.data));
  }

  /// PATCH a resource.
  Future<T> patch<T>(
    String path,
    dynamic body,
    T Function(dynamic json) fromJson,
  ) async {
    final response = await _dio.patch(path, data: body);
    return fromJson(_unwrap(response.data));
  }

  /// DELETE a resource.
  Future<void> delete(String path) async {
    await _dio.delete(path);
  }

  /// Unwraps the backend response envelope.
  /// Backend returns `{ "data": ... }` for single items and
  /// `{ "data": [...], "meta": {...} }` for lists.
  dynamic _unwrap(dynamic responseData) {
    if (responseData is Map<String, dynamic> &&
        responseData.containsKey('data')) {
      return responseData['data'];
    }
    return responseData;
  }
}

@Riverpod(keepAlive: true)
ApiService apiService(Ref ref) {
  return ApiService(ref.read(apiClientProvider));
}
