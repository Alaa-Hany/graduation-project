import 'package:dio/dio.dart';

import 'package:kinder_world/core/network/network_service.dart';

class AdminApi {
  const AdminApi(this._network);

  final NetworkService _network;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? twoFactorCode,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/admin/auth/login',
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
        if (twoFactorCode != null && twoFactorCode.trim().isNotEmpty)
          'two_factor_code': twoFactorCode.trim(),
      },
      options: Options(headers: {'Authorization': null}),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> bootstrapStatus() async {
    final response = await _network.get<Map<String, dynamic>>(
      '/admin/auth/bootstrap/status',
      options: Options(headers: {'Authorization': null}),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> bootstrap({
    required String email,
    required String password,
    String? name,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/admin/auth/bootstrap',
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      },
      options: Options(headers: {'Authorization': null}),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> refresh({
    required String refreshToken,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/admin/auth/refresh',
      data: {'refresh_token': refreshToken},
      options: Options(headers: {'Authorization': null}),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> me({
    required String accessToken,
  }) async {
    final response = await _network.get<Map<String, dynamic>>(
      '/admin/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> logout({
    required String accessToken,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/admin/auth/logout',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }
}
