import 'package:dio/dio.dart';
import 'package:kinder_world/core/models/user.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

class ChildLoginException implements Exception {
  final int? statusCode;

  const ChildLoginException({this.statusCode});
}

class ChildRegisterException implements Exception {
  final int? statusCode;
  final String? detailCode;
  final String? message;

  const ChildRegisterException({
    this.statusCode,
    this.detailCode,
    this.message,
  });
}

class ChildRegisterResponse {
  final String childId;
  final String? name;

  const ChildRegisterResponse({
    required this.childId,
    this.name,
  });
}

class ParentAuthException implements Exception {
  final String message;
  final int? statusCode;

  const ParentAuthException({required this.message, this.statusCode});
}

class ParentPinStatus {
  final bool hasPin;
  final bool isLocked;
  final int failedAttempts;
  final DateTime? lockedUntil;

  const ParentPinStatus({
    required this.hasPin,
    required this.isLocked,
    required this.failedAttempts,
    required this.lockedUntil,
  });
}

class ParentPinActionResult {
  final bool success;
  final String? message;
  final String? error;
  final DateTime? lockedUntil;

  const ParentPinActionResult({
    required this.success,
    this.message,
    this.error,
    this.lockedUntil,
  });
}

/// Repository for authentication operations
class AuthRepository {
  final SecureStorage _secureStorage;
  final NetworkService _networkService;
  final Logger _logger;

  AuthRepository({
    required SecureStorage secureStorage,
    required NetworkService networkService,
    required Logger logger,
  })  : _secureStorage = secureStorage,
        _networkService = networkService,
        _logger = logger;

  User? _userFromJson(dynamic data) {
    if (data is Map<String, dynamic>) {
      final userJson = Map<String, dynamic>.from(data);
      final id = userJson['id'];
      if (id != null) {
        userJson['id'] = id.toString();
      }
      return User.fromJson(userJson);
    }
    return null;
  }

  Future<User?> _persistAuthFromResponse(Map<String, dynamic> data) async {
    final user = _userFromJson(data['user']);
    if (user == null) return null;

    final accessToken = data['access_token'];
    if (accessToken is String && accessToken.isNotEmpty) {
      await _secureStorage.saveAuthToken(accessToken);
    }

    final refreshToken = data['refresh_token'];
    if (refreshToken is String && refreshToken.isNotEmpty) {
      await _secureStorage.saveRefreshToken(refreshToken);
    }

    await _secureStorage.saveUserId(user.id);
    await _secureStorage.saveUserRole(user.role);
    await _secureStorage.saveUserEmail(user.email);

    return user;
  }

  // ==================== AUTHENTICATION STATE ====================

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    try {
      return await _secureStorage.isAuthenticated();
    } catch (e) {
      _logger.e('Error checking authentication: $e');
      return false;
    }
  }

  /// Get current user from storage/API
  Future<User?> getCurrentUser() async {
    String? role;
    try {
      role = await _secureStorage.getUserRole();
      if (role == null) return null;

      if (role == UserRoles.child) {
        final childId = await _secureStorage.getChildSession();
        if (childId == null) return null;
        final now = DateTime.now();
        return User(
          id: childId,
          email: '$childId@child.local',
          role: UserRoles.child,
          name: 'Child $childId',
          createdAt: now,
          updatedAt: now,
          isActive: true,
        );
      }

      final response = await _networkService.get<Map<String, dynamic>>('/auth/me');
      final data = response.data;
      if (data == null) return null;
      return _userFromJson(data['user']);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      _logger.e('Error getting current user: ${e.message}');
      if (role == UserRoles.parent && statusCode == 401) {
        final refreshedToken = await refreshToken();
        if (refreshedToken != null && refreshedToken.isNotEmpty) {
          try {
            final retryResponse =
                await _networkService.get<Map<String, dynamic>>('/auth/me');
            final retryData = retryResponse.data;
            if (retryData == null) return null;
            return _userFromJson(retryData['user']);
          } on DioException catch (retryError) {
            _logger.e(
              'Error retrying current user after refresh: ${retryError.message}',
            );
          }
        }
        await _secureStorage.clearAuthOnly();
      }
      return null;
    } catch (e) {
      _logger.e('Error getting current user: $e');
      return null;
    }
  }

  /// Alias for getCurrentUser - fetch fresh user data from API
  Future<User?> getMe() async {
    return await getCurrentUser();
  }

  /// Get user role
  Future<String?> getUserRole() async {
    try {
      return await _secureStorage.getUserRole();
    } catch (e) {
      _logger.e('Error getting user role: $e');
      return null;
    }
  }

  // ==================== PARENT AUTHENTICATION ====================

  /// Login parent with email and password
  Future<User?> loginParent({
    required String email,
    required String password,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      _logger.d('Attempting parent login for: $normalizedEmail');

      if (normalizedEmail.isEmpty || password.isEmpty) {
        _logger.w('Login failed: Empty credentials');
        return null;
      }

      final response = await _networkService.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': normalizedEmail,
          'password': password,
        },
      );

      final data = response.data;
      if (data == null) {
        _logger.e('Login failed: empty response');
        return null;
      }

      final user = await _persistAuthFromResponse(Map<String, dynamic>.from(data));
      if (user == null) {
        _logger.e('Login failed: invalid user data');
        return null;
      }

      _logger.d('Parent login successful: ${user.id}');
      return user;
    } on DioException catch (e) {
      _logger.e('Parent login error: ${e.response?.statusCode} - ${e.response?.data}');
      throw ParentAuthException(
        message: _extractErrorMessage(e) ?? 'Invalid credentials',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      _logger.e('Parent login error: $e');
      return null;
    }
  }

  /// Register new parent account
  Future<User?> registerParent({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      _logger.d('Attempting parent registration for: $normalizedEmail');

      // Validation
      if (password != confirmPassword) {
        _logger.w('Registration failed: Passwords do not match');
        return null;
      }

      if (password.length < 6) {
        _logger.w('Registration failed: Password too short');
        return null;
      }

      final response = await _networkService.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'name': name,
          'email': normalizedEmail,
          'password': password,
          'confirmPassword': confirmPassword,
        },
      );

      final data = response.data;
      if (data == null) {
        _logger.e('Registration failed: empty response');
        return null;
      }

      final user = await _persistAuthFromResponse(Map<String, dynamic>.from(data));
      if (user == null) {
        _logger.e('Registration failed: invalid user data');
        return null;
      }

      _logger.d('Parent registration successful: ${user.id}');
      return user;
    } on DioException catch (e) {
      _logger.e('Parent registration error: ${e.response?.statusCode} - ${e.response?.data}');
      throw ParentAuthException(
        message: _extractErrorMessage(e) ?? 'Registration failed',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      _logger.e('Parent registration error: $e');
      return null;
    }
  }

  String? _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is Map && detail['message'] != null) {
        return detail['message'].toString();
      }
      if (data['message'] != null) return data['message'].toString();
    }
    if (data is String && data.isNotEmpty) return data;
    return e.message;
  }

  // ==================== CHILD AUTHENTICATION ====================

  /// Login child via picture password
  Future<User?> loginChild({
    required String childId,
    required String childName,
    required List<String> picturePassword,
  }) async {
    try {
      _logger.d('Attempting child login for: $childId');

      if (childId.trim().isEmpty ||
          childName.trim().isEmpty ||
          picturePassword.length != 3) {
        _logger.w('Child login failed: Missing or invalid credentials');
        throw const ChildLoginException(statusCode: 422);
      }

      final response = await _networkService.post<Map<String, dynamic>>(
        '/auth/child/login',
        data: {
          'child_id': int.tryParse(childId) ?? childId,
          'name': childName.trim(),
          'picture_password': picturePassword,
        },
      );

      final data = response.data;
      final success = data != null && data['success'] == true;
      if (!success) {
        _logger.w('Child login failed: Invalid credentials');
        throw const ChildLoginException(statusCode: 401);
      }

      final resolvedName = _extractChildName(data);
      final now = DateTime.now();
      final childUser = User(
        id: childId,
        email: '$childId@child.local',
        role: UserRoles.child,
        name: resolvedName?.isNotEmpty == true
            ? resolvedName!.trim()
            : 'Child $childId',
        createdAt: now,
        updatedAt: now,
        isActive: true,
      );

      await _secureStorage.saveAuthToken('child_session_$childId');
      await _secureStorage.saveUserId(childId);
      await _secureStorage.saveUserRole(UserRoles.child);
      await _secureStorage.saveChildSession(childId);

      _logger.d('Child login successful: ${childUser.id}');
      return childUser;
    } on DioException catch (e) {
      _logger.e('Child login error: ${e.response?.statusCode} - ${e.response?.data}');
      throw ChildLoginException(statusCode: e.response?.statusCode);
    } catch (e) {
      _logger.e('Child login error: $e');
      throw const ChildLoginException();
    }
  }

  /// Register child via picture password
  Future<ChildRegisterResponse?> registerChild({
    required String name,
    required List<String> picturePassword,
    required String parentEmail,
    required int age,
    String? avatar,
  }) async {
    try {
      final trimmedName = name.trim();
      final trimmedEmail = parentEmail.trim().toLowerCase();

      if (trimmedName.isEmpty ||
          trimmedEmail.isEmpty ||
          picturePassword.length != 3 ||
          age < 5 ||
          age > 12) {
        _logger.w('Child register failed: Missing or invalid data');
        throw const ChildRegisterException(statusCode: 422);
      }

      final response = await _networkService.post<Map<String, dynamic>>(
        '/auth/child/register',
        data: {
          'name': trimmedName,
          'picture_password': picturePassword,
          'parent_email': trimmedEmail,
          'age': age,
          if (avatar != null) 'avatar': avatar,
        },
      );

      final data = response.data;
      if (data == null) {
        _logger.e('Child register failed: empty response');
        return null;
      }

      String? childId;
      String? childName;

      if (data['child'] is Map) {
        final childJson = Map<String, dynamic>.from(data['child']);
        childId = childJson['id']?.toString() ?? childJson['child_id']?.toString();
        childName = childJson['name']?.toString();
      }

      childId ??= data['child_id']?.toString() ?? data['id']?.toString();
      childName ??= data['name']?.toString();

      if (childId == null || childId.isEmpty) {
        _logger.e('Child register failed: missing child id');
        return null;
      }

      return ChildRegisterResponse(
        childId: childId,
        name: childName,
      );
    } on DioException catch (e) {
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
      throw ChildRegisterException(
        statusCode: statusCode,
        detailCode: detailCode,
        message: message,
      );
    } catch (e) {
      _logger.e('Child register error: $e');
      throw const ChildRegisterException();
    }
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
          final name =
              extractFromMap(Map<String, dynamic>.from(nested));
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

  // ==================== LOGOUT ====================

  /// Logout current user (clears auth tokens only, preserves local profiles/preferences)
  Future<bool> logout() async {
    try {
      _logger.d('Logging out user');
      await _secureStorage.clearParentPinVerification();
      await _secureStorage.clearAuthOnly();
      _logger.d('Logout successful');
      return true;
    } catch (e) {
      _logger.e('Logout error: $e');
      return false;
    }
  }

  // ==================== PARENT PIN ====================

  Future<ParentPinStatus> getParentPinStatus() async {
    try {
      final response = await _networkService.get<Map<String, dynamic>>(
        '/auth/parent-pin/status',
      );
      final data = response.data ?? const <String, dynamic>{};

      final status = ParentPinStatus(
        hasPin: data['has_pin'] == true,
        isLocked: data['is_locked'] == true,
        failedAttempts: (data['failed_attempts'] as num?)?.toInt() ?? 0,
        lockedUntil: data['locked_until'] is String
            ? DateTime.tryParse(data['locked_until'] as String)
            : null,
      );

      // Migrate legacy local PIN if it exists and backend has no PIN yet.
      final legacyPin = await _secureStorage.getParentPin();
      if (!status.hasPin &&
          legacyPin != null &&
          legacyPin.length == 4 &&
          RegExp(r'^\d{4}$').hasMatch(legacyPin)) {
        final migrated = await setParentPin(legacyPin, legacyPin);
        if (migrated.success) {
          await _secureStorage.deleteParentPin();
          return const ParentPinStatus(
            hasPin: true,
            isLocked: false,
            failedAttempts: 0,
            lockedUntil: null,
          );
        }
      }

      return status;
    } catch (e) {
      _logger.e('Error getting parent PIN status: $e');
      return const ParentPinStatus(
        hasPin: false,
        isLocked: false,
        failedAttempts: 0,
        lockedUntil: null,
      );
    }
  }

  Future<ParentPinActionResult> setParentPin(String pin, String confirmPin) async {
    try {
      final response = await _networkService.post<Map<String, dynamic>>(
        '/auth/parent-pin/set',
        data: {
          'pin': pin,
          'confirm_pin': confirmPin,
        },
      );
      await _secureStorage.saveParentPinVerified(true);
      return ParentPinActionResult(
        success: response.data?['success'] == true,
        message: response.data?['message']?.toString(),
      );
    } on DioException catch (e) {
      return ParentPinActionResult(
        success: false,
        error: _extractErrorMessage(e) ?? 'Failed to set PIN',
      );
    } catch (e) {
      _logger.e('Error setting parent PIN: $e');
      return const ParentPinActionResult(
        success: false,
        error: 'Failed to set PIN',
      );
    }
  }

  Future<ParentPinActionResult> verifyParentPin(String enteredPin) async {
    try {
      final response = await _networkService.post<Map<String, dynamic>>(
        '/auth/parent-pin/verify',
        data: {'pin': enteredPin},
      );
      await _secureStorage.saveParentPinVerified(true);
      return ParentPinActionResult(
        success: response.data?['success'] == true,
        message: response.data?['message']?.toString(),
      );
    } on DioException catch (e) {
      final lockedUntil = _extractLockedUntil(e);
      await _secureStorage.saveParentPinVerified(false);
      return ParentPinActionResult(
        success: false,
        error: _extractErrorMessage(e) ?? 'Incorrect PIN',
        lockedUntil: lockedUntil,
      );
    } catch (e) {
      _logger.e('Error verifying parent PIN: $e');
      return const ParentPinActionResult(
        success: false,
        error: 'Failed to verify PIN',
      );
    }
  }

  Future<ParentPinActionResult> changeParentPin({
    required String currentPin,
    required String newPin,
    required String confirmPin,
  }) async {
    try {
      final response = await _networkService.post<Map<String, dynamic>>(
        '/auth/parent-pin/change',
        data: {
          'current_pin': currentPin,
          'new_pin': newPin,
          'confirm_pin': confirmPin,
        },
      );
      await _secureStorage.saveParentPinVerified(true);
      return ParentPinActionResult(
        success: response.data?['success'] == true,
        message: response.data?['message']?.toString(),
      );
    } on DioException catch (e) {
      return ParentPinActionResult(
        success: false,
        error: _extractErrorMessage(e) ?? 'Failed to change PIN',
      );
    } catch (e) {
      _logger.e('Error changing parent PIN: $e');
      return const ParentPinActionResult(
        success: false,
        error: 'Failed to change PIN',
      );
    }
  }

  Future<ParentPinActionResult> requestParentPinReset({String? note}) async {
    try {
      final response = await _networkService.post<Map<String, dynamic>>(
        '/auth/parent-pin/reset-request',
        data: {
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );
      return ParentPinActionResult(
        success: response.data?['success'] == true,
        message: response.data?['message']?.toString(),
      );
    } on DioException catch (e) {
      return ParentPinActionResult(
        success: false,
        error: _extractErrorMessage(e) ?? 'Failed to request PIN reset',
      );
    } catch (e) {
      _logger.e('Error requesting parent PIN reset: $e');
      return const ParentPinActionResult(
        success: false,
        error: 'Failed to request PIN reset',
      );
    }
  }

  Future<bool> isPinRequired() async {
    try {
      final status = await getParentPinStatus();
      return status.hasPin;
    } catch (e) {
      _logger.e('Error checking PIN requirement: $e');
      return false;
    }
  }

  Future<bool> isParentPinVerified() async {
    try {
      return await _secureStorage.isParentPinVerified();
    } catch (e) {
      _logger.e('Error reading parent PIN verification: $e');
      return false;
    }
  }

  Future<void> clearParentPinVerification() async {
    await _secureStorage.clearParentPinVerification();
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

  // ==================== CHILD SESSION ====================

  /// Save child session
  Future<bool> saveChildSession(String childId) async {
    try {
      return await _secureStorage.saveChildSession(childId);
    } catch (e) {
      _logger.e('Error saving child session: $e');
      return false;
    }
  }

  /// Get current child session
  Future<String?> getChildSession() async {
    try {
      return await _secureStorage.getChildSession();
    } catch (e) {
      _logger.e('Error getting child session: $e');
      return null;
    }
  }

  /// Clear child session
  Future<bool> clearChildSession() async {
    try {
      return await _secureStorage.clearChildSession();
    } catch (e) {
      _logger.e('Error clearing child session: $e');
      return false;
    }
  }

  // ==================== PREMIUM STATUS ====================

  Future<bool?> getPremiumStatus() async {
    try {
      return await _secureStorage.getIsPremium();
    } catch (e) {
      _logger.e('Error getting premium status: $e');
      return null;
    }
  }

  Future<bool> savePremiumStatus(bool isPremium) async {
    try {
      return await _secureStorage.saveIsPremium(isPremium);
    } catch (e) {
      _logger.e('Error saving premium status: $e');
      return false;
    }
  }

  // ==================== PLAN TYPE ====================

  Future<String?> getPlanType() async {
    try {
      return await _secureStorage.getPlanType();
    } catch (e) {
      _logger.e('Error getting plan type: $e');
      return null;
    }
  }

  Future<bool> savePlanType(String planType) async {
    try {
      return await _secureStorage.savePlanType(planType);
    } catch (e) {
      _logger.e('Error saving plan type: $e');
      return false;
    }
  }

  // ==================== TOKEN MANAGEMENT ====================

  /// Refresh authentication token
  Future<String?> refreshToken() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return null;

      final response = await _networkService.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data;
      final newToken = data?['access_token'];
      if (newToken is String && newToken.isNotEmpty) {
        await _secureStorage.saveAuthToken(newToken);
        return newToken;
      }

      return null;
    } on DioException catch (e) {
      _logger.e('Error refreshing token: ${e.response?.statusCode} - ${e.response?.data}');
      return null;
    } catch (e) {
      _logger.e('Error refreshing token: $e');
      return null;
    }
  }

  /// Validate authentication token
  Future<bool> validateToken() async {
    try {
      final token = await _secureStorage.getAuthToken();
      
      if (token == null || token.isEmpty) return false;

      // For now, just check if token exists
      return true;
    } catch (e) {
      _logger.e('Error validating token: $e');
      return false;
    }
  }
}
