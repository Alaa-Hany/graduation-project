import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/providers/accessibility_provider.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/router.dart';

/// Parent-controlled screen for enabling/disabling accessibility features
/// that apply to the child-facing interface.
class AccessibilitySettingsScreen extends ConsumerWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final parent = context.parentTheme;
    final accessibility = ref.watch(accessibilityProvider);
    final controller = ref.read(accessibilityProvider.notifier);

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: colors.onSurface),
          onPressed: () => context.appBack(fallback: Routes.parentSettings),
        ),
        title: Text(
          l10n.accessibilitySettings,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // ── Header banner ──────────────────────────────────────────
            _AccessibilityBanner(
              isAnyEnabled: accessibility.isAnyEnabled,
              l10n: l10n,
              colors: colors,
            ),
            const SizedBox(height: 20),

            // ── Feature toggles ────────────────────────────────────────
            ParentSettingsGroup(
              label: l10n.accessibilityMode,
              tiles: [
                // Large Font toggle
                _AccessibilityToggleTile(
                  icon: Icons.text_fields_rounded,
                  iconColor: parent.info,
                  title: l10n.largeFontMode,
                  subtitle: l10n.largeFontModeSubtitle,
                  value: accessibility.largeFontEnabled,
                  activeLabel: l10n.accessibilityActiveLabel,
                  inactiveLabel: l10n.accessibilityInactiveLabel,
                  onChanged: (v) => controller.setLargeFont(v),
                ),
                // High Contrast toggle
                _AccessibilityToggleTile(
                  icon: Icons.contrast_rounded,
                  iconColor: parent.reward,
                  title: l10n.highContrastMode,
                  subtitle: l10n.highContrastModeSubtitle,
                  value: accessibility.highContrastEnabled,
                  activeLabel: l10n.accessibilityActiveLabel,
                  inactiveLabel: l10n.accessibilityInactiveLabel,
                  showDivider: false,
                  onChanged: (v) => controller.setHighContrast(v),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Live preview ───────────────────────────────────────────
            _LivePreview(
              largeFontEnabled: accessibility.largeFontEnabled,
              highContrastEnabled: accessibility.highContrastEnabled,
              l10n: l10n,
              colors: colors,
            ),
            const SizedBox(height: 20),

            // ── Parent note ────────────────────────────────────────────
            _ParentNote(l10n: l10n, colors: colors),
            const SizedBox(height: 20),

            // ── Reset button ───────────────────────────────────────────
            if (accessibility.isAnyEnabled)
              _ResetButton(
                l10n: l10n,
                colors: colors,
                onReset: () => _confirmReset(context, l10n, controller),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    AppLocalizations l10n,
    AccessibilityController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.accessibilityResetAll,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Text(l10n.accessibilityResetConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.parentTheme.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.done),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.reset();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _AccessibilityBanner extends StatelessWidget {
  final bool isAnyEnabled;
  final AppLocalizations l10n;
  final ColorScheme colors;

  const _AccessibilityBanner({
    required this.isAnyEnabled,
    required this.l10n,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final parent = context.parentTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAnyEnabled
              ? [
                  parent.info.withValues(alpha: 0.15),
                  parent.reward.withValues(alpha: 0.10),
                ]
              : [
                  colors.surfaceContainerHighest,
                  colors.surfaceContainerHighest,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAnyEnabled
              ? parent.info.withValues(alpha: 0.4)
              : colors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isAnyEnabled
                  ? parent.info.withValues(alpha: 0.15)
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.accessibility_new_rounded,
              color: isAnyEnabled ? parent.info : colors.onSurfaceVariant,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.accessibilityMode,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.accessibilityModeSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isAnyEnabled
                  ? parent.info
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isAnyEnabled
                  ? l10n.accessibilityActiveLabel
                  : l10n.accessibilityInactiveLabel,
              key: const Key('accessibility_banner_status'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isAnyEnabled ? colors.onPrimary : colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOGGLE TILE
// ─────────────────────────────────────────────────────────────────────────────

class _AccessibilityToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final String activeLabel;
  final String inactiveLabel;
  final bool showDivider;
  final ValueChanged<bool> onChanged;

  const _AccessibilityToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Icon badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: value
                      ? iconColor.withValues(alpha: 0.15)
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    size: 20,
                    color: value ? iconColor : colors.onSurfaceVariant),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status label + switch
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value ? activeLabel : inactiveLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: value ? iconColor : colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Switch(
                    value: value,
                    onChanged: onChanged,
                    activeThumbColor: iconColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 70,
            color: colors.outlineVariant.withValues(alpha: 0.4),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE PREVIEW
// ─────────────────────────────────────────────────────────────────────────────

class _LivePreview extends StatelessWidget {
  final bool largeFontEnabled;
  final bool highContrastEnabled;
  final AppLocalizations l10n;
  final ColorScheme colors;

  const _LivePreview({
    required this.largeFontEnabled,
    required this.highContrastEnabled,
    required this.l10n,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    // Preview colours
    final previewBg = highContrastEnabled ? Colors.black : colors.surface;
    final previewFg = highContrastEnabled ? Colors.white : colors.onSurface;
    final previewAccent =
        highContrastEnabled ? Colors.yellow : colors.primary;
    final previewBorder =
        highContrastEnabled ? Colors.white : colors.outlineVariant;

    // Preview font scale
    final previewScale = largeFontEnabled ? 1.3 : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Preview',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: previewBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: previewBorder.withValues(alpha: 0.5),
              width: highContrastEnabled ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(previewScale),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Simulated child home header
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: previewAccent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: highContrastEnabled
                            ? Border.all(color: previewAccent, width: 2)
                            : null,
                      ),
                      child: Icon(Icons.child_care_rounded,
                          size: 20, color: previewAccent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, Sara! 👋',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: previewFg,
                            ),
                          ),
                          Text(
                            "Let's learn something today",
                            style: TextStyle(
                              fontSize: 11,
                              color: highContrastEnabled
                                  ? Colors.white70
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Simulated activity button
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: previewAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: highContrastEnabled
                        ? Border.all(color: previewAccent, width: 2)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_rounded,
                          size: 18, color: previewAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Start Learning',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: previewAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PARENT NOTE
// ─────────────────────────────────────────────────────────────────────────────

class _ParentNote extends StatelessWidget {
  final AppLocalizations l10n;
  final ColorScheme colors;

  const _ParentNote({required this.l10n, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.accessibilityParentNote,
              style: TextStyle(
                fontSize: 12,
                color: colors.onPrimaryContainer,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESET BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _ResetButton extends StatelessWidget {
  final AppLocalizations l10n;
  final ColorScheme colors;
  final VoidCallback onReset;

  const _ResetButton({
    required this.l10n,
    required this.colors,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final parent = context.parentTheme;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onReset,
        icon: const Icon(Icons.restart_alt_rounded, size: 18),
        label: Text(l10n.accessibilityResetAll),
        style: OutlinedButton.styleFrom(
          foregroundColor: parent.danger,
          side: BorderSide(color: parent.danger.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
