import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/child_avatar_customization.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/services/child_avatar_customization_service.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

ChildProfile _child({
  int level = 1,
  int streak = 0,
  int activitiesCompleted = 0,
}) {
  return ChildProfile(
    id: 'child-1',
    name: 'Dana',
    age: 8,
    avatar: 'assets/images/avatars/av1.png',
    interests: const ['math'],
    level: level,
    xp: 120,
    streak: streak,
    favorites: const [],
    parentId: 'parent-1',
    parentEmail: 'parent@example.com',
    picturePassword: const ['cat', 'dog', 'apple'],
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 2),
    totalTimeSpent: 30,
    activitiesCompleted: activitiesCompleted,
    avatarPath: 'assets/images/avatars/av1.png',
  );
}

void main() {
  test('save and load customization from shared preferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final service = ChildAvatarCustomizationService(
      sharedPreferences: prefs,
      logger: Logger(),
    );

    const customization = ChildAvatarCustomization(
      avatarPath: 'assets/images/avatars/girl2.png',
      frameColorId: ChildAvatarFrameCatalog.grapeColorId,
      frameStyleId: ChildAvatarFrameCatalog.glowStyleId,
    );

    final saved = await service.save('child-1', customization);
    final loaded = await service.load('child-1');

    expect(saved, isTrue);
    expect(loaded.avatarPath, customization.avatarPath);
    expect(loaded.frameColorId, customization.frameColorId);
    expect(loaded.frameStyleId, customization.frameStyleId);
  });

  test('frame unlock rules use child progress thresholds', () {
    final beginner = _child(level: 1, streak: 1, activitiesCompleted: 1);
    final streakChild = _child(level: 2, streak: 3, activitiesCompleted: 1);
    final activeChild = _child(level: 2, streak: 1, activitiesCompleted: 5);
    final advancedChild = _child(level: 5, streak: 7, activitiesCompleted: 10);

    expect(
      ChildAvatarFrameCatalog.styleForId(ChildAvatarFrameCatalog.classicStyleId)
          .unlockRule
          .isUnlockedFor(beginner),
      isTrue,
    );
    expect(
      ChildAvatarFrameCatalog.styleForId(ChildAvatarFrameCatalog.glowStyleId)
          .unlockRule
          .isUnlockedFor(streakChild),
      isTrue,
    );
    expect(
      ChildAvatarFrameCatalog.styleForId(ChildAvatarFrameCatalog.starsStyleId)
          .unlockRule
          .isUnlockedFor(activeChild),
      isTrue,
    );
    expect(
      ChildAvatarFrameCatalog.styleForId(ChildAvatarFrameCatalog.shieldStyleId)
          .unlockRule
          .isUnlockedFor(advancedChild),
      isTrue,
    );
  });
}
