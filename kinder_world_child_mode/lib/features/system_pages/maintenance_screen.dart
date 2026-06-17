import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/providers/maintenance_mode_provider.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/features/system_pages/widgets/system_page_layout.dart';
import 'package:kinder_world/router.dart';
import 'package:kinder_world/core/utils/color_compat.dart';

class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2.0 * 3.14159,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final warningColor = context.warningColor;
    final l10n = AppLocalizations.of(context)!;

    return SystemPageLayout(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: const AppBackButton(
          fallback: Routes.welcome,
          icon: Icons.arrow_back,
          iconSize: 24,
        ),
      ),
      illustration: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: warningColor.withValuesCompat(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.xxl),
          ),
          child: Icon(
            Icons.build,
            size: 60,
            color: warningColor,
          ),
        ),
      ),
      title: l10n.maintenanceTitle,
      subtitle: l10n.maintenanceDescription,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SystemInfoCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Text(
                  l10n.estimatedCompletion,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.maintenanceEtaDuration,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: warningColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.maintenanceEtaWindow,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SystemInfoCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.maintenanceWhatsComing,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildFeatureItem(
                  Icons.star,
                  l10n.maintenanceFeatureAi,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildFeatureItem(
                  Icons.games,
                  l10n.maintenanceFeatureGames,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildFeatureItem(
                  Icons.security,
                  l10n.maintenanceFeatureSafety,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildFeatureItem(
                  Icons.speed,
                  l10n.maintenanceFeaturePerformance,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              l10n.followUsForUpdates,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSocialIcon(Icons.facebook, colors.primary),
              const SizedBox(width: AppSpacing.lg),
              _buildSocialIcon(Icons.email, colors.error),
              const SizedBox(width: AppSpacing.lg),
              _buildSocialIcon(Icons.web, context.successColor),
            ],
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: () {
              ref.read(maintenanceModeControllerProvider.notifier).clear();
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/welcome');
              }
            },
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              l10n.tryAgain,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final successColor = context.successColor;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: successColor.withValuesCompat(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            icon,
            size: 16,
            color: successColor,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValuesCompat(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.openingLink(icon.toString()),
              ),
              backgroundColor: color,
            ),
          );
        },
      ),
    );
  }
}
