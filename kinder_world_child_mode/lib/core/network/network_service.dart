import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

class NetworkService {
  final Dio _dio;
  final Connectivity _connectivity;
  final SecureStorage _secureStorage;
  final Logger _logger;

  NetworkService({
    Dio? dio,
    Connectivity? connectivity,
    required SecureStorage secureStorage,
    Logger? logger,
  })  : _dio = dio ?? Dio(),
        _connectivity = connectivity ?? Connectivity(),
        _secureStorage = secureStorage,
        _logger = logger ?? Logger() {
    _setupDio();
  }

  void _setupDio() {
    _dio.options = BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.apiTimeout,
      receiveTimeout: AppConstants.apiTimeout,
      sendTimeout: AppConstants.apiTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    // Request Interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final authorizationHeaderKey =
              _findHeaderKey(options.headers, 'Authorization');
          if (authorizationHeaderKey != null) {
            final explicitAuthorization = options.headers[authorizationHeaderKey];
            if (explicitAuthorization == null ||
                explicitAuthorization.toString().trim().isEmpty) {
              options.headers.remove(authorizationHeaderKey);
            }
          } else {
            final token = _secureStorage.hasCachedAuthToken
                ? _secureStorage.cachedAuthToken
                : await _secureStorage.getAuthToken();
            if (_shouldAttachAuthToken(token)) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          
          _logger.d('Request: ${options.method} ${options.path}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.d('Response: ${response.statusCode} ${response.requestOptions.path}');
          handler.next(response);
        },
        onError: (error, handler) {
          _logger.e('Error: ${error.message}');
          handler.next(error);
        },
      ),
    );

    // Retry Interceptor
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        logger: _logger,
      ),
    );
  }

  String? _findHeaderKey(Map<String, dynamic> headers, String target) {
    for (final key in headers.keys) {
      if (key.toLowerCase() == target.toLowerCase()) {
        return key;
      }
    }
    return null;
  }

  bool _shouldAttachAuthToken(String? token) {
    if (token == null || token.isEmpty) {
      return false;
    }
    // Child mode uses a local session marker, not a backend JWT.
    if (token.startsWith('child_session_')) {
      return false;
    }
    return true;
  }

  // Check internet connectivity
  Future<bool> isConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      _logger.e('Error checking connectivity: $e');
      return false;
    }
  }

  // GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  // POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  // PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  // DELETE request
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
      return response;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  void _handleDioError(DioException e) {
    if (e.response != null) {
      _logger.e('DioError: ${e.response?.statusCode} - ${e.response?.data}');
    } else {
      _logger.e('DioError: ${e.message}');
    }
  }

  // Cancel all requests
  void cancelAllRequests() {
    _dio.close();
  }
}

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final Logger logger;
  final int maxRetries;

  RetryInterceptor({
    required this.dio,
    required this.logger,
    this.maxRetries = 3,
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err)) {
      final retryCount = err.requestOptions.extra['retryCount'] ?? 0;
      
      if (retryCount < maxRetries) {
        logger.d('Retrying request: ${err.requestOptions.path} (Attempt: ${retryCount + 1})');
        
        // Keep retries responsive so the app does not feel frozen on transient failures.
        await Future.delayed(
          Duration(milliseconds: 250 * (1 << retryCount)),
        );
        
        // Clone request with incremented retry count
        final options = Options(
          method: err.requestOptions.method,
          headers: err.requestOptions.headers,
          extra: {
            ...err.requestOptions.extra,
            'retryCount': retryCount + 1,
          },
        );
        
        try {
          final response = await dio.request(
            err.requestOptions.path,
            data: err.requestOptions.data,
            queryParameters: err.requestOptions.queryParameters,
            options: options,
          );
          
          handler.resolve(response);
          return;
        } catch (e) {
          logger.e('Retry failed: $e');
        }
      }
    }
    
    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
           err.type == DioExceptionType.receiveTimeout ||
           err.type == DioExceptionType.sendTimeout ||
           (err.response?.statusCode != null && 
            err.response!.statusCode! >= 500);
  }
}
