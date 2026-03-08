import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service for sensitive data
class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Storage keys — parent/child session
  static const String _keyAuthToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserRole = 'user_role';
  static const String _keyParentPin = 'parent_pin';
  static const String _keyChildSession = 'child_session';
  static const String _keyIsPremium = 'is_premium';
  static const String _keyPlanType = 'plan_type';

  // Storage keys — admin session (fully separate namespace)
  static const String _keyAdminToken = 'admin_access_token';
  static const String _keyAdminRefreshToken = 'admin_refresh_token';
  static const String _keyAdminId = 'admin_id';
  static const String _keyAdminEmail = 'admin_email';
  static const String _keyAdminName = 'admin_name';
  static const String _keyAdminRoles = 'admin_roles';
  static const String _keyAdminPermissions = 'admin_permissions';

  // ==================== AUTH TOKEN ====================

  Future<String?> getAuthToken() async {
    try {
      return await _storage.read(key: _keyAuthToken);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveAuthToken(String token) async {
    try {
      await _storage.write(key: _keyAuthToken, value: token);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteAuthToken() async {
    try {
      await _storage.delete(key: _keyAuthToken);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== REFRESH TOKEN ====================

  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _keyRefreshToken, value: token);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteRefreshToken() async {
    try {
      await _storage.delete(key: _keyRefreshToken);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== USER ID ====================

  Future<String?> getUserId() async {
    try {
      return await _storage.read(key: _keyUserId);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveUserId(String userId) async {
    try {
      await _storage.write(key: _keyUserId, value: userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteUserId() async {
    try {
      await _storage.delete(key: _keyUserId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== USER EMAIL ====================

  Future<String?> getUserEmail() async {
    try {
      return await _storage.read(key: _keyUserEmail);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveUserEmail(String email) async {
    try {
      await _storage.write(key: _keyUserEmail, value: email);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteUserEmail() async {
    try {
      await _storage.delete(key: _keyUserEmail);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== USER ROLE ====================

  Future<String?> getUserRole() async {
    try {
      return await _storage.read(key: _keyUserRole);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveUserRole(String role) async {
    try {
      await _storage.write(key: _keyUserRole, value: role);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteUserRole() async {
    try {
      await _storage.delete(key: _keyUserRole);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== PARENT PIN ====================

  Future<String?> getParentPin() async {
    try {
      return await _storage.read(key: _keyParentPin);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveParentPin(String pin) async {
    try {
      await _storage.write(key: _keyParentPin, value: pin);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteParentPin() async {
    try {
      await _storage.delete(key: _keyParentPin);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> hasParentPin() async {
    try {
      final pin = await getParentPin();
      return pin != null && pin.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ==================== CHILD SESSION ====================

  Future<String?> getChildSession() async {
    try {
      return await _storage.read(key: _keyChildSession);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveChildSession(String childId) async {
    try {
      await _storage.write(key: _keyChildSession, value: childId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> clearChildSession() async {
    try {
      await _storage.delete(key: _keyChildSession);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== PREMIUM STATUS ====================

  Future<bool?> getIsPremium() async {
    try {
      final value = await _storage.read(key: _keyIsPremium);
      if (value == null) return null;
      return value == 'true';
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveIsPremium(bool isPremium) async {
    try {
      await _storage.write(
        key: _keyIsPremium,
        value: isPremium ? 'true' : 'false',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> clearIsPremium() async {
    try {
      await _storage.delete(key: _keyIsPremium);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== PLAN TYPE ====================

  Future<String?> getPlanType() async {
    try {
      return await _storage.read(key: _keyPlanType);
    } catch (e) {
      return null;
    }
  }

  Future<bool> savePlanType(String planType) async {
    try {
      await _storage.write(key: _keyPlanType, value: planType);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> clearPlanType() async {
    try {
      await _storage.delete(key: _keyPlanType);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== ADMIN SESSION ====================

  Future<String?> getAdminToken() async {
    try {
      return await _storage.read(key: _keyAdminToken);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveAdminToken(String token) async {
    try {
      await _storage.write(key: _keyAdminToken, value: token);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getAdminRefreshToken() async {
    try {
      return await _storage.read(key: _keyAdminRefreshToken);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveAdminRefreshToken(String token) async {
    try {
      await _storage.write(key: _keyAdminRefreshToken, value: token);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getAdminId() async {
    try {
      return await _storage.read(key: _keyAdminId);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveAdminId(String id) async {
    try {
      await _storage.write(key: _keyAdminId, value: id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getAdminEmail() async {
    try {
      return await _storage.read(key: _keyAdminEmail);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveAdminEmail(String email) async {
    try {
      await _storage.write(key: _keyAdminEmail, value: email);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getAdminName() async {
    try {
      return await _storage.read(key: _keyAdminName);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveAdminName(String name) async {
    try {
      await _storage.write(key: _keyAdminName, value: name);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Roles stored as comma-separated string: "super_admin,content_admin"
  Future<List<String>> getAdminRoles() async {
    try {
      final raw = await _storage.read(key: _keyAdminRoles);
      if (raw == null || raw.isEmpty) return [];
      return raw.split(',').where((s) => s.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> saveAdminRoles(List<String> roles) async {
    try {
      await _storage.write(key: _keyAdminRoles, value: roles.join(','));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Permissions stored as comma-separated string
  Future<List<String>> getAdminPermissions() async {
    try {
      final raw = await _storage.read(key: _keyAdminPermissions);
      if (raw == null || raw.isEmpty) return [];
      return raw.split(',').where((s) => s.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> saveAdminPermissions(List<String> permissions) async {
    try {
      await _storage.write(key: _keyAdminPermissions, value: permissions.join(','));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isAdminAuthenticated() async {
    try {
      final token = await getAdminToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Clear only admin session data — does NOT touch parent/child session.
  Future<bool> clearAdminSession() async {
    try {
      await _storage.delete(key: _keyAdminToken);
      await _storage.delete(key: _keyAdminRefreshToken);
      await _storage.delete(key: _keyAdminId);
      await _storage.delete(key: _keyAdminEmail);
      await _storage.delete(key: _keyAdminName);
      await _storage.delete(key: _keyAdminRoles);
      await _storage.delete(key: _keyAdminPermissions);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== CLEAR ALL ====================

  Future<bool> clearAll() async {
    try {
      await _storage.deleteAll();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear only authentication/session data while preserving child profiles and preferences
  /// Use this for logout to keep local child data intact
  Future<bool> clearAuthOnly() async {
    try {
      // Clear auth tokens and session
      await _storage.delete(key: _keyAuthToken);
      await _storage.delete(key: _keyUserRole);
      await _storage.delete(key: _keyUserId);
      await _storage.delete(key: _keyUserEmail);
      await _storage.delete(key: _keyChildSession);
      await _storage.delete(key: _keyParentPin);
      
      // Preserve: child profiles, plan type, theme settings, privacy settings
      // These are accessible without authentication
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== HELPERS ====================

  Future<bool> isAuthenticated() async {
    try {
      final token = await getAuthToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, String>> getAllSecureData() async {
    try {
      return await _storage.readAll();
    } catch (e) {
      return {};
    }
  }

  /// Backwards-compatible alias for getting the parent id (previous API used getParentId)
  Future<String?> getParentId() async => getUserId();

  /// Backwards-compatible alias for getting the parent email
  Future<String?> getParentEmail() async => getUserEmail();
}
