import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/router.dart';

// ─────────────────────────── Sidebar item model ──────────────────────────────

/// IMPORTANT:
/// All UI text must use AppLocalizations.
/// Hardcoded strings are NOT allowed.

class _SidebarItem {
  final IconData icon;
  final String Function(AppLocalizations l10n) label;
  final String route;
  final String? requiredPermission;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
    this.requiredPermission,
  });
}

// ─────────────────────────── Sidebar widget ──────────────────────────────────

class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({
    super.key,
    required this.selectedRoute,
    this.onClose,
    this.embedded = false,
  });

  final String selectedRoute;
  final VoidCallback? onClose;
  final bool embedded;

  static final List<_SidebarItem> _items = [
    _SidebarItem(
      icon: Icons.dashboard_outlined,
      label: (l) => l.adminSidebarOverview,
      route: Routes.adminDashboard,
    ),
    _SidebarItem(
      icon: Icons.people_outline,
      label: (l) => l.adminSidebarUsers,
      route: Routes.adminUsers,
      requiredPermission: 'admin.users.view',
    ),
    _SidebarItem(
      icon: Icons.child_care_outlined,
      label: (l) => l.adminSidebarChildren,
      route: Routes.adminChildren,
      requiredPermission: 'admin.children.view',
    ),
    _SidebarItem(
      icon: Icons.library_books_outlined,
      label: (l) => l.adminSidebarContent,
      route: Routes.adminContent,
      requiredPermission: 'admin.content.view',
    ),
    _SidebarItem(
      icon: Icons.bar_chart_outlined,
      label: (l) => l.adminSidebarReports,
      route: Routes.adminReports,
      requiredPermission: 'admin.analytics.view',
    ),
    _SidebarItem(
      icon: Icons.support_agent_outlined,
      label: (l) => l.adminSidebarSupport,
      route: Routes.adminSupport,
      requiredPermission: 'admin.support.view',
    ),
    _SidebarItem(
      icon: Icons.subscriptions_outlined,
      label: (l) => l.adminSidebarSubscriptions,
      route: Routes.adminSubscriptions,
      requiredPermission: 'admin.subscription.view',
    ),
    _SidebarItem(
      icon: Icons.admin_panel_settings_outlined,
      label: (l) => l.adminSidebarAdmins,
      route: Routes.adminAdmins,
      requiredPermission: 'admin.admins.manage',
    ),
    _SidebarItem(
      icon: Icons.history_outlined,
      label: (l) => l.adminSidebarAudit,
      route: Routes.adminAudit,
      requiredPermission: 'admin.audit.view',
    ),
    _SidebarItem(
      icon: Icons.settings_outlined,
      label: (l) => l.adminSidebarSettings,
      route: Routes.adminSettings,
      requiredPermission: 'admin.settings.edit',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final admin = ref.watch(currentAdminProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final content = SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.admin_panel_settings_outlined,
                          color: colorScheme.onPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.adminDashboard,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            if (admin?.email != null)
                              Text(
                                admin!.email,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.7),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (onClose != null)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: onClose,
                          color: colorScheme.onPrimaryContainer,
                          iconSize: 20,
                        ),
                    ],
                  ),
                  if (admin?.roles.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: admin!.roles.map((role) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            role,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

            // ── Nav items ───────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: _items.map((item) {
                  // Permission check — hide items the admin can't access
                  if (item.requiredPermission != null) {
                    final hasPermission =
                        admin?.hasPermission(item.requiredPermission!) ?? false;
                    if (!hasPermission) return const SizedBox.shrink();
                  }

                  final isSelected = selectedRoute == item.route ||
                      selectedRoute.startsWith('${item.route}/');

                  return ListTile(
                    leading: isSelected
                        ? Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              item.icon,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                          )
                        : Icon(
                            item.icon,
                            size: 20,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                    title: Text(
                      item.label(l10n),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor:
                        colorScheme.primaryContainer.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 2),
                    onTap: () {
                      onClose?.call();
                      if (!isSelected) context.go(item.route);
                    },
                  );
                }).toList(),
              ),
            ),

            // ── Logout ──────────────────────────────────────────────────
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.logout,
                color: colorScheme.error,
              ),
              title: Text(
                l10n.adminLogout,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () => _confirmLogout(context, ref, l10n),
            ),
            const SizedBox(height: 8),
          ],
        ),
    );

    if (embedded) {
      return Container(
        width: 296,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            right: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: content,
      );
    }

    return Drawer(
      backgroundColor: colorScheme.surface,
      child: content,
    );
  }

  Future<void> _confirmLogout(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminLogout),
        content: Text(
          l10n.adminLogoutConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.adminLogout),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(adminAuthProvider.notifier).logout();
      if (context.mounted) context.go(Routes.adminLogin);
    }
  }
}
