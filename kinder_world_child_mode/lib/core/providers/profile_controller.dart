import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/services/auth_service.dart';
import 'package:logger/logger.dart';
import 'package:kinder_world/app.dart';

// Profile update controller
final profileControllerProvider =
    StateNotifierProvider.autoDispose<ProfileController, AsyncValue<void>>(
  (ref) {
    final authService = ref.watch(authServiceProvider);
    final logger = ref.watch(loggerProvider);
    return ProfileController(
      authService: authService,
      logger: logger,
      ref: ref,
    );
  },
);

class ProfileController extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;
  final Logger _logger;
  final Ref _ref;

  ProfileController({
    required AuthService authService,
    required Logger logger,
    required Ref ref,
  })  : _authService = authService,
        _logger = logger,
        _ref = ref,
        super(const AsyncValue.data(null));

  Future<bool> updateProfile({required String name}) async {
    if (name.trim().isEmpty) {
      state = AsyncValue.error('Name cannot be empty', StackTrace.current);
      return false;
    }

    if (name.trim().length < 2) {
      state = AsyncValue.error(
          'Name must be at least 2 characters', StackTrace.current);
      return false;
    }

    state = const AsyncValue.loading();

    try {
      final success = await _authService.updateProfile(name: name.trim());

      if (success) {
        // Invalidate the me provider to refresh user data
        _ref.invalidate(meProvider);
        await _ref.read(authControllerProvider.notifier).refreshUser();
        state = const AsyncValue.data(null);
        return true;
      } else {
        state = AsyncValue.error(
          'Failed to update profile',
          StackTrace.current,
        );
        return false;
      }
    } catch (e, st) {
      _logger.e('Error updating profile: $e', stackTrace: st);
      state = AsyncValue.error(
        'An error occurred while updating profile',
        st,
      );
      return false;
    }
  }
}
