import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/features/admin/audit/admin_audit_logs_screen.dart';
import 'package:kinder_world/features/admin/admins/admin_admin_management_screen.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/children/admin_child_details_screen.dart';
import 'package:kinder_world/features/admin/children/admin_children_screen.dart';
import 'package:kinder_world/features/admin/content/admin_content_management_screen.dart';
import 'package:kinder_world/features/admin/dashboard/admin_home_tab.dart';
import 'package:kinder_world/features/admin/dashboard/admin_presentation_scope.dart';
import 'package:kinder_world/features/admin/dashboard/admin_sidebar.dart';
import 'package:kinder_world/features/admin/reports/admin_analytics_screen.dart';
import 'package:kinder_world/features/admin/settings/admin_system_settings_screen.dart';
import 'package:kinder_world/features/admin/subscriptions/admin_subscriptions_screen.dart';
import 'package:kinder_world/features/admin/support/admin_support_tickets_screen.dart';
import 'package:kinder_world/features/admin/users/admin_user_details_screen.dart';
import 'package:kinder_world/features/admin/users/admin_users_screen.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/router.dart';
import 'package:kinder_world/core/utils/color_compat.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key, this.activePath});

  final String? activePath;

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String get _selectedRoute {
    final activePath = widget.activePath;
    if (isAdminPresentationRoute(activePath)) {
      return activePath!;
    }
    return Routes.adminDashboard;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(adminAuthProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (authState.status == AdminAuthStatus.initial ||
        authState.status == AdminAuthStatus.loading) {
      return Scaffold(
        backgroundColor: colorScheme.surfaceContainerLowest,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (authState.status == AdminAuthStatus.unauthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go(Routes.adminLogin);
        }
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !mounted) return;
        context.appBack(
          fallback: _selectedRoute == Routes.adminDashboard
              ? Routes.selectUserType
              : Routes.adminDashboard,
        );
      },
      child: Theme(
        data: _adminTheme(theme),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1180;
            final compact = constraints.maxWidth < 720;
            final bodyContent = KeyedSubtree(
              key: ValueKey(_selectedRoute),
              child: _buildBody(),
            );

            return Scaffold(
              key: _scaffoldKey,
              backgroundColor: colorScheme.surfaceContainerLowest,
              appBar: AppBar(
                backgroundColor: colorScheme.surface,
                elevation: 0,
                scrolledUnderElevation: 1,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.appBack(
                    fallback: _selectedRoute == Routes.adminDashboard
                        ? Routes.selectUserType
                        : Routes.adminDashboard,
                  ),
                  tooltip: l10n.goBack,
                ),
                titleSpacing: compact ? 8 : NavigationToolbar.kMiddleSpacing,
                title: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:
                            colorScheme.primary.withValuesCompat(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_outlined,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.adminDashboard,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: compact ? 18 : 20,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (!compact)
                            Text(
                              l10n.adminDashboardSubtitle,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  if (!wide)
                    IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      tooltip: l10n.adminMenuTooltip,
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh_outlined),
                    tooltip: l10n.adminRefreshTooltip,
                    onPressed: () =>
                        ref.read(adminAuthProvider.notifier).refreshProfile(),
                  ),
                  _AdminAvatarButton(
                    onLogout: () => _handleLogout(context, l10n),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              drawer: wide
                  ? null
                  : AdminSidebar(
                      selectedRoute: _selectedRoute,
                      onClose: () => _scaffoldKey.currentState?.closeDrawer(),
                    ),
              body: SafeArea(
                top: false,
                child: wide
                    ? Row(
                        children: [
                          AdminSidebar(
                            embedded: true,
                            selectedRoute: _selectedRoute,
                          ),
                          Expanded(child: bodyContent),
                        ],
                      )
                    : bodyContent,
              ),
            );
          },
        ),
      ),
    );
  }

  ThemeData _adminTheme(ThemeData baseTheme) {
    return baseTheme.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: baseTheme.filledButtonTheme.style?.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ) ??
            FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: baseTheme.outlinedButtonTheme.style?.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ) ??
            OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: baseTheme.elevatedButtonTheme.style?.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ) ??
            ElevatedButton.styleFrom(
              minimumSize: const Size(0, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
      ),
    );
  }

  Widget _buildBody() {
    final path = _selectedRoute;

    if (path.startsWith('${Routes.adminUsers}/')) {
      final id = int.tryParse(path.split('/').last);
      if (id != null) {
        return AdminUserDetailsScreen(
          key: ValueKey('admin-user-$id'),
          userId: id,
        );
      }
    }
    if (path == Routes.adminUsers) return const AdminUsersScreen();

    if (path.startsWith('${Routes.adminChildren}/')) {
      final id = int.tryParse(path.split('/').last);
      if (id != null) {
        return AdminChildDetailsScreen(
          key: ValueKey('admin-child-$id'),
          childId: id,
        );
      }
    }
    if (path == Routes.adminChildren) return const AdminChildrenScreen();
    if (path == Routes.adminContent) {
      return const AdminContentManagementScreen();
    }
    if (path == Routes.adminReports) return const AdminAnalyticsScreen();
    if (path == Routes.adminSupport) return const AdminSupportTicketsScreen();
    if (path == Routes.adminSubscriptions) {
      return const AdminSubscriptionsScreen();
    }
    if (path == Routes.adminAdmins) {
      return const AdminAdminManagementScreen();
    }
    if (path == Routes.adminAudit) return const AdminAuditLogsScreen();
    if (path == Routes.adminSettings) {
      return const AdminSystemSettingsScreen();
    }
    return const AdminHomeTab();
  }

  Future<void> _handleLogout(
    BuildContext context,
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

class _AdminAvatarButton extends ConsumerWidget {
  const _AdminAvatarButton({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(currentAdminProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final initials = _initials(admin?.name ?? admin?.email ?? 'A');

    return PopupMenuButton<String>(
      tooltip: admin?.email ?? '',
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
                admin?.name ?? admin?.email ?? '',
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
                        .withValuesCompat(alpha: 0.6),
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
                AppLocalizations.of(ctx)!.adminLogout,
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
    return name.isNotEmpty ? name[0].toUpperCase() : '';
  }
}
