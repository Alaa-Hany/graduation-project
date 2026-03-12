import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/child_avatar_customization.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/theme/app_theme.dart';
import 'package:kinder_world/core/theme/theme_palette.dart';
import 'package:kinder_world/core/widgets/avatar_view.dart';
import 'package:kinder_world/core/widgets/child_customizable_avatar.dart';

ChildProfile _child() {
  return ChildProfile(
    id: 'child-1',
    name: 'Dana',
    age: 8,
    avatar: 'assets/images/avatars/av1.png',
    interests: const ['math'],
    level: 5,
    xp: 200,
    streak: 4,
    favorites: const [],
    parentId: 'parent-1',
    parentEmail: 'parent@example.com',
    picturePassword: const ['cat', 'dog', 'apple'],
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 2),
    totalTimeSpent: 30,
    activitiesCompleted: 7,
    avatarPath: 'assets/images/avatars/av1.png',
  );
}

void main() {
  testWidgets('renders star accents for stars frame style', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(palette: ThemePalettes.defaultPalette),
        home: Scaffold(
          body: Center(
            child: ChildAvatarFrame(
              child: _child(),
              customization: const ChildAvatarCustomization(
                avatarPath: 'assets/images/avatars/av2.png',
                frameColorId: ChildAvatarFrameCatalog.sunsetColorId,
                frameStyleId: ChildAvatarFrameCatalog.starsStyleId,
              ),
              radius: 30,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AvatarView), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsNWidgets(3));
  });
}
