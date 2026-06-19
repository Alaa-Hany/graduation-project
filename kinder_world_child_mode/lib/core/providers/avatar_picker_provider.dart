import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/data/child_avatar_catalog.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';

/// Manages the currently selected child avatar asset path.
class AvatarPickerNotifier extends StateNotifier<String> {
  AvatarPickerNotifier([String? initial])
      : super(initial ?? AppConstants.defaultChildAvatar);

  static const List<String> availableAvatars = [
    'assets/images/avatars/boy1.png',
    'assets/images/avatars/boy2.png',
    'assets/images/avatars/boy3.png',
    'assets/images/avatars/boy4.png',
    'assets/images/avatars/girl1.png',
    'assets/images/avatars/girl2.png',
    'assets/images/avatars/girl3.png',
    'assets/images/avatars/girl4.png',
    'assets/images/avatars/av1.png',
    'assets/images/avatars/av2.png',
    'assets/images/avatars/av3.png',
    'assets/images/avatars/av4.png',
    'assets/images/avatars/av5.png',
    'assets/images/avatars/av6.png',
  ];

  void selectAvatar(String avatarPath) {
    state = avatarPath;
  }

  void selectRandomAvatar() {
    final random = Random();
    state = availableAvatars[random.nextInt(availableAvatars.length)];
  }
}

final avatarPickerProvider =
    StateNotifierProvider<AvatarPickerNotifier, String>((ref) {
  return AvatarPickerNotifier();
});

final availableAvatarsProvider = Provider<List<String>>((ref) {
  return AvatarPickerNotifier.availableAvatars;
});

/// Returns all avatar options with their unlock state for the current child.
/// Used in child profile avatar picker to show locked/unlocked state.
final childAvatarOptionsWithLockProvider =
    Provider<List<({ChildAvatarOption option, bool isUnlocked})>>((ref) {
  final child = ref.watch(currentChildProvider);
  final level = child?.level ?? 1;
  return childAvatarOptions
      .map((option) => (option: option, isUnlocked: option.isUnlockedForLevel(level)))
      .toList();
});
