import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/core/utils/session_token_utils.dart';
import 'package:logger/logger.dart';

class NetworkService {
  final Dio _dio;
  final Connectivity _connectivity;
  final SecureStorage _secureStorage;
  final Logger _logger;
  final void Function(bool isMaintenanceMode)? _onMaintenanceModeChanged;
  final Random _random = Random();
  final Set<CancelToken> _managedCancelTokens = <CancelToken>{};

  /// Whether TLS certificate pinning is active for this instance.
  ///
  /// Defaults to [AppConstants.enableCertificatePinning] (which is `true`
  /// only when `APP_ENV=production`).  Pass `enablePinning: false` in tests
  /// or development to bypass the pin check without touching app-wide config.
  final bool _enablePinning;

  NetworkService({
    Dio? dio,
    Connectivity? connectivity,
    required SecureStorage secureStorage,
    Logger? logger,
    void Function(bool isMaintenanceMode)? onMaintenanceModeChanged,
    bool? enablePinning,
  })  : _dio = dio ?? Dio(),
        _connectivity = connectivity ?? Connectivity(),
        _secureStorage = secureStorage,
        _logger = logger ?? Logger(),
        _onMaintenanceModeChanged = onMaintenanceModeChanged,
        _enablePinning =
            enablePinning ?? AppConstants.enableCertificatePinning {
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

    _logInfo(
      'http.client.config',
      fields: {
        'base_url': _dio.options.baseUrl,
      },
    );

    // Request Interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Prepend the API version prefix to every app-level path.
          // Paths already carrying the prefix (e.g. on retry) or that are
          // absolute URLs (fallback retry with full URI) are left untouched.
          // Infrastructure paths (/health, /webhooks) don't go through this
          // client, so no exclusion list is needed here.
          const apiPrefix = '/api/${AppConstants.apiVersion}';
          final rawPath = options.path;
          if (!rawPath.startsWith(apiPrefix) &&
              !rawPath.startsWith('http://') &&
              !rawPath.startsWith('https://')) {
            options.path = '$apiPrefix$rawPath';
          }

          final requestId = _resolveRequestId(options);
          options.headers['X-Request-ID'] = requestId;
          options.extra['requestId'] = requestId;
          options.extra['startedAtMs'] = DateTime.now().millisecondsSinceEpoch;

          final authorizationHeaderKey =
              _findHeaderKey(options.headers, 'Authorization');
          if (authorizationHeaderKey != null) {
            final explicitAuthorization =
                options.headers[authorizationHeaderKey];
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

          _logDebug(
            'http.request.start',
            fields: {
              'request_id': requestId,
              'base_url': options.baseUrl,
              'url': options.uri.toString(),
              'method': options.method,
              'path': options.path,
              'request_body': _serializeForLog(options.data),
              'retry': options.extra['retryCount'] ?? 0,
            },
          );
          handler.next(options);
        },
        onResponse: (response, handler) {
          _onMaintenanceModeChanged?.call(false);
          final requestId =
              response.requestOptions.extra['requestId']?.toString() ??
                  response.headers.value('X-Request-ID') ??
                  'unknown';
          final duration = _requestDurationMs(response.requestOptions);
          _logForStatus(
            response.statusCode ?? 0,
            'http.request.end',
            fields: {
              'request_id': requestId,
              'method': response.requestOptions.method,
              'path': response.requestOptions.path,
              'status_code': response.statusCode,
              'duration_ms': duration,
              'retry': response.requestOptions.extra['retryCount'] ?? 0,
            },
          );
          handler.next(response);
        },
        onError: (error, handler) {
          final detail = error.response?.data;
          if (error.response?.statusCode == 503 &&
              detail is Map<String, dynamic> &&
              detail['detail'] is Map<String, dynamic> &&
              (detail['detail'] as Map<String, dynamic>)['code'] ==
                  'APP_MAINTENANCE_MODE') {
            _onMaintenanceModeChanged?.call(true);
          }
          final requestId =
              error.requestOptions.extra['requestId']?.toString() ?? 'unknown';
          _logError(
            'http.request.error',
            fields: {
              'request_id': requestId,
              'method': error.requestOptions.method,
              'path': error.requestOptions.path,
              'status_code': error.response?.statusCode,
              'error_type': error.type.name,
              'message': error.message ?? 'unknown_error',
              'request_body': _serializeForLog(error.requestOptions.data),
              'response_body': _serializeForLog(error.response?.data),
              'retry': error.requestOptions.extra['retryCount'] ?? 0,
              'duration_ms': _requestDurationMs(error.requestOptions),
            },
          );
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

    // Certificate pinning (native platforms only; skipped on web and in tests
    // that inject a non-IO adapter).
    if (_enablePinning && !kIsWeb) {
      _applyPinning();
    }
  }

  // ---------------------------------------------------------------------------
  // Certificate pinning
  // ---------------------------------------------------------------------------

  /// Configures the underlying [IOHttpClientAdapter] to pin the TLS certificate
  /// against [AppConstants.pinnedCertificateSha256].
  ///
  /// Implementation notes:
  /// • A [SecurityContext] with `withTrustedRoots: false` disables ALL system
  ///   CAs, so every TLS handshake goes through [_verifyCertificatePin] — this
  ///   prevents an attacker who installed their own CA on the device from
  ///   bypassing the pin with a "valid" certificate.
  /// • If the adapter is not an [IOHttpClientAdapter] (e.g. a mock injected in
  ///   tests), pinning is gracefully skipped with a warning log.
  void _applyPinning() {
    final adapter = _dio.httpClientAdapter;
    if (adapter is! IOHttpClientAdapter) {
      _logWarning(
        'cert.pinning.skipped',
        fields: {
          'reason': 'adapter_not_io_http',
          'adapter': adapter.runtimeType.toString(),
        },
      );
      return;
    }

    adapter.createHttpClient = () {
      // withTrustedRoots: false → system CA store is not used, so badCertificateCallback
      // is invoked for every connection, enabling true certificate pinning.
      final ctx = SecurityContext(withTrustedRoots: false);
      return HttpClient(context: ctx)
        ..badCertificateCallback = _verifyCertificatePin;
    };

    _logInfo('cert.pinning.enabled', fields: {
      'fingerprint_prefix': _fingerprintPrefix(
        AppConstants.pinnedCertificateSha256,
      ),
    });
  }

  /// Returns `true` only when the SHA-256 fingerprint of [cert] matches
  /// [AppConstants.pinnedCertificateSha256].
  ///
  /// The stored constant may include colons (e.g. `AA:BB:CC:…`) or be a plain
  /// 64-char lowercase hex string — both are normalised before comparison.
  bool _verifyCertificatePin(X509Certificate cert, String host, int port) {
    final actual = sha256.convert(cert.der).toString(); // lowercase hex, no colons
    final expected = AppConstants.pinnedCertificateSha256
        .toLowerCase()
        .replaceAll(':', '');

    final match = actual == expected;
    if (!match) {
      _logError('cert.pinning.mismatch', fields: {
        'host': host,
        'port': port,
        // Log only a short prefix so the full fingerprint is not leaked.
        'expected_prefix': _fingerprintPrefix(expected),
        'actual_prefix': _fingerprintPrefix(actual),
      });
    }
    return match;
  }

  /// Returns the first 16 characters of [fingerprint] followed by `…`, or the
  /// full string if it is shorter — used to avoid logging full cert hashes.
  String _fingerprintPrefix(String fingerprint) {
    const prefixLen = 16;
    return fingerprint.length > prefixLen
        ? '${fingerprint.substring(0, prefixLen)}…'
        : fingerprint;
  }

  // ---------------------------------------------------------------------------

  String? _findHeaderKey(Map<String, dynamic> headers, String target) {
    for (final key in headers.keys) {
      if (key.toLowerCase() == target.toLowerCase()) {
        return key;
      }
    }
    return null;
  }

  String _resolveRequestId(RequestOptions options) {
    final existingHeader = _findHeaderKey(options.headers, 'X-Request-ID');
    if (existingHeader != null) {
      final value = options.headers[existingHeader]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    final existingExtra = options.extra['requestId']?.toString().trim();
    if (existingExtra != null && existingExtra.isNotEmpty) {
      return existingExtra;
    }
    return '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 20)}';
  }

  int? _requestDurationMs(RequestOptions options) {
    final startedAt = options.extra['startedAtMs'];
    final startedAtMs = startedAt is int
        ? startedAt
        : int.tryParse(startedAt?.toString() ?? '');
    if (startedAtMs == null) return null;
    return DateTime.now().millisecondsSinceEpoch - startedAtMs;
  }

  void _logDebug(String event, {required Map<String, Object?> fields}) {
    _logger.d(_structured(event, fields));
  }

  void _logInfo(String event, {required Map<String, Object?> fields}) {
    _logger.i(_structured(event, fields));
  }

  void _logWarning(String event, {required Map<String, Object?> fields}) {
    _logger.w(_structured(event, fields));
  }

  void _logError(String event, {required Map<String, Object?> fields}) {
    _logger.e(_structured(event, fields));
  }

  void _logForStatus(
    int statusCode,
    String event, {
    required Map<String, Object?> fields,
  }) {
    if (statusCode >= 500) {
      _logError(event, fields: fields);
      return;
    }
    if (statusCode >= 400) {
      _logWarning(event, fields: fields);
      return;
    }
    _logInfo(event, fields: fields);
  }

  String _structured(String event, Map<String, Object?> fields) {
    final parts = <String>['event=$event'];
    for (final entry in fields.entries) {
      final value = entry.value;
      if (value == null) continue;
      final safeValue = value.toString().replaceAll('\n', ' ').trim();
      if (safeValue.isEmpty) continue;
      parts.add('${entry.key}=$safeValue');
    }
    return parts.join(' ');
  }

  String? _serializeForLog(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().replaceAll('\n', ' ').trim();
    if (text.isEmpty) {
      return null;
    }
    const maxLength = 500;
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  bool _shouldAttachAuthToken(String? token) {
    if (token == null || token.isEmpty) {
      return false;
    }
    if (isChildSessionToken(token)) {
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
    return _runCancelableRequest(
      externalCancelToken: cancelToken,
      request: (requestCancelToken) => _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: requestCancelToken,
        onReceiveProgress: onReceiveProgress,
      ),
    );
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
    return _runCancelableRequest(
      externalCancelToken: cancelToken,
      request: (requestCancelToken) => _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: requestCancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
    );
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
    return _runCancelableRequest(
      externalCancelToken: cancelToken,
      request: (requestCancelToken) => _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: requestCancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
    );
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
    return _runCancelableRequest(
      externalCancelToken: cancelToken,
      request: (requestCancelToken) => _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: requestCancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
    );
  }

  // DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _runCancelableRequest(
      externalCancelToken: cancelToken,
      request: (requestCancelToken) => _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: requestCancelToken,
      ),
    );
  }

  Future<Response<T>> _runCancelableRequest<T>({
    required Future<Response<T>> Function(CancelToken cancelToken) request,
    CancelToken? externalCancelToken,
  }) async {
    final requestCancelToken = _createRequestCancelToken(
      externalCancelToken: externalCancelToken,
    );
    try {
      return await request(requestCancelToken);
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } finally {
      _managedCancelTokens.remove(requestCancelToken);
    }
  }

  CancelToken _createRequestCancelToken({
    CancelToken? externalCancelToken,
  }) {
    final requestCancelToken = CancelToken();
    _managedCancelTokens.add(requestCancelToken);

    if (externalCancelToken == null) {
      return requestCancelToken;
    }

    if (externalCancelToken.isCancelled) {
      requestCancelToken.cancel(externalCancelToken.cancelError);
      return requestCancelToken;
    }

    externalCancelToken.whenCancel.then((_) {
      if (!requestCancelToken.isCancelled) {
        requestCancelToken.cancel(externalCancelToken.cancelError);
      }
    });
    return requestCancelToken;
  }

  void _handleDioError(DioException e) {
    _logError(
      'http.transport.error',
      fields: {
        'request_id':
            e.requestOptions.extra['requestId']?.toString() ?? 'unknown',
        'method': e.requestOptions.method,
        'path': e.requestOptions.path,
        'status_code': e.response?.statusCode,
        'error_type': e.type.name,
        'message': e.message ?? 'unknown_error',
        'request_body': _serializeForLog(e.requestOptions.data),
        'response_body': _serializeForLog(e.response?.data),
      },
    );
  }

  // Cancel all requests
  void cancelAllRequests() {
    final activeTokens = _managedCancelTokens.toList(growable: false);
    _managedCancelTokens.clear();
    for (final token in activeTokens) {
      if (!token.isCancelled) {
        token.cancel('cancel_all_requests');
      }
    }
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
    if (err.requestOptions.cancelToken?.isCancelled ?? false) {
      handler.next(err);
      return;
    }

    if (_shouldRetry(err)) {
      final retryCount = err.requestOptions.extra['retryCount'] ?? 0;

      if (retryCount < maxRetries) {
        final requestId =
            err.requestOptions.extra['requestId']?.toString() ?? 'unknown';
        final useAltDevPort = _shouldUseAltDevPort(
          err,
          retryCount: retryCount,
        );
        logger.w(
          'event=http.retry.scheduled request_id=$requestId method=${err.requestOptions.method} '
          'path=${err.requestOptions.path} attempt=${retryCount + 1} max_retries=$maxRetries'
          '${useAltDevPort ? ' fallback_port=8001' : ''}',
        );

        // Keep retries responsive so the app does not feel frozen on transient failures.
        await Future.delayed(
          Duration(milliseconds: 250 * (1 << retryCount)),
        );

        if (err.requestOptions.cancelToken?.isCancelled ?? false) {
          handler.next(err);
          return;
        }

        // Clone request with incremented retry count
        try {
          final response = await dio.fetch<dynamic>(
            _buildRetryRequestOptions(
              err.requestOptions,
              retryCount: retryCount + 1,
              useAltDevPort: useAltDevPort,
            ),
          );
          logger.i(
            'event=http.retry.success request_id=$requestId method=${err.requestOptions.method} '
            'path=${err.requestOptions.path} attempt=${retryCount + 1}'
            '${useAltDevPort ? ' fallback_port=8001' : ''}',
          );
          handler.resolve(response);
          return;
        } catch (e) {
          logger.e(
            'event=http.retry.failed request_id=$requestId method=${err.requestOptions.method} '
            'path=${err.requestOptions.path} attempt=${retryCount + 1} error=$e',
          );
        }
      }
    }

    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        (err.response?.statusCode != null && err.response!.statusCode! >= 500);
  }

  bool _shouldUseAltDevPort(
    DioException err, {
    required int retryCount,
  }) {
    if (!kIsWeb || retryCount != 0) {
      return false;
    }
    if (err.type != DioExceptionType.connectionError) {
      return false;
    }
    final uri = err.requestOptions.uri;
    return uri.scheme == 'http' &&
        uri.port == 8000 &&
        (uri.host == '127.0.0.1' ||
            uri.host == 'localhost' ||
            uri.host == Uri.base.host);
  }

  RequestOptions _buildRetryRequestOptions(
    RequestOptions source, {
    required int retryCount,
    required bool useAltDevPort,
  }) {
    final nextUri = useAltDevPort ? source.uri.replace(port: 8001) : source.uri;
    return source.copyWith(
      path: nextUri.toString(),
      baseUrl: '',
      extra: {
        ...source.extra,
        'retryCount': retryCount,
        if (useAltDevPort) 'baseUrlFallback': '8001',
      },
    );
  }
}
