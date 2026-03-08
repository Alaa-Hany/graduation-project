import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/router.dart';

class AdminAccessDeniedScreen extends ConsumerWidget {
  const AdminAccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n?.adminAccessDenied ?? 'Access Denied'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n?.adminPermissionDenied ?? 'Permission Denied',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n?.adminPermissionDeniedMessage ??
                    'You do not have permission to access this section. '
                        'Contact your system administrator.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.go(Routes.adminDashboard),
                icon: const Icon(Icons.dashboard_outlined),
                label: Text(l10n?.adminDashboard ?? 'Admin Dashboard'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () async {
                  await ref.read(adminAuthProvider.notifier).logout();
                  if (context.mounted) context.go(Routes.adminLogin);
                },
                icon: const Icon(Icons.logout),
                label: Text(l10n?.adminLogout ?? 'Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
