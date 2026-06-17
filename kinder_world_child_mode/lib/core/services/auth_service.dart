import 'package:kinder_world/core/api/auth_api.dart';
import 'package:kinder_world/core/repositories/auth_repository.dart';
import 'package:kinder_world/core/models/user.dart';
import 'package:logger/logger.dart';

/// Service wrapper for authentication operations
class AuthService {
  final AuthRepository _repository;
  final AuthApi _authApi;
  final Logger _logger;

  AuthService({
    required AuthRepository repository,
    required AuthApi authApi,
    required Logger logger,
  })  : _repository = repository,
        _authApi = authApi,
        _logger = logger;

  /// Get current user
  Future<User?> getMe() async {
    return await _repository.getMe();
  }

  /// Update parent profile
  Future<bool> updateProfile({required String name}) async {
    try {
      final response = await _authApi.updateProfile(name: name);
      final success = response.isNotEmpty;
      if (success) {
        _logger.d('Profile updated successfully');
      }
      return success;
    } catch (e) {
      _logger.e('Error updating profile: $e');
      return false;
    }
  }

  /// Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await _authApi.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      final success = response['success'] == true;
      if (success) {
        _logger.d('Password changed successfully');
      }
      return success;
    } catch (e) {
      _logger.e('Error changing password: $e');
      return false;
    }
  }

  // Delegate repository methods
  Future<User?> loginParent({
    required String email,
    required String password,
    String? twoFactorCode,
  }) async {
    return await _repository.loginParent(
      email: email,
      password: password,
      twoFactorCode: twoFactorCode,
    );
  }

  Future<PendingParentVerification?> registerParent({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    return await _repository.registerParent(
      name: name,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
    );
  }

  Future<User?> verifyParentEmailOtp({
    required String email,
    required String otp,
  }) async {
    return await _repository.verifyParentEmailOtp(email: email, otp: otp);
  }

  Future<PendingParentVerification?> resendParentEmailOtp({
    required String email,
  }) async {
    return await _repository.resendParentEmailOtp(email: email);
  }

  Future<bool> logout() async {
    return await _repository.logout();
  }

  Future<String?> getUserRole() async {
    return await _repository.getUserRole();
  }
}
