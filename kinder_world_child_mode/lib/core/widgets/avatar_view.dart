import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';

/// Unified avatar display widget that handles both avatar paths and avatar IDs
/// Maps avatar_1, avatar_2, avatar_3, avatar_4 to their corresponding icons
class AvatarView extends StatelessWidget {
  final String? avatarPath; // Direct asset path (e.g., 'assets/images/avatars/boy_01.png')
  final String? avatarId; // Avatar ID (e.g., 'avatar_1', 'avatar_2')
  final double radius;
  final BoxFit fit;
  final Color? backgroundColor;
  final String fallbackAsset;

  static const Map<String, String> _legacyAvatarMap = {
    // Legacy paths - maps old storage format to new format
    'assets/avatars/kids/boy_01.png': 'assets/images/avatars/boy1.png',
    'assets/avatars/kids/boy_02.png': 'assets/images/avatars/boy2.png',
    'assets/avatars/kids/girl_01.png': 'assets/images/avatars/girl1.png',
    'assets/avatars/kids/girl_02.png': 'assets/images/avatars/girl2.png',
    'assets/avatars/kids/neutral_01.png': 'assets/images/avatars/av1.png',
    // Direct mappings for consistency - no conversion needed
    'assets/images/avatars/boy1.png': 'assets/images/avatars/boy1.png',
    'assets/images/avatars/boy2.png': 'assets/images/avatars/boy2.png',
    'assets/images/avatars/boy3.png': 'assets/images/avatars/boy3.png',
    'assets/images/avatars/boy4.png': 'assets/images/avatars/boy4.png',
    'assets/images/avatars/girl1.png': 'assets/images/avatars/girl1.png',
    'assets/images/avatars/girl2.png': 'assets/images/avatars/girl2.png',
    'assets/images/avatars/girl3.png': 'assets/images/avatars/girl3.png',
    'assets/images/avatars/girl4.png': 'assets/images/avatars/girl4.png',
    'assets/images/avatars/av1.png': 'assets/images/avatars/av1.png',
    'assets/images/avatars/av2.png': 'assets/images/avatars/av2.png',
    'assets/images/avatars/av3.png': 'assets/images/avatars/av3.png',
    'assets/images/avatars/av4.png': 'assets/images/avatars/av4.png',
    'assets/images/avatars/av5.png': 'assets/images/avatars/av5.png',
    'assets/images/avatars/av6.png': 'assets/images/avatars/av6.png',
    // Avatar IDs for compatibility
    'avatar_1': 'assets/images/avatars/boy1.png',
    'avatar_2': 'assets/images/avatars/boy2.png',
    'avatar_3': 'assets/images/avatars/boy3.png',
    'avatar_4': 'assets/images/avatars/boy4.png',
    'avatar_5': 'assets/images/avatars/girl1.png',
    'avatar_6': 'assets/images/avatars/girl2.png',
    'avatar_7': 'assets/images/avatars/girl3.png',
    'avatar_8': 'assets/images/avatars/girl4.png',
    'avatar_9': 'assets/images/avatars/av1.png',
    'avatar_10': 'assets/images/avatars/av2.png',
    'avatar_11': 'assets/images/avatars/av3.png',
    'avatar_12': 'assets/images/avatars/av4.png',
    'avatar_13': 'assets/images/avatars/av5.png',
    'avatar_14': 'assets/images/avatars/av6.png',
    'avatar_neutral': 'assets/images/avatars/av1.png',
  };

  const AvatarView({
    this.avatarPath,
    this.avatarId,
    this.radius = 24,
    this.fit = BoxFit.cover,
    this.backgroundColor,
    this.fallbackAsset = AppConstants.defaultChildAvatar,
    super.key,
  });

  /// Get icon data from avatarId
  _AvatarIconData? _resolveIconData(BuildContext context) {
    if (avatarId == null) return null;
    final colors = context.colors;
    final child = context.childTheme;
    final parent = context.parentTheme;
    final palette = <String, _AvatarIconData>{
      'avatar_1': _AvatarIconData(
        icon: Icons.face,
        backgroundColor: child.learning.subtle(0.14),
        iconColor: child.learning,
      ),
      'avatar_2': _AvatarIconData(
        icon: Icons.sentiment_satisfied_alt,
        backgroundColor: parent.reward.subtle(0.16),
        iconColor: parent.reward,
      ),
      'avatar_3': _AvatarIconData(
        icon: Icons.emoji_emotions,
        backgroundColor: child.skill.subtle(0.14),
        iconColor: child.skill,
      ),
      'avatar_4': _AvatarIconData(
        icon: Icons.mood,
        backgroundColor: child.success.subtle(0.14),
        iconColor: child.success,
      ),
      'avatar_5': _AvatarIconData(
        icon: Icons.star,
        backgroundColor: child.xp.subtle(0.18),
        iconColor: parent.warning,
      ),
      'avatar_6': _AvatarIconData(
        icon: Icons.pets,
        backgroundColor: colors.tertiaryContainer,
        iconColor: colors.tertiary,
      ),
      'avatar_7': _AvatarIconData(
        icon: Icons.favorite,
        backgroundColor: child.kindness.subtle(0.14),
        iconColor: child.kindness,
      ),
      'avatar_8': _AvatarIconData(
        icon: Icons.rocket_launch,
        backgroundColor: child.fun.subtle(0.14),
        iconColor: child.fun,
      ),
      'avatar_neutral': _AvatarIconData(
        icon: Icons.account_circle,
        backgroundColor: colors.surfaceContainerHighest,
        iconColor: colors.onSurfaceVariant,
      ),
    };
    if (_legacyAvatarMap.containsKey(avatarId)) {
      return null;
    }
    return palette[avatarId];
  }

  /// Get asset path from either avatarPath or avatarId (legacy support)
  String? _resolvePath() {
    if (avatarPath != null && avatarPath!.isNotEmpty) {
      return _normalizeAssetPath(avatarPath!);
    }
    if (avatarId != null && avatarId!.isNotEmpty) {
      return _normalizeAssetPath(avatarId!);
    }
    return null;
  }

  String _normalizeAssetPath(String path) {
    return _legacyAvatarMap[path] ?? path;
  }

  bool _isNetworkImage(String path) {
    final uri = Uri.tryParse(path);
    return uri != null && uri.hasAbsolutePath &&
        (path.startsWith('http://') || path.startsWith('https://'));
  }

  @override
  Widget build(BuildContext context) {
    // First try to get icon data (new approach)
    final iconData = _resolveIconData(context);
    if (iconData != null) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: backgroundColor ?? iconData.backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          iconData.icon,
          size: radius * 1.2,
          color: iconData.iconColor,
        ),
      );
    }

    // Fallback to image path (legacy support)
    final resolvedPath = _resolvePath();
    final fallbackImage = fallbackAsset;
    
    if (resolvedPath != null && _isNetworkImage(resolvedPath)) {
      return CachedNetworkImage(
        imageUrl: resolvedPath,
        imageBuilder: (context, provider) => CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? Colors.transparent,
          backgroundImage: provider,
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? Colors.transparent,
          backgroundImage: AssetImage(fallbackImage),
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? Colors.transparent,
          backgroundImage: AssetImage(fallbackImage),
        ),
      );
    }

    final assetPath = resolvedPath ?? fallbackImage;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.transparent,
      backgroundImage: AssetImage(assetPath),
    );
  }
}

class _AvatarIconData {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  const _AvatarIconData({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });
}
