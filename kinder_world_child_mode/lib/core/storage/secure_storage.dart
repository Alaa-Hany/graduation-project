import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionSnapshot {
  const SecureSessionSnapshot({
    required this.authToken,
    required this.userRole,
    required this.childSession,
    required this.parentPinVerified,
  });

  final String? authToken;
  final String? userRole;
  final String? childSession;
  final bool parentPinVerified;

  bool get isAuthenticated => authToken != null && authToken!.isNotEmpty;
}

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
  static const String _keyParentPinVerified = 'parent_pin_verified';
  static const String _keyChildSession = 'child_session';
  static const String _keyParentAccessToken = 'parent_access_token';
  static const String _keyParentRefreshToken = 'parent_refresh_token';
  static const String _keyParentId = 'parent_user_id';
  static const String _keyParentEmail = 'parent_user_email';
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

  String? _authTokenCache;
  bool _hasAuthTokenCache = false;
  String? _userIdCache;
  bool _hasUserIdCache = false;
  String? _userEmailCache;
  bool _hasUserEmailCache = false;
  String? _userRoleCache;
  bool _hasUserRoleCache = false;
  String? _childSessionCache;
  bool _hasChildSessionCache = false;
  bool _parentPinVerifiedCache = false;
  bool _hasParentPinVerifiedCache = false;

  void _clearSessionCaches() {
    _authTokenCache = null;
    _hasAuthTokenCache = true;
    _userIdCache = null;
    _hasUserIdCache = true;
    _userEmailCache = null;
    _hasUserEmailCache = true;
    _userRoleCache = null;
    _hasUserRoleCache = true;
    _childSessionCache = null;
    _hasChildSessionCache = true;
    _parentPinVerifiedCache = false;
    _hasParentPinVerifiedCache = true;
  }

  bool get hasCachedSessionSnapshot =>
      _hasAuthTokenCache &&
      _hasUserIdCache &&
      _hasUserEmailCache &&
      _hasUserRoleCache &&
      _hasChildSessionCache &&
      _hasParentPinVerifiedCache;

  bool get hasCachedAuthToken => _hasAuthTokenCache;
  bool get hasCachedParentPinVerification => _hasParentPinVerifiedCache;
  bool get hasCachedUserId => _hasUserIdCache;
  bool get hasCachedUserEmail => _hasUserEmailCache;

  String? get cachedAuthToken => _authTokenCache;
  String? get cachedUserId => _userIdCache;
  String? get cachedUserEmail => _userEmailCache;

  SecureSessionSnapshot get cachedSessionSnapshot => SecureSessionSnapshot(
        authToken: _authTokenCache,
        userRole: _userRoleCache,
        childSession: _childSessionCache,
        parentPinVerified: _parentPinVerifiedCache,
      );

  Future<void> preloadSessionState() async {
    try {
      final values = await _storage.readAll();
      _authTokenCache = values[_keyAuthToken];
      _hasAuthTokenCache = true;
      _userIdCache = values[_keyUserId];
      _hasUserIdCache = true;
      _userEmailCache = values[_keyUserEmail];
      _hasUserEmailCache = true;
      _userRoleCache = values[_keyUserRole];
      _hasUserRoleCache = true;
      _childSessionCache = values[_keyChildSession];
      _hasChildSessionCache = true;
      _parentPinVerifiedCache = values[_keyParentPinVerified] == 'true';
      _hasParentPinVerifiedCache = true;
    } catch (e) {
      _authTokenCache = null;
      _hasAuthTokenCache = true;
      _userIdCache = null;
      _hasUserIdCache = true;
      _userEmailCache = null;
      _hasUserEmailCache = true;
      _userRoleCache = null;
      _hasUserRoleCache = true;
      _childSessionCache = null;
      _hasChildSessionCache = true;
      _parentPinVerifiedCache = false;
      _hasParentPinVerifiedCache = true;
    }
  }

  // ==================== AUTH TOKEN ====================

  Future<String?> getAuthToken() async {
    if (_hasAuthTokenCache) {
      return _authTokenCache;
    }
    try {
      final value = await _storage.read(key: _keyAuthToken);
      _authTokenCache = value;
      _hasAuthTokenCache = true;
      return value;
    } catch (e) {
      _authTokenCache = null;
      _hasAuthTokenCache = true;
      return null;
    }
  }

  Future<bool> saveAuthToken(String token) async {
    try {
      await _storage.write(key: _keyAuthToken, value: token);
      _authTokenCache = token;
      _hasAuthTokenCache = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteAuthToken() async {
    try {
      await _storage.delete(key: _keyAuthToken);
      _authTokenCache = null;
      _hasAuthTokenCache = true;
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
    if (_hasUserIdCache) {
      return _userIdCache;
    }
    try {
      final value = await _storage.read(key: _keyUserId);
      _userIdCache = value;
      _hasUserIdCache = true;
      return value;
    } catch (e) {
      _userIdCache = null;
      _hasUserIdCache = true;
      return null;
    }
  }

  Future<bool> saveUserId(String userId) async {
    try {
      await _storage.write(key: _keyUserId, value: userId);
      _userIdCache = userId;
      _hasUserIdCache = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteUserId() async {
    try {
      await _storage.delete(key: _keyUserId);
      _userIdCache = null;
      _hasUserIdCache = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== USER EMAIL ====================

  Future<String?> getUserEmail() async {
    if (_hasUserEmailCache) {
      return _userEmailCache;
    }
    try {
      final value = await _storage.read(key: _keyUserEmail);
      _userEmailCache = value;
      _hasUserEmailCache = true;
      return value;
    } catch (e) {
      _userEmailCache = null;
      _hasUserEmailCache = true;
      return null;
    }
  }

  Future<bool> saveUserEmail(String email) async {
    try {
      await _storage.write(key: _keyUserEmail, value: email);
      _userEmailCache = email;
      _hasUserEmailCache = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteUserEmail() async {
    try {
      await _storage.delete(key: _keyUserEmail);
      _userEmailCache = null;
      _hasUserEmailCache = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== USER ROLE ====================

  Future<String?> getUserRole() async {
    if (_hasUserRoleCache) {
      return _userRoleCache;
    }
    try {
      final value = await _storage.read(key: _keyUserRole);
      _userRoleCache = value;
      _hasUserRoleCache = true;
      return value;
    } catch (e) {
      _userRoleCache = null;
      _hasUserRoleCache = true;
      return null;
    }
  }

  Future<bool> saveUserRole(String role) async {
    try {
      await _storage.write(key: _keyUserRole, value: role);
      _userRoleCache = role;
      _hasUserRoleCache = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteUserRole() async {
    try {
      await _storage.delete(key: _keyUserRole);
      _userRoleCache = null;
      _hasUserRoleCache = true;
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

  Future<bool> isParentPinVerified() async {
    if (_hasParentPinVerifiedCache) {
      return _parentPinVerifiedCache;
    }
    try {
      final value = await _storage.read(key: _keyParentPinVerified);
      _parentPinVerifiedCache = value == 'true';
      _hasParentPinVerifiedCache = true;
      return _parentPinVerifiedCache;
    } catch (e) {
      _parentPinVerifiedCache = false;
      _hasParentPinVerifiedCache = true;
      return false;
    }
  }

  Future<bool> saveParentPinVerified(bool isVerified) async {
    try {
      await _storage.write(
        key: _keyParentPinVerified,
        value: isVerified ? 'true' : 'false',
      );
      _parentPinVerifiedCache = isVerified;
      _hasParentPinVerifiedCache = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> clearParentPinVerification() async {
    try {
      await _storage.delete(key: _keyParentPinVerified);
      _parentPinVerifiedCache = false;
      _hasParentPinVerifiedCache = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== CHILD SESSION ====================

  Future<String?> getChildSession() async {
    if (_hasChildSessionCache) {
      return _childSessionCache;
    }
    try {
      final value = await _storage.read(key: _keyChildSession);
      _childSessionCache = value;
      _hasChildSessionCache = true;
      return value;
    } catch (e) {
      _childSessionCache = null;
      _hasChildSessionCache = true;
      return null;
    }
  }

  Future<bool> saveChildSession(String childId) async {
    try {
      await _storage.write(key: _keyChildSession, value: childId);
      _childSessionCache = childId;
      _hasChildSessionCache = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> clearChildSession() async {
    try {
      await _storage.delete(key: _keyChildSession);
      _childSessionCache = null;
      _hasChildSessionCache = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getParentAccessToken() async {
    try {
      return await _storage.read(key: _keyParentAccessToken);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveParentAccessToken(String token) async {
    try {
      await _storage.write(key: _keyParentAccessToken, value: token);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getParentRefreshToken() async {
    try {
      return await _storage.read(key: _keyParentRefreshToken);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveParentRefreshToken(String token) async {
    try {
      await _storage.write(key: _keyParentRefreshToken, value: token);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getStoredParentId() async {
    try {
      return await _storage.read(key: _keyParentId);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveStoredParentId(String parentId) async {
    try {
      await _storage.write(key: _keyParentId, value: parentId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getStoredParentEmail() async {
    try {
      return await _storage.read(key: _keyParentEmail);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveStoredParentEmail(String email) async {
    try {
      await _storage.write(key: _keyParentEmail, value: email);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> clearStoredParentSession() async {
    try {
      await _storage.delete(key: _keyParentAccessToken);
      await _storage.delete(key: _keyParentRefreshToken);
      await _storage.delete(key: _keyParentId);
      await _storage.delete(key: _keyParentEmail);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== PREMIUM STATUS ====================
  // Legacy display cache only. Do not use for entitlement decisions.

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
  // Legacy display cache only. Do not use for entitlement decisions.

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
      await _storage.write(
          key: _keyAdminPermissions, value: permissions.join(','));
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
      _clearSessionCaches();
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
      await _storage.delete(key: _keyRefreshToken);
      await _storage.delete(key: _keyUserRole);
      await _storage.delete(key: _keyUserId);
      await _storage.delete(key: _keyUserEmail);
      await _storage.delete(key: _keyChildSession);
      await _storage.delete(key: _keyParentPinVerified);
      await _storage.delete(key: _keyIsPremium);
      await _storage.delete(key: _keyPlanType);
      await clearStoredParentSession();
      _clearSessionCaches();

      // Preserve: child profiles, theme settings, privacy settings
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
  Future<String?> getParentId() async {
    final stored = await getStoredParentId();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return getUserId();
  }

  /// Backwards-compatible alias for getting the parent email
  Future<String?> getParentEmail() async {
    final stored = await getStoredParentEmail();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return getUserEmail();
  }
}
