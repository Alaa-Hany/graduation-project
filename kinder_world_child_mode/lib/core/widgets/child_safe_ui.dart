import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/services/sound_effects_service.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';

/// Shows a small floating "+xp" toast after a child earns experience points.
/// Used after every activity that awards XP (lesson, quiz, game, coloring
/// page, AI buddy session, daily streak, etc.) so the gain is always visible,
/// not just reflected silently in the profile totals.
void showXpGainPopup(BuildContext context, {required int xp, int coins = 0}) {
  if (xp <= 0) return;
  unawaited(SoundEffectsService.instance.playReward());
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
      duration: const Duration(seconds: 2),
      backgroundColor: context.childTheme.xp,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Row(
        children: [
          const Icon(Icons.star_rounded, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            l10n.xpGainedToast(xp),
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

void showChildFeedbackSnackBar(
  BuildContext context,
  String message, {
  bool success = true,
}) {
  final theme = Theme.of(context);
  final bg = success ? context.childTheme.success : theme.colorScheme.error;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
      duration: const Duration(seconds: 2),
      backgroundColor: bg,
      content: Text(
        message,
        style: theme.textTheme.labelLarge?.copyWith(
          color: bg.onColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class ChildPrimaryActionButton extends StatelessWidget {
  const ChildPrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.semanticLabel,
    this.backgroundColor,
    this.foregroundColor,
    this.isBusy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? semanticLabel;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? colors.primary;
    final fg = foregroundColor ?? bg.onColor;
    final child = isBusy
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: fg,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: fg,
                  ),
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isBusy ? null : onPressed,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            backgroundColor: bg,
            foregroundColor: fg,
          ),
          child: child,
        ),
      ),
    );
  }
}
