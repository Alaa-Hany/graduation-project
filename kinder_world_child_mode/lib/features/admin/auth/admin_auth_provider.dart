import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/api/api_providers.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/models/admin_user.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_repository.dart';

// ─────────────────────────── State ───────────────────────────────────────────

enum AdminAuthStatus { initial, loading, authenticated, unauthenticated, error }

class AdminAuthState {
  final AdminAuthStatus status;
  final AdminUser? admin;
  final String? errorMessage;
  final bool requiresTwoFactor;
  final String? twoFactorMethod;
  final bool canBootstrap;

  const AdminAuthState({
    this.status = AdminAuthStatus.initial,
    this.admin,
    this.errorMessage,
    this.requiresTwoFactor = false,
    this.twoFactorMethod,
    this.canBootstrap = false,
  });

  bool get isAuthenticated =>
      status == AdminAuthStatus.authenticated && admin != null;
  bool get isLoading => status == AdminAuthStatus.loading;

  AdminAuthState copyWith({
    AdminAuthStatus? status,
    AdminUser? admin,
    String? errorMessage,
    bool clearAdmin = false,
    bool clearError = false,
    bool? requiresTwoFactor,
    bool clearTwoFactor = false,
    String? twoFactorMethod,
    bool? canBootstrap,
  }) {
    return AdminAuthState(
      status: status ?? this.status,
      admin: clearAdmin ? null : (admin ?? this.admin),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      requiresTwoFactor: clearTwoFactor
          ? false
          : (requiresTwoFactor ?? this.requiresTwoFactor),
      twoFactorMethod:
          clearTwoFactor ? null : (twoFactorMethod ?? this.twoFactorMethod),
      canBootstrap: canBootstrap ?? this.canBootstrap,
    );
  }

  @override
  String toString() =>
      'AdminAuthState(status: $status, admin: ${admin?.email}, error: $errorMessage)';
}

// ─────────────────────────── Repository provider ─────────────────────────────

final adminAuthRepositoryProvider = Provider<AdminAuthRepository>((ref) {
  final adminApi = ref.watch(adminApiProvider);
  final storage = ref.watch(secureStorageProvider);
  return AdminAuthRepository(adminApi: adminApi, storage: storage);
});

// ─────────────────────────── Notifier ────────────────────────────────────────

class AdminAuthNotifier extends StateNotifier<AdminAuthState> {
  final AdminAuthRepository _repo;
  final AppNavigationController _navigationController;

  AdminAuthNotifier(this._repo, this._navigationController)
      : super(const AdminAuthState()) {
    _restoreSession();
  }

  /// Attempt to restore a persisted admin session on app start.
  Future<void> _restoreSession() async {
    state = state.copyWith(status: AdminAuthStatus.loading);
    try {
      final canBootstrap = await _repo.canBootstrap();
      final admin = await _repo.restoreSession();
      if (admin != null) {
        state = AdminAuthState(
          status: AdminAuthStatus.authenticated,
          admin: admin,
          canBootstrap: canBootstrap,
        );
      } else {
        state = AdminAuthState(
          status: AdminAuthStatus.unauthenticated,
          canBootstrap: canBootstrap,
        );
      }
    } catch (_) {
      state = const AdminAuthState(status: AdminAuthStatus.unauthenticated);
    }
  }

  /// Login with email + password.
  Future<bool> login({
    required String email,
    required String password,
    String? twoFactorCode,
  }) async {
    state = state.copyWith(
      status: AdminAuthStatus.loading,
      clearError: true,
      clearTwoFactor: true,
    );

    final result = await _repo.login(
      email: email,
      password: password,
      twoFactorCode: twoFactorCode,
    );

    if (result.success && result.admin != null) {
      state = AdminAuthState(
        status: AdminAuthStatus.authenticated,
        admin: result.admin,
        canBootstrap: false,
      );
      return true;
    } else {
      state = AdminAuthState(
        status: AdminAuthStatus.unauthenticated,
        errorMessage: result.error,
        requiresTwoFactor: result.requiresTwoFactor,
        twoFactorMethod: result.twoFactorMethod,
        canBootstrap: state.canBootstrap,
      );
      return false;
    }
  }

  Future<bool> bootstrap({
    required String email,
    required String password,
    String? name,
  }) async {
    state = state.copyWith(
      status: AdminAuthStatus.loading,
      clearError: true,
      clearTwoFactor: true,
    );

    final result = await _repo.bootstrap(
      email: email,
      password: password,
      name: name,
    );

    if (result.success && result.admin != null) {
      state = AdminAuthState(
        status: AdminAuthStatus.authenticated,
        admin: result.admin,
        canBootstrap: false,
      );
      return true;
    }

    final canBootstrap = await _repo.canBootstrap();
    state = AdminAuthState(
      status: AdminAuthStatus.unauthenticated,
      errorMessage: result.error,
      canBootstrap: canBootstrap,
    );
    return false;
  }

  /// Logout — clears local session and calls backend.
  Future<void> logout() async {
    state = state.copyWith(status: AdminAuthStatus.loading);
    await _repo.logout();
    _navigationController.clearHistory(seedLocation: '/admin/login');
    final canBootstrap = await _repo.canBootstrap();
    state = AdminAuthState(
      status: AdminAuthStatus.unauthenticated,
      canBootstrap: canBootstrap,
    );
  }

  /// Refresh the access token silently.
  Future<bool> refreshToken() async {
    final result = await _repo.refreshToken();
    if (!result.success) {
      // Refresh failed — force re-login
      state = AdminAuthState(
        status: AdminAuthStatus.unauthenticated,
        errorMessage: result.error,
      );
      return false;
    }
    return true;
  }

  /// Re-fetch admin profile from server and update state.
  Future<void> refreshProfile() async {
    final result = await _repo.getMe();
    if (result.success && result.admin != null) {
      state = state.copyWith(admin: result.admin);
    } else if (result.error != null) {
      final refreshed = await _repo.refreshToken();
      if (refreshed.success) {
        final retry = await _repo.getMe();
        if (retry.success && retry.admin != null) {
          state = state.copyWith(admin: retry.admin);
          return;
        }
      }
      state = AdminAuthState(
        status: AdminAuthStatus.unauthenticated,
        errorMessage: result.error,
        canBootstrap: state.canBootstrap,
      );
    }
  }

  /// Clear any error message without changing auth status.
  void clearError() {
    state = state.copyWith(clearError: true, clearTwoFactor: true);
  }

  /// Check if the current admin has a specific permission.
  bool hasPermission(String permission) {
    return state.admin?.hasPermission(permission) ?? false;
  }

  /// Check if the current admin has a specific role.
  bool hasRole(String role) {
    return state.admin?.hasRole(role) ?? false;
  }
}

// ─────────────────────────── Provider ────────────────────────────────────────

final adminAuthProvider =
    StateNotifierProvider<AdminAuthNotifier, AdminAuthState>((ref) {
  final repo = ref.watch(adminAuthRepositoryProvider);
  final navigationController = ref.watch(appNavigationControllerProvider);
  return AdminAuthNotifier(repo, navigationController);
});

/// Convenience provider — returns the current AdminUser or null.
final currentAdminProvider = Provider<AdminUser?>((ref) {
  return ref.watch(adminAuthProvider).admin;
});

/// Convenience provider — true when admin is authenticated.
final isAdminAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(adminAuthProvider).isAuthenticated;
});
