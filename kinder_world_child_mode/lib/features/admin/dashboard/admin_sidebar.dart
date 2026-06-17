import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/utils/color_compat.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/dashboard/admin_presentation_scope.dart';
import 'package:kinder_world/router.dart';

class _SidebarItem {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
    this.requiredPermission,
  });

  final IconData icon;
  final String Function(AppLocalizations l10n) label;
  final String route;
  final String? requiredPermission;
}

class _SidebarSection {
  const _SidebarSection(this.items);

  final List<_SidebarItem> items;
}

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

  static final List<_SidebarSection> _sections = [
    _SidebarSection([
      _SidebarItem(
        icon: Icons.dashboard_outlined,
        label: (l10n) => l10n.adminSidebarOverview,
        route: Routes.adminDashboard,
      ),
      _SidebarItem(
        icon: Icons.auto_stories_outlined,
        label: (l10n) => l10n.adminSidebarContent,
        route: Routes.adminContent,
        requiredPermission: 'admin.content.view',
      ),
      _SidebarItem(
        icon: Icons.insights_outlined,
        label: (l10n) => l10n.adminSidebarReports,
        route: Routes.adminReports,
        requiredPermission: 'admin.analytics.view',
      ),
    ]),
    _SidebarSection([
      _SidebarItem(
        icon: Icons.people_outline,
        label: (l10n) => l10n.adminSidebarUsers,
        route: Routes.adminUsers,
        requiredPermission: 'admin.users.view',
      ),
      _SidebarItem(
        icon: Icons.child_care_outlined,
        label: (l10n) => l10n.adminSidebarChildren,
        route: Routes.adminChildren,
        requiredPermission: 'admin.children.view',
      ),
      _SidebarItem(
        icon: Icons.support_agent_outlined,
        label: (l10n) => l10n.adminSidebarSupport,
        route: Routes.adminSupport,
        requiredPermission: 'admin.support.view',
      ),
      _SidebarItem(
        icon: Icons.workspace_premium_outlined,
        label: (l10n) => l10n.adminSidebarSubscriptions,
        route: Routes.adminSubscriptions,
        requiredPermission: 'admin.subscription.view',
      ),
    ]),
    _SidebarSection([
      _SidebarItem(
        icon: Icons.history_outlined,
        label: (l10n) => l10n.adminSidebarAudit,
        route: Routes.adminAudit,
        requiredPermission: 'admin.audit.view',
      ),
      _SidebarItem(
        icon: Icons.manage_accounts_outlined,
        label: (l10n) => l10n.adminSidebarAdmins,
        route: Routes.adminAdmins,
        requiredPermission: 'admin.admins.manage',
      ),
      _SidebarItem(
        icon: Icons.tune_outlined,
        label: (l10n) => l10n.adminSidebarSettings,
        route: Routes.adminSettings,
        requiredPermission: 'admin.settings.edit',
      ),
    ]),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final admin = ref.watch(currentAdminProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    List<_SidebarItem> visibleItems(List<_SidebarItem> items) {
      return items.where((item) {
        if (!adminPresentationMenuRoutes.contains(item.route)) {
          return false;
        }
        final permission = item.requiredPermission;
        if (permission == null) {
          return true;
        }
        return admin?.hasPermission(permission) ?? false;
      }).toList();
    }

    final sections = _sections
        .map((section) => visibleItems(section.items))
        .where((items) => items.isNotEmpty)
        .toList();
    final quickRoutes = {
      Routes.adminContent,
      Routes.adminUsers,
      Routes.adminSupport,
      Routes.adminSettings,
    };
    final quickAccess = sections
        .expand((items) => items)
        .where((item) => quickRoutes.contains(item.route))
        .take(4)
        .toList();

    final content = SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            decoration: BoxDecoration(color: colorScheme.primaryContainer),
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
                                    .withValuesCompat(alpha: 0.7),
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
                    runSpacing: 6,
                    children: admin!.roles.map((role) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValuesCompat(
                            alpha: 0.15,
                          ),
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
                if (quickAccess.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: quickAccess.map((item) {
                      final isSelected = selectedRoute == item.route ||
                          selectedRoute.startsWith('${item.route}/');
                      return FilledButton.tonal(
                        onPressed: () {
                          onClose?.call();
                          if (!isSelected) {
                            context.go(item.route);
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: isSelected
                              ? colorScheme.primary
                              : colorScheme.primary
                                  .withValuesCompat(alpha: 0.14),
                          foregroundColor: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.primary,
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        child: Text(item.label(l10n)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (int sectionIndex = 0;
                    sectionIndex < sections.length;
                    sectionIndex++) ...[
                  ...sections[sectionIndex].map((item) {
                    final isSelected = selectedRoute == item.route ||
                        selectedRoute.startsWith('${item.route}/');

                    return ListTile(
                      leading: isSelected
                          ? Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValuesCompat(
                                  alpha: 0.12,
                                ),
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
                              color: colorScheme.onSurface.withValuesCompat(
                                alpha: 0.6,
                              ),
                            ),
                      title: Text(
                        item.label(l10n),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: colorScheme.primaryContainer
                          .withValuesCompat(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      onTap: () {
                        onClose?.call();
                        if (!isSelected) {
                          context.go(item.route);
                        }
                      },
                    );
                  }),
                  if (sectionIndex != sections.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Divider(
                        height: 1,
                        color: colorScheme.outlineVariant
                            .withValuesCompat(alpha: 0.6),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout, color: colorScheme.error),
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
              color: colorScheme.outlineVariant.withValuesCompat(alpha: 0.5),
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
            content: Text(l10n.adminLogoutConfirm),
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
        ) ??
        false;

    if (confirmed) {
      await ref.read(adminAuthProvider.notifier).logout();
      if (context.mounted) {
        context.go(Routes.adminLogin);
      }
    }
  }
}
