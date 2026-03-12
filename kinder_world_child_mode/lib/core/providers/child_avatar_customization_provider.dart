import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/models/child_avatar_customization.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:kinder_world/core/services/child_avatar_customization_service.dart';

final childAvatarCustomizationServiceProvider =
    Provider<ChildAvatarCustomizationService>((ref) {
  return ChildAvatarCustomizationService(
    sharedPreferences: ref.watch(sharedPreferencesProvider),
    logger: ref.watch(loggerProvider),
  );
});

class ChildAvatarCustomizationNotifier
    extends StateNotifier<AsyncValue<ChildAvatarCustomization>> {
  ChildAvatarCustomizationNotifier({
    required ChildAvatarCustomizationService service,
    required String childId,
  })  : _service = service,
        _childId = childId,
        super(const AsyncValue.loading()) {
    load();
  }

  final ChildAvatarCustomizationService _service;
  final String _childId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _service.load(_childId));
  }

  Future<bool> save(ChildAvatarCustomization customization) async {
    state = AsyncValue.data(customization);
    final success = await _service.save(_childId, customization);
    if (!success) {
      await load();
    }
    return success;
  }
}

final childAvatarCustomizationProvider = StateNotifierProvider.autoDispose
    .family<ChildAvatarCustomizationNotifier,
        AsyncValue<ChildAvatarCustomization>, String>((
  ref,
  childId,
) {
  return ChildAvatarCustomizationNotifier(
    service: ref.watch(childAvatarCustomizationServiceProvider),
    childId: childId,
  );
});

final childAvatarCustomizationResolvedProvider = Provider.autoDispose
    .family<ChildAvatarCustomization, String>((ref, childId) {
  return ref.watch(childAvatarCustomizationProvider(childId)).maybeWhen(
        data: (value) => value,
        orElse: ChildAvatarCustomization.defaults,
      );
});
