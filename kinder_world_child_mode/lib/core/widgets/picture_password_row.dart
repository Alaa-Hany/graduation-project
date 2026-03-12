import 'package:flutter/material.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';

class PicturePasswordOption {
  final String id;
  final IconData icon;
  final String semanticColor;

  const PicturePasswordOption({
    required this.id,
    required this.icon,
    required this.semanticColor,
  });

  @Deprecated('Use semanticColor with _resolveSemanticColor(BuildContext).')
  Color get color => _legacySemanticColor(semanticColor);
}

const List<PicturePasswordOption> picturePasswordOptions = [
  PicturePasswordOption(
    id: 'apple',
    icon: Icons.eco,
    semanticColor: 'success',
  ),
  PicturePasswordOption(
    id: 'ball',
    icon: Icons.sports_soccer,
    semanticColor: 'info',
  ),
  PicturePasswordOption(
    id: 'cat',
    icon: Icons.pets,
    semanticColor: 'primary',
  ),
  PicturePasswordOption(
    id: 'dog',
    icon: Icons.emoji_nature,
    semanticColor: 'warning',
  ),
  PicturePasswordOption(
    id: 'elephant',
    icon: Icons.park,
    semanticColor: 'secondary',
  ),
  PicturePasswordOption(
    id: 'fish',
    icon: Icons.set_meal,
    semanticColor: 'fun',
  ),
  PicturePasswordOption(
    id: 'guitar',
    icon: Icons.music_note,
    semanticColor: 'skill',
  ),
  PicturePasswordOption(
    id: 'house',
    icon: Icons.home,
    semanticColor: 'learning',
  ),
  PicturePasswordOption(
    id: 'icecream',
    icon: Icons.cake,
    semanticColor: 'kindness',
  ),
  PicturePasswordOption(
    id: 'jelly',
    icon: Icons.emoji_food_beverage,
    semanticColor: 'streak',
  ),
  PicturePasswordOption(
    id: 'kite',
    icon: Icons.toys,
    semanticColor: 'parent',
  ),
  PicturePasswordOption(
    id: 'lion',
    icon: Icons.face,
    semanticColor: 'xp',
  ),
];

final Map<String, PicturePasswordOption> picturePasswordOptionsById = {
  for (final option in picturePasswordOptions) option.id: option,
};

Color _legacySemanticColor(String semanticColor) {
  switch (semanticColor) {
    case 'success':
      return const Color(0xFF22C55E);
    case 'info':
      return const Color(0xFF0EA5E9);
    case 'primary':
      return const Color(0xFF4F46E5);
    case 'warning':
      return const Color(0xFFF59E0B);
    case 'secondary':
      return const Color(0xFF14B8A6);
    case 'fun':
      return const Color(0xFF06B6D4);
    case 'skill':
      return const Color(0xFF8B5CF6);
    case 'learning':
      return const Color(0xFF3B82F6);
    case 'kindness':
      return const Color(0xFFEC4899);
    case 'streak':
      return const Color(0xFFF97316);
    case 'parent':
      return const Color(0xFF16A34A);
    case 'xp':
      return const Color(0xFFF4C542);
    default:
      return const Color(0xFF64748B);
  }
}

Color resolvePicturePasswordColor(
  BuildContext context,
  PicturePasswordOption option,
) {
  return _resolvePicturePasswordSemanticColor(context, option.semanticColor) ??
      _legacySemanticColor(option.semanticColor);
}

Color? _resolvePicturePasswordSemanticColor(
  BuildContext context,
  String? semanticColor,
) {
  if (semanticColor == null) return null;
  final colors = context.colors;
  final child = context.childTheme;
  final parent = context.parentTheme;
  switch (semanticColor) {
    case 'success':
      return context.successColor;
    case 'info':
      return context.infoColor;
    case 'primary':
      return colors.primary;
    case 'warning':
      return context.warningColor;
    case 'secondary':
      return colors.secondary;
    case 'fun':
      return child.fun;
    case 'skill':
      return child.skill;
    case 'learning':
      return child.learning;
    case 'kindness':
      return child.kindness;
    case 'streak':
      return child.streak;
    case 'parent':
      return parent.primary;
    case 'xp':
      return child.xp;
    default:
      return null;
  }
}

class PicturePasswordRow extends StatelessWidget {
  const PicturePasswordRow({
    super.key,
    required this.picturePassword,
    this.size = 18,
    this.color,
    this.showPlaceholders = true,
    this.useOptionColor = true,
  });

  final List<String> picturePassword;
  final double size;
  final Color? color;
  final bool showPlaceholders;
  final bool useOptionColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallbackColor = color ?? colors.primary;
    final slots = showPlaceholders
        ? List<String?>.generate(
            3,
            (i) => i < picturePassword.length ? picturePassword[i] : null,
          )
        : picturePassword.take(3).map<String?>((id) => id).toList();

    if (slots.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: slots
          .map((slot) => _buildSlot(context, slot, fallbackColor, colors))
          .toList(),
    );
  }

  Widget _buildSlot(
    BuildContext context,
    String? id,
    Color fallbackColor,
    ColorScheme colors,
  ) {
    final option = id == null ? null : picturePasswordOptionsById[id];
    final resolvedColor = useOptionColor
        ? _resolveSemanticColor(context, option?.semanticColor) ?? fallbackColor
        : fallbackColor;
    final borderColor = resolvedColor.withValues(alpha: 0.6);
    final fillColor = id == null
        ? colors.surfaceContainerHighest.withValues(alpha: 0.5)
        : resolvedColor.withValues(alpha: 0.15);
    final iconColor = resolvedColor;

    final icon = option?.icon;
    final fallback = id == null || id.isEmpty ? '?' : id[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: id == null
          ? const SizedBox.shrink()
          : Center(
              child: icon != null
                  ? Icon(icon, size: size * 0.6, color: iconColor)
                  : Text(
                      fallback,
                      style: TextStyle(
                        fontSize: size * 0.55,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
            ),
    );
  }

  Color? _resolveSemanticColor(BuildContext context, String? semanticColor) {
    return _resolvePicturePasswordSemanticColor(context, semanticColor);
  }
}
