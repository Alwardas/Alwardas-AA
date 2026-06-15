import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../api_constants.dart';
import 'hive_service.dart';

class DioClient {
  late final Dio _dio;

  DioClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Attaches the user session metadata or dynamic cookies if present
          final session = HiveService.getSession();
          if (session != null && session['id'] != null) {
            options.headers['X-User-Id'] = session['id'];
            options.headers['X-User-Role'] = session['role'];
          }
          if (kDebugMode) {
            debugPrint('🌐 DIO Request: ${options.method} ${options.path}');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint('✅ DIO Response: ${response.statusCode} for ${response.requestOptions.path}');
          }
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          if (kDebugMode) {
            debugPrint('❌ DIO Error: ${e.message} for ${e.requestOptions.path}');
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool useCache = false,
    Duration cacheMaxAge = const Duration(minutes: 5),
  }) async {
    final cacheKey = 'dio_cache_${path}_${queryParameters?.toString() ?? ''}';

    if (useCache) {
      final cached = HiveService.getCachedData(cacheKey, maxAge: cacheMaxAge);
      if (cached != null) {
        if (kDebugMode) {
          debugPrint('💾 DIO Cache Hit: $path');
        }
        return Response<T>(
          data: cached as T,
          statusCode: 200,
          requestOptions: RequestOptions(path: path),
        );
      }
    }

    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

      if (useCache && response.statusCode == 200 && response.data != null) {
        await HiveService.cacheData(cacheKey, response.data);
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      // Invalidate cache on post writes to this general prefix path
      await HiveService.clearCache();
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      await HiveService.clearCache();
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
