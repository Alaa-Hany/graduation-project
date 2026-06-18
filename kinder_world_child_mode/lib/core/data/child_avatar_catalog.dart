import 'package:flutter/material.dart';

class ChildAvatarOption {
  const ChildAvatarOption({
    required this.id,
    required this.assetPath,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.unlockLevel, // null = always unlocked
  });

  final String id;
  final String assetPath;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  /// Minimum level required to use this avatar. null = always available.
  final int? unlockLevel;

  bool isUnlockedForLevel(int level) =>
      unlockLevel == null || level >= unlockLevel!;
}

const childAvatarOptions = <ChildAvatarOption>[
  // Level 1 — always available (starter avatars)
  ChildAvatarOption(
    id: 'assets/images/avatars/boy1.png',
    assetPath: 'assets/images/avatars/boy1.png',
    icon: Icons.face,
    backgroundColor: Color(0xFFE3F2FD),
    iconColor: Color(0xFF1E88E5),
  ),
  ChildAvatarOption(
    id: 'assets/images/avatars/girl1.png',
    assetPath: 'assets/images/avatars/girl1.png',
    icon: Icons.emoji_emotions,
    backgroundColor: Color(0xFFF3E5F5),
    iconColor: Color(0xFF8E24AA),
  ),
  // Level 2
  ChildAvatarOption(
    id: 'assets/images/avatars/boy2.png',
    assetPath: 'assets/images/avatars/boy2.png',
    icon: Icons.sentiment_satisfied_alt,
    backgroundColor: Color(0xFFFFF3E0),
    iconColor: Color(0xFFFB8C00),
    unlockLevel: 2,
  ),
  ChildAvatarOption(
    id: 'assets/images/avatars/girl2.png',
    assetPath: 'assets/images/avatars/girl2.png',
    icon: Icons.mood,
    backgroundColor: Color(0xFFE8F5E9),
    iconColor: Color(0xFF43A047),
    unlockLevel: 2,
  ),
  // Level 3
  ChildAvatarOption(
    id: 'assets/images/avatars/boy3.png',
    assetPath: 'assets/images/avatars/boy3.png',
    icon: Icons.face,
    backgroundColor: Color(0xFFE1F5FE),
    iconColor: Color(0xFF0277BD),
    unlockLevel: 3,
  ),
  ChildAvatarOption(
    id: 'assets/images/avatars/girl3.png',
    assetPath: 'assets/images/avatars/girl3.png',
    icon: Icons.face_retouching_natural,
    backgroundColor: Color(0xFFFCE4EC),
    iconColor: Color(0xFFC2185B),
    unlockLevel: 3,
  ),
  // Level 4
  ChildAvatarOption(
    id: 'assets/images/avatars/boy4.png',
    assetPath: 'assets/images/avatars/boy4.png',
    icon: Icons.child_care,
    backgroundColor: Color(0xFFFFE0B2),
    iconColor: Color(0xFFF57C00),
    unlockLevel: 4,
  ),
  ChildAvatarOption(
    id: 'assets/images/avatars/girl4.png',
    assetPath: 'assets/images/avatars/girl4.png',
    icon: Icons.girl,
    backgroundColor: Color(0xFFF8BBD0),
    iconColor: Color(0xFFE91E63),
    unlockLevel: 4,
  ),
  // Level 5
  ChildAvatarOption(
    id: 'assets/images/avatars/av1.png',
    assetPath: 'assets/images/avatars/av1.png',
    icon: Icons.face_2_rounded,
    backgroundColor: Color(0xFFEDE7F6),
    iconColor: Color(0xFF7E57C2),
    unlockLevel: 5,
  ),
  ChildAvatarOption(
    id: 'assets/images/avatars/av2.png',
    assetPath: 'assets/images/avatars/av2.png',
    icon: Icons.tag_faces_rounded,
    backgroundColor: Color(0xFFE8F5E9),
    iconColor: Color(0xFF2E7D32),
    unlockLevel: 5,
  ),
  // Level 6
  ChildAvatarOption(
    id: 'assets/images/avatars/av3.png',
    assetPath: 'assets/images/avatars/av3.png',
    icon: Icons.cruelty_free_rounded,
    backgroundColor: Color(0xFFFFF3E0),
    iconColor: Color(0xFFEF6C00),
    unlockLevel: 6,
  ),
  ChildAvatarOption(
    id: 'assets/images/avatars/av4.png',
    assetPath: 'assets/images/avatars/av4.png',
    icon: Icons.auto_awesome_rounded,
    backgroundColor: Color(0xFFE1F5FE),
    iconColor: Color(0xFF0277BD),
    unlockLevel: 6,
  ),
  // Level 7
  ChildAvatarOption(
    id: 'assets/images/avatars/av5.png',
    assetPath: 'assets/images/avatars/av5.png',
    icon: Icons.pets_rounded,
    backgroundColor: Color(0xFFFCE4EC),
    iconColor: Color(0xFFAD1457),
    unlockLevel: 7,
  ),
  ChildAvatarOption(
    id: 'assets/images/avatars/av6.png',
    assetPath: 'assets/images/avatars/av6.png',
    icon: Icons.emoji_emotions_rounded,
    backgroundColor: Color(0xFFFFF8E1),
    iconColor: Color(0xFFF9A825),
    unlockLevel: 7,
  ),
];

const defaultChildAvatarId = 'assets/images/avatars/boy1.png';

ChildAvatarOption? childAvatarOptionForValue(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  for (final option in childAvatarOptions) {
    if (option.id == value || option.assetPath == value) {
      return option;
    }
  }

  return null;
}
