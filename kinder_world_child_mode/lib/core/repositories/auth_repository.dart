import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/api/auth_api.dart';
import 'package:kinder_world/core/messages/app_messages.dart';
import 'package:kinder_world/core/models/user.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/gamification_provider.dart';
import 'package:kinder_world/core/providers/mood_provider.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/core/utils/session_token_utils.dart';
import 'package:logger/logger.dart';

part 'auth_repository_support.dart';
part 'auth_repository_state.dart';
part 'auth_repository_parent.dart';
part 'auth_repository_child.dart';

class ChildLoginException implements Exception {
  final int? statusCode;
  final String? detailCode;

  const ChildLoginException({this.statusCode, this.detailCode});
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
  final bool requiresTwoFactor;
  final String? twoFactorMethod;
  final bool requiresEmailVerification;
  final String? pendingEmail;
  final DateTime? otpExpiresAt;
  final DateTime? resendAvailableAt;

  const ParentAuthException({
    required this.message,
    this.statusCode,
    this.requiresTwoFactor = false,
    this.twoFactorMethod,
    this.requiresEmailVerification = false,
    this.pendingEmail,
    this.otpExpiresAt,
    this.resendAvailableAt,
  });
}

class PendingParentVerification {
  final String email;
  final String? message;
  final DateTime? otpExpiresAt;
  final DateTime? resendAvailableAt;

  const PendingParentVerification({
    required this.email,
    this.message,
    this.otpExpiresAt,
    this.resendAvailableAt,
  });
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
class AuthRepository
    with
        _AuthRepositorySupportMixin,
        _AuthRepositoryStateMixin,
        _AuthRepositoryParentMixin,
        _AuthRepositoryChildMixin {
  @override
  final SecureStorage _secureStorage;
  @override
  final AuthApi _authApi;
  @override
  final Logger _logger;
  @override
  final Ref _ref;

  AuthRepository({
    required SecureStorage secureStorage,
    required AuthApi authApi,
    required Logger logger,
    required Ref ref,
  })  : _secureStorage = secureStorage,
        _authApi = authApi,
        _logger = logger,
        _ref = ref;
}
