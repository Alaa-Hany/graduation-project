import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

// Parent PIN State
class ParentPinState {
  final String? pin;
  final bool isRequired;
  final bool isVerified;
  final bool isLoading;
  final String? error;

  const ParentPinState({
    this.pin,
    this.isRequired = false,
    this.isVerified = false,
    this.isLoading = false,
    this.error,
  });

  ParentPinState copyWith({
    String? pin,
    bool? isRequired,
    bool? isVerified,
    bool? isLoading,
    String? error,
  }) {
    return ParentPinState(
      pin: pin ?? this.pin,
      isRequired: isRequired ?? this.isRequired,
      isVerified: isVerified ?? this.isVerified,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Parent PIN Provider
class ParentPinNotifier extends StateNotifier<ParentPinState> {
  final SecureStorage _secureStorage;
  final Logger _logger;

  ParentPinNotifier({
    required SecureStorage secureStorage,
    required Logger logger,
  })  : _secureStorage = secureStorage,
        _logger = logger,
        super(const ParentPinState()) {
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    try {
      final pin = await _secureStorage.getParentPin();
      
      state = state.copyWith(
        pin: pin,
        isRequired: pin != null,
        isVerified: false,
      );
      
      _logger.d('Parent PIN state loaded');
    } catch (e) {
      _logger.e('Error loading parent PIN state: $e');
      state = state.copyWith(error: 'Failed to load PIN state');
    }
  }

  Future<bool> setParentPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Validate PIN
      if (pin.length < 4) {
        state = state.copyWith(
          isLoading: false,
          error: 'PIN must be at least 4 characters',
        );
        return false;
      }
      
      await _secureStorage.saveParentPin(pin);
      
      state = ParentPinState(
        pin: pin,
        isRequired: true,
        isVerified: false,
        isLoading: false,
      );
      
      _logger.d('Parent PIN set successfully');
      return true;
    } catch (e) {
      _logger.e('Error setting parent PIN: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to set PIN',
      );
      return false;
    }
  }

  Future<bool> verifyPin(String enteredPin) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final storedPin = await _secureStorage.getParentPin();
      final isValid = storedPin != null && storedPin == enteredPin;
      
      if (isValid) {
        state = state.copyWith(
          isVerified: true,
          isLoading: false,
        );
        _logger.d('Parent PIN verified successfully');
      } else {
        state = state.copyWith(
          isVerified: false,
          isLoading: false,
          error: 'Incorrect PIN',
        );
        _logger.w('Parent PIN verification failed');
      }
      
      return isValid;
    } catch (e) {
      _logger.e('Error verifying PIN: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to verify PIN',
      );
      return false;
    }
  }

  Future<void> clearPin() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _secureStorage.deleteParentPin();
      
      state = const ParentPinState(
        pin: null,
        isRequired: false,
        isVerified: false,
        isLoading: false,
      );
      
      _logger.d('Parent PIN cleared');
    } catch (e) {
      _logger.e('Error clearing PIN: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to clear PIN',
      );
    }
  }

  void requirePinVerification() {
    state = state.copyWith(isRequired: true, isVerified: false);
  }

  void markAsVerified() {
    state = state.copyWith(isVerified: true);
  }

  void clearVerification() {
    state = state.copyWith(isVerified: false);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider
final parentPinProvider = StateNotifierProvider.autoDispose<ParentPinNotifier, ParentPinState>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final logger = ref.watch(loggerProvider);
  
  return ParentPinNotifier(
    secureStorage: secureStorage,
    logger: logger,
  );
});

// Helper providers
final isPinRequiredProvider = Provider<bool>((ref) {
  return ref.watch(parentPinProvider).isRequired;
});

final isPinVerifiedProvider = Provider<bool>((ref) {
  return ref.watch(parentPinProvider).isVerified;
});