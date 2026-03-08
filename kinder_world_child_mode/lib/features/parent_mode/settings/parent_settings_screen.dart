import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/router.dart';

class ParentSettingsScreen extends ConsumerWidget {
  const ParentSettingsScreen({super.key});

  void _safeNavigate(VoidCallback action) {
    Future.microtask(action);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    final bool isPremium = user?.hasActiveSubscription ?? false;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: colors.onSurface),
          onPressed: () => context.go(Routes.parentDashboard),
        ),
        title: Text(
          l10n.settings,
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
              height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // ── Profile Header ──────────────────────────────────────────
            _ProfileHeader(
              name: user?.name ?? l10n.parentFallback,
              email: user?.email ?? '',
              isPremium: isPremium,
              onEditTap: () =>
                  _safeNavigate(() => context.push(Routes.parentProfile)),
            ),
            const SizedBox(height: 24),

            // ── Account ─────────────────────────────────────────────────
            ParentSettingsGroup(
              label: l10n.accountSection,
              tiles: [
                ParentSettingsTile(
                  icon: Icons.lock_rounded,
                  iconColor: ParentColors.activityPurple,
                  title: l10n.changePassword,
                  subtitle: l10n.changePasswordSubtitle,
                  onTap: () => _safeNavigate(
                      () => context.push(Routes.parentChangePassword)),
                ),
                ParentSettingsTile(
                  icon: Icons.notifications_rounded,
                  iconColor: ParentColors.alertAmber,
                  title: l10n.notifications,
                  subtitle: l10n.notificationsSubtitle,
                  showDivider: false,
                  onTap: () => _safeNavigate(
                      () => context.push(Routes.parentNotifications)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Family ──────────────────────────────────────────────────
            ParentSettingsGroup(
              label: l10n.familySection,
              tiles: [
                ParentSettingsTile(
                  icon: Icons.child_care_rounded,
                  iconColor: ParentColors.parentGreenLight,
                  title: l10n.childProfiles,
                  subtitle: l10n.childProfilesSubtitle,
                  onTap: () => _safeNavigate(
                      () => context.push(Routes.parentChildManagement)),
                ),
                ParentSettingsTile(
                  icon: Icons.security_rounded,
                  iconColor: ParentColors.alertRed,
                  title: l10n.parentalControls,
                  subtitle: l10n.parentalControlsSubtitle,
                  onTap: () => _safeNavigate(
                      () => context.push(Routes.parentControls)),
                ),
                ParentSettingsTile(
                  icon: Icons.workspace_premium_rounded,
                  iconColor: ParentColors.xpGold,
                  title: l10n.subscription,
                  subtitle: isPremium ? l10n.premiumActive : l10n.upgradePlan,
                  trailing: isPremium
                      ? const ParentStatusBadge(status: ParentBadgeStatus.premium)
                      : null,
                  showDivider: false,
                  onTap: () => _safeNavigate(
                      () => context.push(Routes.parentSubscription)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Preferences ─────────────────────────────────────────────
            ParentSettingsGroup(
              label: l10n.preferencesSection,
              tiles: [
                ParentSettingsTile(
                  icon: Icons.language_rounded,
                  iconColor: ParentColors.infoBlue,
                  title: l10n.language,
                  subtitle: l10n.languageSubtitle,
                  onTap: () => _safeNavigate(
                      () => context.push(Routes.parentLanguage)),
                ),
                ParentSettingsTile(
                  icon: Icons.palette_rounded,
                  iconColor: ParentColors.activityPurple,
                  title: l10n.theme,
                  subtitle: l10n.themeSubtitle,
                  onTap: () =>
                      _safeNavigate(() => context.push(Routes.parentTheme)),
                ),
                ParentSettingsTile(
                  icon: Icons.privacy_tip_rounded,
                  iconColor: ParentColors.parentGreen,
                  title: l10n.privacySettings,
                  subtitle: l10n.privacySettingsSubtitle,
                  showDivider: false,
                  onTap: () => _safeNavigate(
                      () => context.push(Routes.parentPrivacySettings)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Support ─────────────────────────────────────────────────
            ParentSettingsGroup(
              label: l10n.supportSection,
              tiles: [
                ParentSettingsTile(
                  icon: Icons.help_rounded,
                  iconColor: ParentColors.infoBlue,
                  title: l10n.helpFaq,
                  subtitle: l10n.helpFaqSubtitle,
                  onTap: () =>
                      _safeNavigate(() => context.push(Routes.parentHelp)),
                ),
                ParentSettingsTile(
                  icon: Icons.mail_rounded,
                  iconColor: ParentColors.parentGreenLight,
                  title: l10n.contactUs,
                  subtitle: l10n.contactUsSubtitle,
                  onTap: () =>
                      _safeNavigate(() => context.push(Routes.parentContactUs)),
                ),
                ParentSettingsTile(
                  icon: Icons.info_rounded,
                  iconColor: Colors.blueGrey,
                  title: l10n.about,
                  subtitle: l10n.aboutSubtitle,
                  showDivider: false,
                  onTap: () =>
                      _safeNavigate(() => context.push(Routes.parentAbout)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Danger Zone ─────────────────────────────────────────────
            ParentSettingsGroup(
              tiles: [
                ParentSettingsTile(
                  icon: Icons.logout_rounded,
                  title: l10n.logout,
                  isDestructive: true,
                  showDivider: false,
                  trailing: const SizedBox.shrink(),
                  onTap: () async {
                    final confirmed = await _confirmLogout(context, l10n);
                    if (confirmed && context.mounted) {
                      await ref
                          .read(childSessionControllerProvider.notifier)
                          .endChildSession();
                      await ref
                          .read(authControllerProvider.notifier)
                          .logout();
                      if (context.mounted) {
                        context.go(Routes.selectUserType);
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── App version footnote ─────────────────────────────────────
            Center(
              child: Text(
                l10n.appVersionLabel('1.0.0'),
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmLogout(
      BuildContext context, AppLocalizations l10n) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.logoutTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(l10n.logoutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ParentColors.alertRed,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final bool isPremium;
  final VoidCallback? onEditTap;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.isPremium,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar circle
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ParentColors.parentGreen,
                  ParentColors.parentGreenLight,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'P',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Name + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                if (isPremium)
                  const ParentStatusBadge(status: ParentBadgeStatus.premium)
                else
                  const ParentStatusBadge(status: ParentBadgeStatus.active),
              ],
            ),
          ),
          // Edit icon
          GestureDetector(
            onTap: onEditTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.edit_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
