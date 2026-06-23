part of 'auth_repository.dart';

mixin _AuthRepositoryStateMixin on _AuthRepositorySupportMixin {
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
        return await _resolveCurrentChildUser();
      }

      final data = await _authApi.me();
      return _userFromJson(data['user']);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      _logger.e('Error getting current user: ${e.message}');
      if (role == UserRoles.child && statusCode == 401) {
        await _secureStorage.clearAuthOnly();
      }
      if (role == UserRoles.parent && statusCode == 401) {
        final refreshedToken = await refreshToken();
        if (refreshedToken != null && refreshedToken.isNotEmpty) {
          try {
            final retryData = await _authApi.me();
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

  Future<User?> _resolveCurrentChildUser() async {
    final sessionToken = await _secureStorage.getAuthToken();
    if (sessionToken == null || sessionToken.isEmpty) {
      return null;
    }
    if (await _clearLegacyChildSessionIfNeeded(sessionToken)) {
      return null;
    }

    final childId = await _secureStorage.getChildSession();
    if (childId == null) {
      return null;
    }

    final data = await _authApi.validateChildSession(
      sessionToken: sessionToken,
    );
    if (data['success'] != true) {
      await _secureStorage.clearAuthOnly();
      return null;
    }

    final resolvedChildId =
        data['child_id']?.toString().trim().isNotEmpty == true
            ? data['child_id'].toString()
            : childId;
    return _buildChildUser(
      childId: resolvedChildId,
      childName: _extractChildName(data),
    );
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

  /// Logout current user (clears auth tokens only, preserves local profiles/preferences)
  Future<bool> logout() async {
    try {
      _logger.d('Logging out user');
      final role = await _secureStorage.getUserRole();
      final authToken = await _secureStorage.getAuthToken();

      if (_shouldNotifyBackendOnLogout(role: role, authToken: authToken)) {
        try {
          await _authApi.logout();
        } on DioException catch (e) {
          _logger.w(
            'Parent logout API failed: ${e.response?.statusCode} ${e.message}',
          );
        } catch (e) {
          _logger.w('Parent logout API failed: $e');
        }
      }

      await _secureStorage.clearParentPinVerification();
      await _secureStorage.clearAuthOnly();

      const hiveBoxNames = [
        'child_profiles',
        'activities',
        'progress_records',
        'gamification_data',
        'mood_entries',
      ];
      for (final boxName in hiveBoxNames) {
        try {
          await Hive.box(boxName).clear();
        } catch (e) {
          _logger.d('Error clearing Hive box "$boxName" during logout: $e');
        }
      }

      _ref.invalidate(childSessionControllerProvider);
      _ref.invalidate(gamificationStateProvider);
      _ref.invalidate(moodNotifierProvider);

      _logger.d('Logout successful');
      return true;
    } catch (e) {
      _logger.e('Logout error: $e');
      return false;
    }
  }

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

  Future<bool?> getPremiumStatus() async {
    try {
      if (kReleaseMode) {
        _logger.w('Blocked local premium status read in release mode.');
        return null;
      }
      return await _secureStorage.getIsPremium();
    } catch (e) {
      _logger.e('Error getting premium status: $e');
      return null;
    }
  }

  Future<bool> savePremiumStatus(bool isPremium) async {
    try {
      if (kReleaseMode) {
        _logger.w('Blocked local premium status write in release mode.');
        return false;
      }
      return await _secureStorage.saveIsPremium(isPremium);
    } catch (e) {
      _logger.e('Error saving premium status: $e');
      return false;
    }
  }

  Future<String?> getPlanType() async {
    try {
      if (kReleaseMode) {
        _logger.w('Blocked local plan type read in release mode.');
        return null;
      }
      return await _secureStorage.getPlanType();
    } catch (e) {
      _logger.e('Error getting plan type: $e');
      return null;
    }
  }

  Future<bool> savePlanType(String planType) async {
    try {
      if (kReleaseMode) {
        _logger.w('Blocked local plan type write in release mode.');
        return false;
      }
      return await _secureStorage.savePlanType(planType);
    } catch (e) {
      _logger.e('Error saving plan type: $e');
      return false;
    }
  }

  /// Refresh authentication token
  Future<String?> refreshToken() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return null;

      final data = await _authApi.refresh(refreshToken: refreshToken);
      final newToken = data['access_token'];
      if (newToken is String && newToken.isNotEmpty) {
        await _secureStorage.saveAuthToken(newToken);
        final role = await _secureStorage.getUserRole();
        if (role == UserRoles.parent) {
          await _secureStorage.saveParentAccessToken(newToken);
        }
        return newToken;
      }

      return null;
    } on DioException catch (e) {
      _logger.e(
        'Error refreshing token: ${e.response?.statusCode} - ${e.response?.data}',
      );
      return null;
    } catch (e) {
      _logger.e('Error refreshing token: $e');
      return null;
    }
  }

  /// Validate authentication token
  Future<bool> validateToken() async {
    try {
      final role = await _secureStorage.getUserRole();
      final token = await _secureStorage.getAuthToken();

      if (token == null || token.isEmpty) return false;
      if (await _clearLegacyChildSessionIfNeeded(token)) {
        return false;
      }
      if (isChildSessionToken(token)) {
        final data = await _authApi.validateChildSession(sessionToken: token);
        return data['success'] == true;
      }

      if (role == UserRoles.parent) {
        try {
          final data = await _authApi.me();
          return _userFromJson(data['user']) != null;
        } on DioException catch (e) {
          if (e.response?.statusCode == 401) {
            final refreshedToken = await refreshToken();
            if (refreshedToken == null || refreshedToken.isEmpty) {
              return false;
            }
            final retryData = await _authApi.me();
            return _userFromJson(retryData['user']) != null;
          }
          rethrow;
        }
      }

      return !_tokenLooksExpired(token);
    } catch (e) {
      _logger.e('Error validating token: $e');
      return false;
    }
  }
}
