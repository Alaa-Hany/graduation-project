import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/audit/admin_audit_logs_screen.dart';
import 'package:kinder_world/features/admin/admins/admin_admin_management_screen.dart';
import 'package:kinder_world/features/admin/children/admin_child_details_screen.dart';
import 'package:kinder_world/features/admin/children/admin_children_screen.dart';
import 'package:kinder_world/features/admin/content/admin_content_management_screen.dart';
import 'package:kinder_world/features/admin/dashboard/admin_home_tab.dart';
import 'package:kinder_world/features/admin/dashboard/admin_sidebar.dart';
import 'package:kinder_world/features/admin/reports/admin_analytics_screen.dart';
import 'package:kinder_world/features/admin/settings/admin_system_settings_screen.dart';
import 'package:kinder_world/features/admin/support/admin_support_tickets_screen.dart';
import 'package:kinder_world/features/admin/subscriptions/admin_subscriptions_screen.dart';
import 'package:kinder_world/features/admin/users/admin_user_details_screen.dart';
import 'package:kinder_world/features/admin/users/admin_users_screen.dart';
import 'package:kinder_world/router.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  /// The active sub-route path, used to highlight the correct sidebar item.
  final String? activePath;

  const AdminDashboardScreen({super.key, this.activePath});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String get _selectedRoute => widget.activePath ?? Routes.adminDashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(adminAuthProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Session expired — redirect to login
    if (authState.status == AdminAuthStatus.unauthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.adminLogin);
      });
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colorScheme.surfaceContainerLowest,

      // ── App bar ─────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: l10n?.adminMenuTooltip ?? 'Menu',
        ),
        title: Row(
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              color: colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              l10n?.adminDashboard ?? 'Admin Dashboard',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          // Refresh profile
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: l10n?.adminRefreshTooltip ?? 'Refresh',
            onPressed: () =>
                ref.read(adminAuthProvider.notifier).refreshProfile(),
          ),
          // Admin avatar / logout shortcut
          _AdminAvatarButton(
            onLogout: () => _handleLogout(context, l10n),
          ),
          const SizedBox(width: 8),
        ],
      ),

      // ── Drawer (sidebar) ────────────────────────────────────────────────
      drawer: AdminSidebar(
        selectedRoute: _selectedRoute,
        onClose: () => _scaffoldKey.currentState?.closeDrawer(),
      ),

      // ── Body ────────────────────────────────────────────────────────────
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final path = _selectedRoute;

    if (path.startsWith('${Routes.adminUsers}/')) {
      final id = int.tryParse(path.split('/').last);
      if (id != null) {
        return AdminUserDetailsScreen(userId: id);
      }
    }
    if (path == Routes.adminUsers) {
      return const AdminUsersScreen();
    }
    if (path.startsWith('${Routes.adminChildren}/')) {
      final id = int.tryParse(path.split('/').last);
      if (id != null) {
        return AdminChildDetailsScreen(childId: id);
      }
    }
    if (path == Routes.adminChildren) {
      return const AdminChildrenScreen();
    }
    if (path == Routes.adminContent) {
      return const AdminContentManagementScreen();
    }
    if (path == Routes.adminReports) {
      return const AdminAnalyticsScreen();
    }
    if (path == Routes.adminSupport) {
      return const AdminSupportTicketsScreen();
    }
    if (path == Routes.adminSubscriptions) {
      return const AdminSubscriptionsScreen();
    }
    if (path == Routes.adminAdmins) {
      return const AdminAdminManagementScreen();
    }
    if (path == Routes.adminAudit) {
      return const AdminAuditLogsScreen();
    }
    if (path == Routes.adminSettings) {
      return const AdminSystemSettingsScreen();
    }
    return const AdminHomeTab();
  }

  Future<void> _handleLogout(
      BuildContext context, AppLocalizations? l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.adminLogout ?? 'Logout'),
        content: Text(
          l10n?.adminLogoutConfirm ??
              'Are you sure you want to log out of the admin portal?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n?.adminLogout ?? 'Logout'),
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

// ─────────────────────────── Avatar button ───────────────────────────────────

class _AdminAvatarButton extends ConsumerWidget {
  const _AdminAvatarButton({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(currentAdminProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final initials = _initials(admin?.name ?? admin?.email ?? 'A');

    return PopupMenuButton<String>(
      tooltip: admin?.email ?? 'Admin',
      offset: const Offset(0, 48),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          initials,
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                admin?.name ?? 'Admin',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (admin?.email != null)
                Text(
                  admin!.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: colorScheme.error),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(ctx)?.adminLogout ?? 'Logout',
                style: TextStyle(color: colorScheme.error),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'logout') onLogout();
      },
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'[\s@._-]+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'A';
  }
}
