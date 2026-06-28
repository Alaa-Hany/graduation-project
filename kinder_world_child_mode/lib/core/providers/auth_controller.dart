import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/api/api_providers.dart';
import 'package:kinder_world/core/messages/app_messages.dart';
import 'package:kinder_world/core/models/user.dart';
import 'package:kinder_world/core/repositories/auth_repository.dart';
import 'package:kinder_world/core/services/auth_service.dart';
import 'package:kinder_world/app.dart';
import 'package:logger/logger.dart';

// ==================== AUTH STATE ====================

/// Authentication state
class AuthState {
  static const Object _sentinel = Object();
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final bool requiresTwoFactor;
  final String? twoFactorMethod;
  final bool requiresEmailVerification;
  final String? pendingVerificationEmail;
  final DateTime? otpExpiresAt;
  final DateTime? resendAvailableAt;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.requiresTwoFactor = false,
    this.twoFactorMethod,
    this.requiresEmailVerification = false,
    this.pendingVerificationEmail,
    this.otpExpiresAt,
    this.resendAvailableAt,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    Object? error = _sentinel,
    bool? isAuthenticated,
    bool? requiresTwoFactor,
    Object? twoFactorMethod = _sentinel,
    bool? requiresEmailVerification,
    Object? pendingVerificationEmail = _sentinel,
    Object? otpExpiresAt = _sentinel,
    Object? resendAvailableAt = _sentinel,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      requiresTwoFactor: requiresTwoFactor ?? this.requiresTwoFactor,
      twoFactorMethod: identical(twoFactorMethod, _sentinel)
          ? this.twoFactorMethod
          : twoFactorMethod as String?,
      requiresEmailVerification:
          requiresEmailVerification ?? this.requiresEmailVerification,
      pendingVerificationEmail: identical(pendingVerificationEmail, _sentinel)
          ? this.pendingVerificationEmail
          : pendingVerificationEmail as String?,
      otpExpiresAt: identical(otpExpiresAt, _sentinel)
          ? this.otpExpiresAt
          : otpExpiresAt as DateTime?,
      resendAvailableAt: identical(resendAvailableAt, _sentinel)
          ? this.resendAvailableAt
          : resendAvailableAt as DateTime?,
    );
  }

  bool get isParent => user?.role == UserRoles.parent;
  bool get isChild => user?.role == UserRoles.child;
}

// ==================== AUTH CONTROLLER ====================

/// Authentication controller - SINGLE SOURCE OF TRUTH
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final Logger _logger;
  final AppNavigationController _navigationController;

  AuthController({
    required AuthRepository authRepository,
    required Logger logger,
    required AppNavigationController navigationController,
  })  : _authRepository = authRepository,
        _logger = logger,
        _navigationController = navigationController,
        super(const AuthState()) {
    _initialize();
  }

  /// Initialize authentication state
  Future<void> _initialize() async {
    _logger.d('Initializing auth controller');
    await _authRepository.clearParentPinVerification();

    final storedIsAuthenticated = await _authRepository.isAuthenticated();
    final user = await _authRepository.getCurrentUser();
    final isAuthenticated = user != null && storedIsAuthenticated;

    state = state.copyWith(
      isAuthenticated: isAuthenticated,
      user: user,
    );

    _logger.d(
        'Auth initialized: authenticated=$isAuthenticated, user=${user?.id}');
  }

  // ==================== PARENT AUTHENTICATION ====================

  /// Login parent with email and password
  Future<bool> loginParent({
    required String email,
    required String password,
    String? twoFactorCode,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      requiresTwoFactor: false,
      twoFactorMethod: null,
      requiresEmailVerification: false,
      pendingVerificationEmail: null,
      otpExpiresAt: null,
      resendAvailableAt: null,
    );

    try {
      final user = await _authRepository.loginParent(
        email: email.trim().toLowerCase(),
        password: password,
        twoFactorCode: twoFactorCode,
      );

      if (user != null) {
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
          requiresTwoFactor: false,
          twoFactorMethod: null,
        );
        _logger.d('Parent login successful: ${user.id}');
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: AuthUiMessages.invalidEmailOrPassword,
          requiresTwoFactor: false,
          twoFactorMethod: null,
        );
        return false;
      }
    } on ParentAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _formatParentAuthError(e),
        requiresTwoFactor: e.requiresTwoFactor,
        twoFactorMethod: e.twoFactorMethod,
        requiresEmailVerification: e.requiresEmailVerification,
        pendingVerificationEmail: e.pendingEmail,
        resendAvailableAt: e.resendAvailableAt,
      );
      return false;
    } catch (e) {
      _logger.e('Parent login error: $e');
      state = state.copyWith(
        isLoading: false,
        error: AuthUiMessages.loginFailedTryAgain,
        requiresTwoFactor: false,
        twoFactorMethod: null,
      );
      return false;
    }
  }

  /// Register new parent account
  Future<PendingParentVerification?> registerParent({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      requiresEmailVerification: false,
      pendingVerificationEmail: null,
      otpExpiresAt: null,
      resendAvailableAt: null,
    );

    try {
      final pending = await _authRepository.registerParent(
        name: name,
        email: email.trim().toLowerCase(),
        password: password,
        confirmPassword: confirmPassword,
      );

      if (pending != null) {
        state = state.copyWith(
          isLoading: false,
          requiresEmailVerification: true,
          pendingVerificationEmail: pending.email,
          otpExpiresAt: pending.otpExpiresAt,
          resendAvailableAt: pending.resendAvailableAt,
          error: pending.message ?? AuthUiMessages.verificationCodeSent,
        );
        _logger.d('Parent registration pending verification: ${pending.email}');
        return pending;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: AuthUiMessages.registrationFailedCheckInfo,
        );
        return null;
      }
    } on ParentAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _formatParentAuthError(e),
        requiresEmailVerification: e.requiresEmailVerification,
        pendingVerificationEmail: e.pendingEmail,
        otpExpiresAt: e.otpExpiresAt,
        resendAvailableAt: e.resendAvailableAt,
      );
      return null;
    } catch (e) {
      _logger.e('Parent registration error: $e');
      state = state.copyWith(
        isLoading: false,
        error: AuthUiMessages.registrationFailedTryAgain,
      );
      return null;
    }
  }

  Future<bool> verifyParentEmailOtp({
    required String email,
    required String otp,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await _authRepository.verifyParentEmailOtp(
        email: email.trim().toLowerCase(),
        otp: otp.trim(),
      );

      if (user != null) {
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
          requiresEmailVerification: false,
          pendingVerificationEmail: null,
          otpExpiresAt: null,
          resendAvailableAt: null,
        );
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: AuthUiMessages.verificationCodeInvalid,
      );
      return false;
    } on ParentAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _formatParentAuthError(e),
        requiresEmailVerification: true,
        pendingVerificationEmail: e.pendingEmail ?? email.trim().toLowerCase(),
        otpExpiresAt: e.otpExpiresAt,
        resendAvailableAt: e.resendAvailableAt,
      );
      return false;
    } catch (e) {
      _logger.e('Parent OTP verification error: $e');
      state = state.copyWith(
        isLoading: false,
        error: AuthUiMessages.verificationCodeInvalid,
      );
      return false;
    }
  }

  Future<bool> resendParentEmailOtp({required String email}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final pending = await _authRepository.resendParentEmailOtp(
        email: email.trim().toLowerCase(),
      );
      state = state.copyWith(
        isLoading: false,
        requiresEmailVerification: true,
        pendingVerificationEmail: pending?.email ?? email.trim().toLowerCase(),
        otpExpiresAt: pending?.otpExpiresAt,
        resendAvailableAt: pending?.resendAvailableAt,
        error: pending?.message ?? AuthUiMessages.verificationCodeResent,
      );
      return true;
    } on ParentAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _formatParentAuthError(e),
        requiresEmailVerification: true,
        pendingVerificationEmail: e.pendingEmail ?? email.trim().toLowerCase(),
        otpExpiresAt: e.otpExpiresAt,
        resendAvailableAt: e.resendAvailableAt,
      );
      return false;
    } catch (e) {
      _logger.e('Parent OTP resend error: $e');
      state = state.copyWith(
        isLoading: false,
        error: AuthUiMessages.registrationFailedTryAgain,
      );
      return false;
    }
  }

  // ==================== CHILD AUTHENTICATION ====================

  /// Login child with picture password
  Future<bool> loginChild({
    required String childId,
    required String childName,
    required List<String> picturePassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await _authRepository.loginChild(
        childId: childId,
        childName: childName,
        picturePassword: picturePassword,
      );

      if (user != null) {
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
        );

        _logger.d('Child login successful: ${user.id}');
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: AuthUiMessages.childLoginFailed,
        );
        return false;
      }
    } on ChildLoginException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _childLoginErrorForStatus(e.statusCode, e.detailCode),
      );
      return false;
    } catch (e) {
      _logger.e('Child login error: $e');
      state = state.copyWith(
        isLoading: false,
        error: AuthUiMessages.childLoginFailed,
      );
      return false;
    }
  }

  /// Register child account
  Future<ChildRegisterResponse?> registerChild({
    required String name,
    required List<String> picturePassword,
    required String parentEmail,
    required int age,
    String? avatar,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _authRepository.registerChild(
        name: name,
        picturePassword: picturePassword,
        parentEmail: parentEmail,
        age: age,
        avatar: avatar,
      );

      if (response != null) {
        state = state.copyWith(
          isLoading: false,
        );
        return response;
      }

      state = state.copyWith(
        isLoading: false,
        error: AuthUiMessages.childRegisterFailed,
      );
      return null;
    } on ChildRegisterException catch (e) {
      // Map known backend statuses to specific UI codes FIRST so the screen can
      // surface the real cause (not signed in as parent / email mismatch /
      // parent not found / limit reached). Preferring e.message here would
      // collapse every distinct failure into the generic "register failed"
      // message, which is exactly what hid the real cause before.
      state = state.copyWith(
        isLoading: false,
        error: _childRegisterErrorForStatus(e.statusCode, e.detailCode) ??
            e.message ??
            AuthUiMessages.childRegisterFailed,
      );
      return null;
    } catch (e) {
      _logger.e('Child register error: $e');
      state = state.copyWith(
        isLoading: false,
        error: AuthUiMessages.childRegisterFailed,
      );
      return null;
    }
  }

  // ==================== LOGOUT ====================

  /// Logout current user
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      await _authRepository.logout();
      _navigationController.clearHistory(seedLocation: '/select-user-type');

      state = const AuthState(
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,
        requiresEmailVerification: false,
        pendingVerificationEmail: null,
        otpExpiresAt: null,
        resendAvailableAt: null,
      );

      _logger.d('User logged out successfully');
    } catch (e) {
      _logger.e('Error during logout: $e');
      state = state.copyWith(
        isLoading: false,
        error: AuthUiMessages.logoutFailed,
      );
    }
  }

  // ==================== PARENT PIN ====================

  /// Set parent PIN
  Future<bool> setParentPin(String pin) async {
    try {
      final result = await _authRepository.setParentPin(pin, pin);
      return result.success;
    } catch (e) {
      _logger.e('Error setting parent PIN: $e');
      return false;
    }
  }

  /// Verify parent PIN
  Future<bool> verifyParentPin(String enteredPin) async {
    try {
      final result = await _authRepository.verifyParentPin(enteredPin);
      return result.success;
    } catch (e) {
      _logger.e('Error verifying PIN: $e');
      return false;
    }
  }

  /// Check if PIN is required
  Future<bool> isPinRequired() async {
    try {
      return await _authRepository.isPinRequired();
    } catch (e) {
      _logger.e('Error checking PIN requirement: $e');
      return false;
    }
  }

  // ==================== UTILITIES ====================

  /// Refresh user data
  Future<void> refreshUser() async {
    try {
      final user = await _authRepository.getCurrentUser();
      state = state.copyWith(
        user: user,
        isAuthenticated: user != null,
      );
    } catch (e) {
      _logger.e('Error refreshing user: $e');
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(
      error: null,
      requiresTwoFactor: false,
      twoFactorMethod: null,
      requiresEmailVerification: false,
    );
  }

  String _childLoginErrorForStatus(int? statusCode, [String? detailCode]) {
    switch (statusCode) {
      case 401:
        if (detailCode == 'CHILD_INVALID_NAME') {
          return 'child_login_invalid_name';
        }
        return 'child_login_401';
      case 404:
        return 'child_login_404';
      case 422:
        return 'child_login_422';
      default:
        return AuthUiMessages.childLoginFailed;
    }
  }

  String? _childRegisterErrorForStatus(int? statusCode, String? detailCode) {
    if (statusCode == 402 && detailCode == 'CHILD_LIMIT_REACHED') {
      return 'child_register_limit';
    }
    switch (statusCode) {
      case 401:
      case 403:
        return 'child_register_401';
      case 404:
        return 'child_register_404';
      case 422:
        return 'child_register_422';
      default:
        // Unknown/unexpected status: let the caller fall back to the raw
        // backend message (or the generic failure text) instead of forcing a
        // misleading specific code.
        return null;
    }
  }

  String _formatParentAuthError(ParentAuthException e) {
    final message = e.message.trim();
    final statusCode = e.statusCode;
    return AuthUiMessages.formatStatusMessage(
      statusCode: statusCode,
      message: message,
    );
  }

  /// Validate token
  Future<bool> validateToken() async {
    try {
      return await _authRepository.validateToken();
    } catch (e) {
      _logger.e('Error validating token: $e');
      return false;
    }
  }
}

// ==================== PROVIDERS ====================

/// Main auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final authApi = ref.watch(authApiProvider);
  final logger = ref.watch(loggerProvider);

  return AuthRepository(
    secureStorage: secureStorage,
    authApi: authApi,
    logger: logger,
    ref: ref,
  );
});

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final authApi = ref.watch(authApiProvider);
  final logger = ref.watch(loggerProvider);

  return AuthService(
    repository: authRepository,
    authApi: authApi,
    logger: logger,
  );
});

/// Main auth controller provider - SINGLE SOURCE OF TRUTH
/// Not autoDispose: auth state must persist across navigation to avoid re-initialization.
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  final navigationController = ref.watch(appNavigationControllerProvider);

  return AuthController(
    authRepository: authRepository,
    logger: logger,
    navigationController: navigationController,
  );
});

// ==================== HELPER PROVIDERS ====================

/// Check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).isAuthenticated;
});

/// Get current user
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authControllerProvider).user;
});

/// Get current authenticated user - fetches fresh data from API
final meProvider = FutureProvider.autoDispose<User?>((ref) async {
  final authRepository = ref.watch(authRepositoryProvider);
  return await authRepository.getMe();
});

/// Check if current user is parent
final isParentProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).isParent;
});

/// Check if current user is child
final isChildProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).isChild;
});

/// Get user role
final userRoleProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider).user?.role;
});

/// Get auth loading state
final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).isLoading;
});

/// Get auth error
final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider).error;
});
