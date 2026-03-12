import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/repositories/auth_repository.dart';
import 'package:logger/logger.dart';

enum ParentPinFlowMode {
  auto,
  verify,
  setup,
  change,
}

class ParentPinState {
  final bool hasPin;
  final bool isVerified;
  final bool isLoading;
  final bool isLocked;
  final int failedAttempts;
  final DateTime? lockedUntil;
  final String? error;
  final String? successMessage;

  const ParentPinState({
    this.hasPin = false,
    this.isVerified = false,
    this.isLoading = false,
    this.isLocked = false,
    this.failedAttempts = 0,
    this.lockedUntil,
    this.error,
    this.successMessage,
  });

  ParentPinState copyWith({
    bool? hasPin,
    bool? isVerified,
    bool? isLoading,
    bool? isLocked,
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
    String? error,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return ParentPinState(
      hasPin: hasPin ?? this.hasPin,
      isVerified: isVerified ?? this.isVerified,
      isLoading: isLoading ?? this.isLoading,
      isLocked: isLocked ?? this.isLocked,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class ParentPinNotifier extends StateNotifier<ParentPinState> {
  ParentPinNotifier({
    required AuthRepository authRepository,
    required Logger logger,
  })  : _authRepository = authRepository,
        _logger = logger,
        super(const ParentPinState()) {
    refreshStatus();
  }

  final AuthRepository _authRepository;
  final Logger _logger;

  Future<void> refreshStatus() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final status = await _authRepository.getParentPinStatus();
      final isVerified = await _authRepository.isParentPinVerified();
      state = state.copyWith(
        isLoading: false,
        hasPin: status.hasPin,
        isLocked: status.isLocked,
        failedAttempts: status.failedAttempts,
        lockedUntil: status.lockedUntil,
        isVerified: status.hasPin ? isVerified : false,
        clearError: true,
      );
    } catch (e) {
      _logger.e('Error refreshing parent PIN status: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load PIN status',
      );
    }
  }

  Future<bool> setPin({
    required String pin,
    required String confirmPin,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _authRepository.setParentPin(pin, confirmPin);
    if (result.success) {
      await refreshStatus();
      state = state.copyWith(
        isVerified: true,
        successMessage: result.message,
      );
      return true;
    }

    state = state.copyWith(
      isLoading: false,
      error: result.error,
    );
    return false;
  }

  Future<bool> verifyPin(String pin) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _authRepository.verifyParentPin(pin);
    if (result.success) {
      await refreshStatus();
      state = state.copyWith(
        isVerified: true,
        successMessage: result.message,
        clearError: true,
      );
      return true;
    }

    await refreshStatus();
    state = state.copyWith(
      isLoading: false,
      isVerified: false,
      error: result.error,
      lockedUntil: result.lockedUntil ?? state.lockedUntil,
      isLocked: result.lockedUntil != null || state.isLocked,
    );
    return false;
  }

  Future<bool> changePin({
    required String currentPin,
    required String newPin,
    required String confirmPin,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _authRepository.changeParentPin(
      currentPin: currentPin,
      newPin: newPin,
      confirmPin: confirmPin,
    );
    if (result.success) {
      await refreshStatus();
      state = state.copyWith(
        isVerified: true,
        successMessage: result.message,
      );
      return true;
    }

    state = state.copyWith(
      isLoading: false,
      error: result.error,
    );
    return false;
  }

  Future<bool> requestReset({String? note}) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _authRepository.requestParentPinReset(note: note);
    state = state.copyWith(
      isLoading: false,
      successMessage: result.success ? result.message : null,
      error: result.success ? null : result.error,
    );
    return result.success;
  }

  Future<void> clearVerification() async {
    await _authRepository.clearParentPinVerification();
    state = state.copyWith(isVerified: false);
  }

  ParentPinFlowMode resolveMode(ParentPinFlowMode preferredMode) {
    if (preferredMode == ParentPinFlowMode.change) {
      return state.hasPin ? ParentPinFlowMode.change : ParentPinFlowMode.setup;
    }
    if (preferredMode == ParentPinFlowMode.auto) {
      return state.hasPin ? ParentPinFlowMode.verify : ParentPinFlowMode.setup;
    }
    if (preferredMode == ParentPinFlowMode.verify && !state.hasPin) {
      return ParentPinFlowMode.setup;
    }
    return preferredMode;
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final parentPinProvider =
    StateNotifierProvider<ParentPinNotifier, ParentPinState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  return ParentPinNotifier(
    authRepository: authRepository,
    logger: logger,
  );
});
