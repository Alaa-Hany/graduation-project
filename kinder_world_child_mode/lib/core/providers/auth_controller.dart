import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/models/user.dart';
import 'package:kinder_world/core/repositories/auth_repository.dart';
import 'package:kinder_world/core/services/auth_service.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';
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

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    Object? error = _sentinel,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
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
  static const String _premiumEmail = 'w@w.w';

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
    
    _logger.d('Auth initialized: authenticated=$isAuthenticated, user=${user?.id}');
  }

  // ==================== PARENT AUTHENTICATION ====================

  /// Login parent with email and password
  Future<bool> loginParent({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final user = await _authRepository.loginParent(
        email: normalizedEmail,
        password: password,
      );
      
      if (user != null) {
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
        );
        await _applyPremiumOverride(normalizedEmail);
        _logger.d('Parent login successful: ${user.id}');
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid email or password',
        );
        return false;
      }
    } on ParentAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      return false;
    } catch (e) {
      _logger.e('Parent login error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Login failed. Please try again.',
      );
      return false;
    }
  }

  /// Register new parent account
  Future<bool> registerParent({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final user = await _authRepository.registerParent(
        name: name,
        email: normalizedEmail,
        password: password,
        confirmPassword: confirmPassword,
      );
      
      if (user != null) {
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
        );
        await _applyPremiumOverride(normalizedEmail);
        _logger.d('Parent registration successful: ${user.id}');
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Registration failed. Please check your information.',
        );
        return false;
      }
    } on ParentAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      return false;
    } catch (e) {
      _logger.e('Parent registration error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed. Please try again.',
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
          error: 'child_login_failed',
        );
        return false;
      }
    } on ChildLoginException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _childLoginErrorForStatus(e.statusCode),
      );
      return false;
    } catch (e) {
      _logger.e('Child login error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'child_login_failed',
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
        error: 'child_register_failed',
      );
      return null;
    } on ChildRegisterException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ??
            _childRegisterErrorForStatus(e.statusCode, e.detailCode),
      );
      return null;
    } catch (e) {
      _logger.e('Child register error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'child_register_failed',
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
      );
      
      _logger.d('User logged out successfully');
    } catch (e) {
      _logger.e('Error during logout: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Logout failed',
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
      state = state.copyWith(user: user);
    } catch (e) {
      _logger.e('Error refreshing user: $e');
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  String _childLoginErrorForStatus(int? statusCode) {
    switch (statusCode) {
      case 401:
        return 'child_login_401';
      case 404:
        return 'child_login_404';
      case 422:
        return 'child_login_422';
      default:
        return 'child_login_failed';
    }
  }

  String _childRegisterErrorForStatus(int? statusCode, String? detailCode) {
    if (statusCode == 402 && detailCode == 'CHILD_LIMIT_REACHED') {
      return 'child_register_limit';
    }
    switch (statusCode) {
      case 401:
        return 'child_register_401';
      case 404:
        return 'child_register_404';
      case 422:
        return 'child_register_422';
      default:
        return 'child_register_failed';
    }
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

  Future<void> setPremiumStatus(bool isPremium) async {
    await _authRepository.savePremiumStatus(isPremium);
    final existingPlanType = await _authRepository.getPlanType();
    if (!(isPremium && existingPlanType == 'family_plus')) {
      await _authRepository.savePlanType(isPremium ? 'premium' : 'free');
    }
    final user = state.user;
    if (user == null) return;
    state = state.copyWith(
      user: user.copyWith(
        subscriptionStatus:
            isPremium ? SubscriptionStatus.active : SubscriptionStatus.expired,
      ),
    );
  }

  Future<void> applyPlanSelection(PlanTier tier) async {
    switch (tier) {
      case PlanTier.free:
        await setPremiumStatus(false);
        break;
      case PlanTier.premium:
        await setPremiumStatus(true);
        break;
      case PlanTier.familyPlus:
        await _authRepository.savePlanType('family_plus');
        await setPremiumStatus(true);
        break;
    }
  }

  Future<void> _applyPremiumOverride(String email) async {
    final normalized = email.trim().toLowerCase();
    await setPremiumStatus(normalized == _premiumEmail);
  }
}

// ==================== PROVIDERS ====================

/// Main auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final networkService = ref.watch(networkServiceProvider);
  final logger = ref.watch(loggerProvider);
  
  return AuthRepository(
    secureStorage: secureStorage,
    networkService: networkService,
    logger: logger,
  );
});

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final networkService = ref.watch(networkServiceProvider);
  final logger = ref.watch(loggerProvider);
  
  return AuthService(
    repository: authRepository,
    networkService: networkService,
    logger: logger,
  );
});

/// Main auth controller provider - SINGLE SOURCE OF TRUTH
/// Not autoDispose: auth state must persist across navigation to avoid re-initialization.
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
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
