import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/models/admin_user.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_repository.dart';

// ─────────────────────────── State ───────────────────────────────────────────

enum AdminAuthStatus { initial, loading, authenticated, unauthenticated, error }

class AdminAuthState {
  final AdminAuthStatus status;
  final AdminUser? admin;
  final String? errorMessage;

  const AdminAuthState({
    this.status = AdminAuthStatus.initial,
    this.admin,
    this.errorMessage,
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
  }) {
    return AdminAuthState(
      status: status ?? this.status,
      admin: clearAdmin ? null : (admin ?? this.admin),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  String toString() =>
      'AdminAuthState(status: $status, admin: ${admin?.email}, error: $errorMessage)';
}

// ─────────────────────────── Repository provider ─────────────────────────────

final adminAuthRepositoryProvider = Provider<AdminAuthRepository>((ref) {
  final network = ref.watch(networkServiceProvider);
  final storage = ref.watch(secureStorageProvider);
  return AdminAuthRepository(network: network, storage: storage);
});

// ─────────────────────────── Notifier ────────────────────────────────────────

class AdminAuthNotifier extends StateNotifier<AdminAuthState> {
  final AdminAuthRepository _repo;

  AdminAuthNotifier(this._repo) : super(const AdminAuthState()) {
    _restoreSession();
  }

  /// Attempt to restore a persisted admin session on app start.
  Future<void> _restoreSession() async {
    state = state.copyWith(status: AdminAuthStatus.loading);
    try {
      final admin = await _repo.restoreSession();
      if (admin != null) {
        state = AdminAuthState(
          status: AdminAuthStatus.authenticated,
          admin: admin,
        );
      } else {
        state = const AdminAuthState(status: AdminAuthStatus.unauthenticated);
      }
    } catch (_) {
      state = const AdminAuthState(status: AdminAuthStatus.unauthenticated);
    }
  }

  /// Login with email + password.
  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(status: AdminAuthStatus.loading, clearError: true);

    final result = await _repo.login(email: email, password: password);

    if (result.success && result.admin != null) {
      state = AdminAuthState(
        status: AdminAuthStatus.authenticated,
        admin: result.admin,
      );
      return true;
    } else {
      state = AdminAuthState(
        status: AdminAuthStatus.unauthenticated,
        errorMessage: result.error,
      );
      return false;
    }
  }

  /// Logout — clears local session and calls backend.
  Future<void> logout() async {
    state = state.copyWith(status: AdminAuthStatus.loading);
    await _repo.logout();
    state = const AdminAuthState(status: AdminAuthStatus.unauthenticated);
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
      );
    }
  }

  /// Clear any error message without changing auth status.
  void clearError() {
    state = state.copyWith(clearError: true);
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
  return AdminAuthNotifier(repo);
});

/// Convenience provider — returns the current AdminUser or null.
final currentAdminProvider = Provider<AdminUser?>((ref) {
  return ref.watch(adminAuthProvider).admin;
});

/// Convenience provider — true when admin is authenticated.
final isAdminAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(adminAuthProvider).isAuthenticated;
});
