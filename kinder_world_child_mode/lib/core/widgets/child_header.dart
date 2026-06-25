import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/widgets/child_customizable_avatar.dart';

class ChildHeader extends ConsumerWidget {
  final bool compact;
  final EdgeInsetsGeometry padding;
  final Color? avatarBackground;
  final ChildProfile? child;

  const ChildHeader({
    super.key,
    this.compact = false,
    this.padding = const EdgeInsets.only(bottom: 16),
    this.avatarBackground,
    this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedChild = child ?? ref.watch(currentChildProvider);
    final l10n = AppLocalizations.of(context)!;
    final name = (resolvedChild?.name.isNotEmpty ?? false)
        ? resolvedChild!.name
        : (resolvedChild?.id ?? l10n.friendFallback);
    final level = resolvedChild?.level ?? 1;
    final theme = Theme.of(context);

    // Several child screens hardcode a light pastel Scaffold background that
    // does not follow the dark theme. Resolve the header text color from the
    // actual background the header sits on (its Scaffold) instead of the global
    // theme, so the text stays readable on those screens in dark mode while
    // still following the theme on screens that have no explicit background.
    final scaffoldBackground = Scaffold.maybeOf(context)?.widget.backgroundColor ??
        theme.scaffoldBackgroundColor;
    final isOnDarkBackground =
        ThemeData.estimateBrightnessForColor(scaffoldBackground) ==
            Brightness.dark;
    final titleColor = isOnDarkBackground ? Colors.white : Colors.black87;
    final subtitleColor = isOnDarkBackground ? Colors.white70 : Colors.black54;

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: compact ? AppConstants.fontSize : AppConstants.largeFontSize,
      fontWeight: FontWeight.bold,
      color: titleColor,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: compact ? 12 : 14,
      color: subtitleColor,
      fontWeight: FontWeight.w600,
    );
    final avatarRadius = compact ? 20.0 : 28.0;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (resolvedChild != null)
            ChildCustomizableAvatar(
              child: resolvedChild,
              radius: avatarRadius,
              backgroundColor:
                  avatarBackground ?? theme.colorScheme.surfaceContainerHighest,
            )
          else
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor:
                  avatarBackground ?? theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.face_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.helloName(name), style: titleStyle),
              const SizedBox(height: 2),
              Text(l10n.levelLabel(level), style: subtitleStyle),
            ],
          ),
        ],
      ),
    );
  }
}
