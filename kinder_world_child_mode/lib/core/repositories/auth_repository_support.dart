part of 'auth_repository.dart';

mixin _AuthRepositorySupportMixin {
  static const _parentTwoFactorRequiredCode = 'PARENT_TWO_FACTOR_REQUIRED';
  static const _parentInvalidTwoFactorCode = 'PARENT_INVALID_TWO_FACTOR_CODE';
  static const _emailVerificationRequiredCode = 'EMAIL_VERIFICATION_REQUIRED';
  static const _otpResendCooldownCode = 'OTP_RESEND_COOLDOWN';

  SecureStorage get _secureStorage;
  AuthApi get _authApi;
  Logger get _logger;
  Ref get _ref;

  User? _userFromJson(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final userJson = Map<String, dynamic>.from(data);
    final id = userJson['id'];
    if (id != null) {
      userJson['id'] = id.toString();
    }
    return User.fromJson(userJson);
  }

  Future<User?> _persistAuthFromResponse(Map<String, dynamic> data) async {
    final user = _userFromJson(data['user']);
    if (user == null) return null;

    final accessToken = data['access_token'];
    if (accessToken is String && accessToken.isNotEmpty) {
      await _secureStorage.saveAuthToken(accessToken);
      if (user.role == UserRoles.parent) {
        await _secureStorage.saveParentAccessToken(accessToken);
      }
    }

    final refreshToken = data['refresh_token'];
    if (refreshToken is String && refreshToken.isNotEmpty) {
      await _secureStorage.saveRefreshToken(refreshToken);
      if (user.role == UserRoles.parent) {
        await _secureStorage.saveParentRefreshToken(refreshToken);
      }
    }

    await _secureStorage.saveUserId(user.id);
    await _secureStorage.saveUserRole(user.role);
    await _secureStorage.saveUserEmail(user.email);
    if (user.role == UserRoles.parent) {
      await _secureStorage.saveStoredParentId(user.id);
      await _secureStorage.saveStoredParentEmail(user.email);
    }
    await _secureStorage.clearChildSession();
    await _secureStorage.clearParentPinVerification();

    return user;
  }

  Future<void> _persistChildSessionState({
    required String sessionToken,
    required String childId,
  }) async {
    await _secureStorage.deleteRefreshToken();
    await _secureStorage.deleteUserEmail();
    await _secureStorage.clearParentPinVerification();
    await _secureStorage.saveAuthToken(sessionToken);
    await _secureStorage.saveUserId(childId);
    await _secureStorage.saveUserRole(UserRoles.child);
    await _secureStorage.saveChildSession(childId);
  }

  User _buildChildUser({
    required String childId,
    String? childName,
  }) {
    final now = DateTime.now();
    return User(
      id: childId,
      email: '$childId@child.local',
      role: UserRoles.child,
      name: childName?.trim().isNotEmpty == true
          ? childName!.trim()
          : 'Child $childId',
      createdAt: now,
      updatedAt: now,
      isActive: true,
    );
  }

  ChildRegisterResponse? _parseChildRegisterResponse(
      Map<String, dynamic> data) {
    String? childId;
    String? childName;

    if (data['child'] is Map) {
      final childJson = Map<String, dynamic>.from(data['child']);
      childId =
          childJson['id']?.toString() ?? childJson['child_id']?.toString();
      childName = childJson['name']?.toString();
    }

    childId ??= data['child_id']?.toString() ?? data['id']?.toString();
    childName ??= data['name']?.toString();

    if (childId == null || childId.isEmpty) {
      return null;
    }

    return ChildRegisterResponse(
      childId: childId,
      name: childName,
    );
  }

  String? _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is Map && detail['message'] != null) {
        return detail['message'].toString();
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map) {
          final msg = first['msg']?.toString();
          if (msg != null && msg.isNotEmpty) return msg;
        }
        return detail.map((e) => e.toString()).join(', ');
      }
      if (data['message'] != null) return data['message'].toString();
    }
    if (data is String && data.isNotEmpty) return data;
    return e.message;
  }

  Map<String, dynamic>? _extractErrorDetailMap(DioException e) {
    final data = e.response?.data;
    if (data is! Map) {
      return null;
    }
    final detail = data['detail'];
    if (detail is Map) {
      return Map<String, dynamic>.from(detail);
    }
    final error = data['error'];
    if (error is Map) {
      return Map<String, dynamic>.from(error);
    }
    return null;
  }

  String? _extractErrorDetailCode(DioException e) {
    final detail = _extractErrorDetailMap(e);
    final code = detail?['code'];
    if (code == null) {
      return null;
    }
    final normalizedCode = code.toString().trim();
    return normalizedCode.isEmpty ? null : normalizedCode;
  }

  String? _extractTwoFactorMethod(DioException e) {
    final detail = _extractErrorDetailMap(e);
    final method = detail?['two_factor_method'];
    if (method == null) {
      return null;
    }
    final normalizedMethod = method.toString().trim();
    return normalizedMethod.isEmpty ? null : normalizedMethod;
  }

  bool _isParentTwoFactorRequired(DioException e) {
    return _extractErrorDetailCode(e) == _parentTwoFactorRequiredCode;
  }

  bool _isParentInvalidTwoFactorCode(DioException e) {
    return _extractErrorDetailCode(e) == _parentInvalidTwoFactorCode;
  }

  bool _isParentEmailVerificationRequired(DioException e) {
    return _extractErrorDetailCode(e) == _emailVerificationRequiredCode;
  }

  bool _isOtpResendCooldown(DioException e) {
    return _extractErrorDetailCode(e) == _otpResendCooldownCode;
  }

  DateTime? _extractLockedUntil(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map && detail['locked_until'] is String) {
        return DateTime.tryParse(detail['locked_until'].toString());
      }
      if (data['locked_until'] is String) {
        return DateTime.tryParse(data['locked_until'].toString());
      }
    }
    return null;
  }

  DateTime? _extractResendAvailableAt(DioException e) {
    final detail = _extractErrorDetailMap(e);
    final value = detail?['resend_available_at'];
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  ChildRegisterException _childRegisterExceptionFromDio(DioException e) {
    final statusCode = e.response?.statusCode;
    String? detailCode;
    String? message;
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map) {
        final code = detail['code'];
        if (code != null) {
          detailCode = code.toString();
        }
        if (detail['message'] != null) {
          message = detail['message'].toString();
        }
      } else if (detail is String) {
        message = detail;
      } else if (data['code'] != null) {
        detailCode = data['code'].toString();
      }
      if (message == null && data['message'] != null) {
        message = data['message'].toString();
      }
    }
    _logger.e('Child register error: $statusCode - $data');
    return ChildRegisterException(
      statusCode: statusCode,
      detailCode: detailCode,
      message: message,
    );
  }

  String? _extractChildName(dynamic data) {
    String? extractFromMap(Map<String, dynamic> map) {
      String? pick(dynamic value) {
        if (value == null) return null;
        final name = value.toString().trim();
        return name.isNotEmpty ? name : null;
      }

      final direct = pick(map['name']) ??
          pick(map['child_name']) ??
          pick(map['childName']) ??
          pick(map['full_name']) ??
          pick(map['fullName']);
      if (direct != null) return direct;

      for (final key in [
        'child',
        'child_profile',
        'childProfile',
        'profile',
        'user',
        'data',
        'result',
        'payload',
      ]) {
        final nested = map[key];
        if (nested is Map) {
          final name = extractFromMap(Map<String, dynamic>.from(nested));
          if (name != null) return name;
        }
      }
      return null;
    }

    if (data is Map) {
      return extractFromMap(Map<String, dynamic>.from(data));
    }
    return null;
  }

  bool _tokenLooksExpired(String token) {
    return isJwtExpired(token);
  }

  Future<bool> _clearLegacyChildSessionIfNeeded(String? token) async {
    if (!isLegacyChildSessionMarker(token)) {
      return false;
    }

    await _secureStorage.clearAuthOnly();
    return true;
  }

  bool _isUsableParentToken(String? token) {
    if (token == null || token.isEmpty) {
      return false;
    }
    if (isChildSessionToken(token) || isLegacyChildSessionMarker(token)) {
      return false;
    }
    return true;
  }

  Future<String?> _resolveParentRegistrationToken() async {
    final currentRole = await _secureStorage.getUserRole();
    final currentAuthToken = _secureStorage.hasCachedAuthToken
        ? _secureStorage.cachedAuthToken
        : await _secureStorage.getAuthToken();
    if (currentRole == UserRoles.parent &&
        _isUsableParentToken(currentAuthToken)) {
      return currentAuthToken;
    }

    final storedParentToken = await _secureStorage.getParentAccessToken();
    if (_isUsableParentToken(storedParentToken)) {
      return storedParentToken;
    }
    return null;
  }

  bool _shouldNotifyBackendOnLogout({
    required String? role,
    required String? authToken,
  }) {
    return role == UserRoles.parent &&
        authToken != null &&
        authToken.isNotEmpty &&
        !isChildSessionToken(authToken) &&
        !isLegacyChildSessionMarker(authToken);
  }

  ParentPinStatus _emptyParentPinStatus() {
    return const ParentPinStatus(
      hasPin: false,
      isLocked: false,
      failedAttempts: 0,
      lockedUntil: null,
    );
  }
}
