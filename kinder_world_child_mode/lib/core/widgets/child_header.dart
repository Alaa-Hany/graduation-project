import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/widgets/child_customizable_avatar.dart';

class ChildHeader extends ConsumerWidget {
  final bool compact;
  final EdgeInsetsGeometry padding;
  final Color? avatarBackground;

  const ChildHeader({
    super.key,
    this.compact = false,
    this.padding = const EdgeInsets.only(bottom: 16),
    this.avatarBackground,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(currentChildProvider);
    final l10n = AppLocalizations.of(context)!;
    final name = (child?.name.isNotEmpty ?? false)
        ? child!.name
        : (child?.id ?? l10n.friendFallback);
    final level = child?.level ?? 1;
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: compact ? AppConstants.fontSize : AppConstants.largeFontSize,
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onSurface,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: compact ? 12 : 14,
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final avatarRadius = compact ? 20.0 : 28.0;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (child != null)
            ChildCustomizableAvatar(
              child: child,
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
