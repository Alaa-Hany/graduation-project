part of 'auth_repository.dart';

mixin _AuthRepositoryParentMixin on _AuthRepositorySupportMixin {
  /// Login parent with email and password
  Future<User?> loginParent({
    required String email,
    required String password,
    String? twoFactorCode,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      _logger.d('Attempting parent login for: $normalizedEmail');

      if (normalizedEmail.isEmpty || password.isEmpty) {
        _logger.w('Login failed: Empty credentials');
        return null;
      }

      final payload = await _authApi.login(
        email: normalizedEmail,
        password: password,
        twoFactorCode: twoFactorCode,
      );
      final data = payload.raw;
      if (data.isEmpty) {
        _logger.e('Login failed: empty response');
        return null;
      }

      final user =
          await _persistAuthFromResponse(Map<String, dynamic>.from(data));
      if (user == null) {
        _logger.e('Login failed: invalid user data');
        return null;
      }

      _logger.d('Parent login successful: ${user.id}');
      return user;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final resolvedMessage = _isParentTwoFactorRequired(e)
          ? (_extractErrorMessage(e) ?? AuthUiMessages.twoFactorCodeRequired)
          : _isParentInvalidTwoFactorCode(e)
              ? (_extractErrorMessage(e) ?? AuthUiMessages.invalidTwoFactorCode)
              : (_extractErrorMessage(e) ?? AuthUiMessages.loginFailedTryAgain);
      _logger.e(
        'Parent login error: status=$statusCode message=$resolvedMessage body=${e.response?.data}',
      );
      throw ParentAuthException(
        message: resolvedMessage,
        statusCode: statusCode,
        requiresTwoFactor: _isParentTwoFactorRequired(e),
        twoFactorMethod: _extractTwoFactorMethod(e),
      );
    } catch (e) {
      _logger.e('Parent login error: $e');
      return null;
    }
  }

  /// Register new parent account
  Future<PendingParentVerification?> registerParent({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      _logger.d('Attempting parent registration for: $normalizedEmail');

      if (password != confirmPassword) {
        _logger.w('Registration failed: Passwords do not match');
        throw const ParentAuthException(
          message: AuthUiMessages.passwordsDoNotMatch,
          statusCode: 400,
        );
      }

      if (password.length < 8) {
        _logger.w('Registration failed: Password too short');
        throw const ParentAuthException(
          message: AuthUiMessages.passwordMinLength,
          statusCode: 422,
        );
      }

      final payload = await _authApi.register(
        name: name,
        email: normalizedEmail,
        password: password,
        confirmPassword: confirmPassword,
      );
      if (!payload.success || payload.email.isEmpty) {
        _logger.e('Registration failed: empty response');
        throw const ParentAuthException(
          message: AuthUiMessages.registrationFailedEmptyServerResponse,
        );
      }

      _logger.d('Parent registration pending verification: ${payload.email}');
      return PendingParentVerification(
        email: payload.email,
        message: payload.message,
        otpExpiresAt: payload.otpExpiresAt,
        resendAvailableAt: payload.resendAvailableAt,
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final resolvedMessage =
          _extractErrorMessage(e) ?? AuthUiMessages.registrationFailedTryAgain;
      _logger.e(
        'Parent registration error: status=$statusCode message=$resolvedMessage body=${e.response?.data}',
      );
      throw ParentAuthException(
        message: resolvedMessage,
        statusCode: statusCode,
        requiresEmailVerification: _isParentEmailVerificationRequired(e),
        pendingEmail: _extractErrorDetailMap(e)?['email']?.toString(),
        resendAvailableAt: _extractResendAvailableAt(e),
      );
    } on ParentAuthException {
      rethrow;
    } catch (e) {
      _logger.e('Parent registration error: $e');
      return null;
    }
  }

  Future<User?> verifyParentEmailOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final payload = await _authApi.verifyEmailOtp(email: email, otp: otp);
      final user = await _persistAuthFromResponse(
          Map<String, dynamic>.from(payload.raw));
      if (user == null) {
        throw const ParentAuthException(
          message: AuthUiMessages.registrationFailedInvalidUserData,
        );
      }
      return user;
    } on DioException catch (e) {
      throw ParentAuthException(
        message:
            _extractErrorMessage(e) ?? AuthUiMessages.verificationCodeInvalid,
        statusCode: e.response?.statusCode,
        requiresEmailVerification: true,
        pendingEmail: email.trim().toLowerCase(),
        resendAvailableAt: _extractResendAvailableAt(e),
      );
    }
  }

  Future<PendingParentVerification?> resendParentEmailOtp({
    required String email,
  }) async {
    try {
      final payload = await _authApi.resendEmailOtp(email: email);
      return PendingParentVerification(
        email: payload.email,
        message: payload.message,
        otpExpiresAt: payload.otpExpiresAt,
        resendAvailableAt: payload.resendAvailableAt,
      );
    } on DioException catch (e) {
      throw ParentAuthException(
        message: _extractErrorMessage(e) ??
            (_isOtpResendCooldown(e)
                ? AuthUiMessages.verificationCodeCooldown
                : AuthUiMessages.registrationFailedTryAgain),
        statusCode: e.response?.statusCode,
        requiresEmailVerification: true,
        pendingEmail: email.trim().toLowerCase(),
        resendAvailableAt: _extractResendAvailableAt(e),
      );
    }
  }

  Future<ParentPinStatus> getParentPinStatus() async {
    final role = await _secureStorage.getUserRole();
    final authToken = _secureStorage.hasCachedAuthToken
        ? _secureStorage.cachedAuthToken
        : await _secureStorage.getAuthToken();
    final hasUsableParentSession =
        role == UserRoles.parent && _isUsableParentToken(authToken);

    if (!hasUsableParentSession) {
      _logger.d(
        'Skipping parent PIN status request: no authenticated parent session',
      );
      return _emptyParentPinStatus();
    }

    try {
      final data = await _authApi.parentPinStatus();

      return ParentPinStatus(
        hasPin: data['has_pin'] == true,
        isLocked: data['is_locked'] == true,
        failedAttempts: (data['failed_attempts'] as num?)?.toInt() ?? 0,
        lockedUntil: data['locked_until'] is String
            ? DateTime.tryParse(data['locked_until'] as String)
            : null,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _logger.w(
          'Parent PIN status request returned 401; clearing parent PIN verification state',
        );
        await _secureStorage.clearParentPinVerification();
      } else {
        _logger.e('Error getting parent PIN status: $e');
      }
      return _emptyParentPinStatus();
    } catch (e) {
      _logger.e('Error getting parent PIN status: $e');
      return _emptyParentPinStatus();
    }
  }

  Future<ParentPinActionResult> setParentPin(
    String pin,
    String confirmPin,
  ) async {
    try {
      final response = await _authApi.parentPinSet(
        pin: pin,
        confirmPin: confirmPin,
      );
      await _secureStorage.saveParentPinVerified(true);
      return ParentPinActionResult(
        success: response['success'] == true,
        message: response['message']?.toString(),
      );
    } on DioException catch (e) {
      return ParentPinActionResult(
        success: false,
        error: _extractErrorMessage(e) ?? AuthUiMessages.failedToSetPin,
      );
    } catch (e) {
      _logger.e('Error setting parent PIN: $e');
      return const ParentPinActionResult(
        success: false,
        error: AuthUiMessages.failedToSetPin,
      );
    }
  }

  Future<ParentPinActionResult> verifyParentPin(String enteredPin) async {
    try {
      final response = await _authApi.parentPinVerify(pin: enteredPin);
      await _secureStorage.saveParentPinVerified(true);
      return ParentPinActionResult(
        success: response['success'] == true,
        message: response['message']?.toString(),
      );
    } on DioException catch (e) {
      final lockedUntil = _extractLockedUntil(e);
      await _secureStorage.saveParentPinVerified(false);
      return ParentPinActionResult(
        success: false,
        error: _extractErrorMessage(e) ?? AuthUiMessages.incorrectPin,
        lockedUntil: lockedUntil,
      );
    } catch (e) {
      _logger.e('Error verifying parent PIN: $e');
      return const ParentPinActionResult(
        success: false,
        error: AuthUiMessages.failedToVerifyPin,
      );
    }
  }

  Future<ParentPinActionResult> changeParentPin({
    required String currentPin,
    required String newPin,
    required String confirmPin,
  }) async {
    try {
      final response = await _authApi.parentPinChange(
        currentPin: currentPin,
        newPin: newPin,
        confirmPin: confirmPin,
      );
      await _secureStorage.saveParentPinVerified(true);
      return ParentPinActionResult(
        success: response['success'] == true,
        message: response['message']?.toString(),
      );
    } on DioException catch (e) {
      return ParentPinActionResult(
        success: false,
        error: _extractErrorMessage(e) ?? AuthUiMessages.failedToChangePin,
      );
    } catch (e) {
      _logger.e('Error changing parent PIN: $e');
      return const ParentPinActionResult(
        success: false,
        error: AuthUiMessages.failedToChangePin,
      );
    }
  }

  Future<ParentPinActionResult> requestParentPinReset({String? note}) async {
    try {
      final response = await _authApi.parentPinResetRequest(note: note);
      return ParentPinActionResult(
        success: response['success'] == true,
        message: response['message']?.toString(),
      );
    } on DioException catch (e) {
      return ParentPinActionResult(
        success: false,
        error:
            _extractErrorMessage(e) ?? AuthUiMessages.failedToRequestPinReset,
      );
    } catch (e) {
      _logger.e('Error requesting parent PIN reset: $e');
      return const ParentPinActionResult(
        success: false,
        error: AuthUiMessages.failedToRequestPinReset,
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
}
