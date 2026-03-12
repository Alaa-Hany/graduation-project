import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kinder_world/core/models/child_profile.dart';

class ChildAvatarCustomization {
  const ChildAvatarCustomization({
    this.avatarPath,
    this.frameColorId = ChildAvatarFrameCatalog.skyColorId,
    this.frameStyleId = ChildAvatarFrameCatalog.classicStyleId,
  });

  final String? avatarPath;
  final String frameColorId;
  final String frameStyleId;

  ChildAvatarCustomization copyWith({
    String? avatarPath,
    bool clearAvatarPath = false,
    String? frameColorId,
    String? frameStyleId,
  }) {
    return ChildAvatarCustomization(
      avatarPath: clearAvatarPath ? null : (avatarPath ?? this.avatarPath),
      frameColorId: frameColorId ?? this.frameColorId,
      frameStyleId: frameStyleId ?? this.frameStyleId,
    );
  }

  Map<String, dynamic> toJson() => {
        'avatar_path': avatarPath,
        'frame_color_id': frameColorId,
        'frame_style_id': frameStyleId,
      };

  String encode() => jsonEncode(toJson());

  factory ChildAvatarCustomization.fromJson(Map<String, dynamic> json) {
    return ChildAvatarCustomization(
      avatarPath: json['avatar_path']?.toString(),
      frameColorId: json['frame_color_id']?.toString() ??
          ChildAvatarFrameCatalog.skyColorId,
      frameStyleId: json['frame_style_id']?.toString() ??
          ChildAvatarFrameCatalog.classicStyleId,
    );
  }

  factory ChildAvatarCustomization.decode(String source) {
    return ChildAvatarCustomization.fromJson(
      Map<String, dynamic>.from(jsonDecode(source) as Map),
    );
  }

  factory ChildAvatarCustomization.defaults() =>
      const ChildAvatarCustomization();
}

class ChildAvatarColorOption {
  const ChildAvatarColorOption({
    required this.id,
    required this.color,
  });

  final String id;
  final Color color;
}

class ChildAvatarFrameStyleOption {
  const ChildAvatarFrameStyleOption({
    required this.id,
    required this.icon,
    required this.unlockRule,
  });

  final String id;
  final IconData icon;
  final ChildAvatarUnlockRule unlockRule;
}

class ChildAvatarUnlockRule {
  const ChildAvatarUnlockRule._({
    this.level,
    this.streak,
    this.activities,
  });

  const ChildAvatarUnlockRule.always() : this._();

  const ChildAvatarUnlockRule.level(int level) : this._(level: level);

  const ChildAvatarUnlockRule.streak(int streak) : this._(streak: streak);

  const ChildAvatarUnlockRule.activities(int activities)
      : this._(activities: activities);

  final int? level;
  final int? streak;
  final int? activities;

  bool isUnlockedFor(ChildProfile child) {
    if (level != null) return child.level >= level!;
    if (streak != null) return child.streak >= streak!;
    if (activities != null) return child.activitiesCompleted >= activities!;
    return true;
  }
}

class ChildAvatarFrameCatalog {
  ChildAvatarFrameCatalog._();

  static const String skyColorId = 'sky';
  static const String mintColorId = 'mint';
  static const String sunsetColorId = 'sunset';
  static const String grapeColorId = 'grape';

  static const String classicStyleId = 'classic';
  static const String glowStyleId = 'glow';
  static const String starsStyleId = 'stars';
  static const String shieldStyleId = 'shield';

  static const colors = <ChildAvatarColorOption>[
    ChildAvatarColorOption(id: skyColorId, color: Color(0xFF4FC3F7)),
    ChildAvatarColorOption(id: mintColorId, color: Color(0xFF66BB6A)),
    ChildAvatarColorOption(id: sunsetColorId, color: Color(0xFFFF8A65)),
    ChildAvatarColorOption(id: grapeColorId, color: Color(0xFF9575CD)),
  ];

  static const styles = <ChildAvatarFrameStyleOption>[
    ChildAvatarFrameStyleOption(
      id: classicStyleId,
      icon: Icons.circle_outlined,
      unlockRule: ChildAvatarUnlockRule.always(),
    ),
    ChildAvatarFrameStyleOption(
      id: glowStyleId,
      icon: Icons.blur_on_rounded,
      unlockRule: ChildAvatarUnlockRule.streak(3),
    ),
    ChildAvatarFrameStyleOption(
      id: starsStyleId,
      icon: Icons.auto_awesome_rounded,
      unlockRule: ChildAvatarUnlockRule.activities(5),
    ),
    ChildAvatarFrameStyleOption(
      id: shieldStyleId,
      icon: Icons.shield_outlined,
      unlockRule: ChildAvatarUnlockRule.level(5),
    ),
  ];

  static Color colorForId(String id) {
    return colors
        .firstWhere(
          (option) => option.id == id,
          orElse: () => colors.first,
        )
        .color;
  }

  static ChildAvatarFrameStyleOption styleForId(String id) {
    return styles.firstWhere(
      (option) => option.id == id,
      orElse: () => styles.first,
    );
  }
}
