import 'package:dio/dio.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/services/device_identity_service.dart';

class AuthSessionPayload {
  const AuthSessionPayload({
    required this.accessToken,
    required this.user,
    this.refreshToken,
    required this.raw,
  });

  final String accessToken;
  final String? refreshToken;
  final Map<String, dynamic> user;
  final Map<String, dynamic> raw;
}

class PendingVerificationPayload {
  const PendingVerificationPayload({
    required this.success,
    required this.email,
    required this.verificationRequired,
    this.message,
    this.otpExpiresAt,
    this.resendAvailableAt,
    required this.raw,
  });

  final bool success;
  final String email;
  final bool verificationRequired;
  final String? message;
  final DateTime? otpExpiresAt;
  final DateTime? resendAvailableAt;
  final Map<String, dynamic> raw;
}

class OtpActionPayload {
  const OtpActionPayload({
    required this.success,
    required this.email,
    this.message,
    this.otpExpiresAt,
    this.resendAvailableAt,
    required this.raw,
  });

  final bool success;
  final String email;
  final String? message;
  final DateTime? otpExpiresAt;
  final DateTime? resendAvailableAt;
  final Map<String, dynamic> raw;
}

class ChildLoginPayload {
  const ChildLoginPayload({
    required this.success,
    this.childId,
    this.name,
    this.sessionToken,
    this.sessionExpiresAt,
    this.sessionTtlMinutes,
    required this.raw,
  });

  final bool success;
  final String? childId;
  final String? name;
  final String? sessionToken;
  final DateTime? sessionExpiresAt;
  final int? sessionTtlMinutes;
  final Map<String, dynamic> raw;
}

class AuthApi {
  AuthApi(
    this._network, {
    DeviceIdentityService? deviceIdentityService,
  }) : _deviceIdentityService = deviceIdentityService;

  final NetworkService _network;
  final DeviceIdentityService? _deviceIdentityService;

  Future<AuthSessionPayload> login({
    required String email,
    required String password,
    String? twoFactorCode,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
        if (twoFactorCode != null && twoFactorCode.trim().isNotEmpty)
          'two_factor_code': twoFactorCode.trim(),
      },
    );
    return _toSessionPayload(response.data);
  }

  Future<PendingVerificationPayload> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'name': name,
        'email': email.trim().toLowerCase(),
        'password': password,
        'confirm_password': confirmPassword,
      },
    );
    return _toPendingVerificationPayload(response.data);
  }

  Future<AuthSessionPayload> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/auth/verify-email-otp',
      data: {
        'email': email.trim().toLowerCase(),
        'otp': otp.trim(),
      },
    );
    return _toSessionPayload(response.data);
  }

  Future<OtpActionPayload> resendEmailOtp({
    required String email,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/auth/resend-email-otp',
      data: {
        'email': email.trim().toLowerCase(),
      },
    );
    return _toOtpActionPayload(response.data);
  }

  Future<Map<String, dynamic>> refresh({
    required String refreshToken,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> me() async {
    final response = await _network.get<Map<String, dynamic>>('/auth/me');
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> logout() async {
    final response = await _network.post<Map<String, dynamic>>('/auth/logout');
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
  }) async {
    final response = await _network.put<Map<String, dynamic>>(
      '/auth/profile',
      data: {'name': name.trim()},
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/auth/change-password',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<ChildLoginPayload> childLogin({
    required String childId,
    required String name,
    required List<String> picturePassword,
  }) async {
    final deviceId = await _resolveDeviceId();
    final response = await _network.post<Map<String, dynamic>>(
      '/auth/child/login',
      data: {
        'child_id': int.tryParse(childId) ?? childId,
        'name': name.trim(),
        'picture_password': picturePassword,
        if (deviceId != null) 'device_id': deviceId,
      },
    );
    final body = Map<String, dynamic>.from(response.data ?? const {});
    return ChildLoginPayload(
      success: body['success'] == true,
      childId: body['child_id']?.toString(),
      name: body['name']?.toString(),
      sessionToken: body['session_token']?.toString(),
      sessionExpiresAt: body['session_expires_at'] is String
          ? DateTime.tryParse(body['session_expires_at'] as String)
          : null,
      sessionTtlMinutes: (body['session_ttl_minutes'] as num?)?.toInt(),
      raw: body,
    );
  }

  Future<Map<String, dynamic>> validateChildSession({
    required String sessionToken,
  }) async {
    final deviceId = await _resolveDeviceId();
    final response = await _network.post<Map<String, dynamic>>(
      '/auth/child/session/validate',
      data: {
        'session_token': sessionToken,
        if (deviceId != null) 'device_id': deviceId,
      },
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> childRegister({
    required String name,
    required List<String> picturePassword,
    required String parentAccessToken,
    String? parentEmail,
    required int age,
    String? avatar,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/children',
      data: {
        'name': name.trim(),
        'picture_password': picturePassword,
        if (parentEmail != null && parentEmail.trim().isNotEmpty)
          'parent_email': parentEmail.trim().toLowerCase(),
        'age': age,
        if (avatar != null) 'avatar': avatar,
      },
      options: Options(
        headers: {'Authorization': 'Bearer $parentAccessToken'},
      ),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> childChangePassword({
    required String childId,
    required String name,
    required List<String> currentPicturePassword,
    required List<String> newPicturePassword,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/auth/child/change-password',
      data: {
        'child_id': int.tryParse(childId) ?? childId,
        'name': name.trim(),
        'current_picture_password': currentPicturePassword,
        'new_picture_password': newPicturePassword,
      },
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> parentPinStatus() async {
    final response =
        await _network.get<Map<String, dynamic>>('/auth/parent-pin/status');
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> parentPinSet({
    required String pin,
    required String confirmPin,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/auth/parent-pin/set',
      data: {'pin': pin, 'confirm_pin': confirmPin},
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> parentPinVerify({
    required String pin,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/auth/parent-pin/verify',
      data: {'pin': pin},
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> parentPinChange({
    required String currentPin,
    required String newPin,
    required String confirmPin,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/auth/parent-pin/change',
      data: {
        'current_pin': currentPin,
        'new_pin': newPin,
        'confirm_pin': confirmPin,
      },
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> parentPinResetRequest({String? note}) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/auth/parent-pin/reset-request',
      data: {if (note != null) 'note': note},
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/auth/forgot-password',
      data: {'email': email.trim().toLowerCase()},
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> childForgotPassword({
    required int childId,
    required String parentEmail,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/auth/child/forgot-password',
      data: {
        'child_id': childId,
        'parent_email': parentEmail.trim().toLowerCase(),
      },
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> resetChildPicturePassword({
    required String token,
    required List<String> newPicturePassword,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/auth/child/reset-picture-password',
      data: {
        'token': token,
        'new_picture_password': newPicturePassword,
      },
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/auth/reset-password',
      data: {
        'token': token,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  AuthSessionPayload _toSessionPayload(Map<String, dynamic>? data) {
    final body = Map<String, dynamic>.from(data ?? const {});
    return AuthSessionPayload(
      accessToken: body['access_token']?.toString() ?? '',
      refreshToken: body['refresh_token']?.toString(),
      user: Map<String, dynamic>.from(
        body['user'] as Map? ?? const <String, dynamic>{},
      ),
      raw: body,
    );
  }

  PendingVerificationPayload _toPendingVerificationPayload(
    Map<String, dynamic>? data,
  ) {
    final body = Map<String, dynamic>.from(data ?? const {});
    return PendingVerificationPayload(
      success: body['success'] == true,
      email: body['email']?.toString() ?? '',
      verificationRequired: body['verification_required'] == true,
      message: body['message']?.toString(),
      otpExpiresAt: body['otp_expires_at'] is String
          ? DateTime.tryParse(body['otp_expires_at'] as String)
          : null,
      resendAvailableAt: body['resend_available_at'] is String
          ? DateTime.tryParse(body['resend_available_at'] as String)
          : null,
      raw: body,
    );
  }

  OtpActionPayload _toOtpActionPayload(Map<String, dynamic>? data) {
    final body = Map<String, dynamic>.from(data ?? const {});
    return OtpActionPayload(
      success: body['success'] == true,
      email: body['email']?.toString() ?? '',
      message: body['message']?.toString(),
      otpExpiresAt: body['otp_expires_at'] is String
          ? DateTime.tryParse(body['otp_expires_at'] as String)
          : null,
      resendAvailableAt: body['resend_available_at'] is String
          ? DateTime.tryParse(body['resend_available_at'] as String)
          : null,
      raw: body,
    );
  }

  Future<String?> _resolveDeviceId() async {
    return await _deviceIdentityService?.getDeviceId();
  }
}
