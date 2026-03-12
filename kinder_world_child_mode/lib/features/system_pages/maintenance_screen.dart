import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/router.dart';

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
    final successColor = context.successColor;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: const AppBackButton(
          fallback: Routes.welcome,
          icon: Icons.arrow_back,
          iconSize: 24,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Gear Icon
              AnimatedBuilder(
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
                    color: warningColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    Icons.build,
                    size: 60,
                    color: warningColor,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Title
              Text(
                AppLocalizations.of(context)!.maintenanceTitle,
                style: textTheme.titleLarge?.copyWith(
                  fontSize: AppConstants.largeFontSize * 1.2,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                AppLocalizations.of(context)!.maintenanceDescription,
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: AppConstants.fontSize,
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Estimated Time
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.estimatedCompletion,
                      style: textTheme.titleSmall?.copyWith(
                        fontSize: AppConstants.fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.maintenanceEtaDuration,
                      style: textTheme.titleLarge?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: warningColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.maintenanceEtaWindow,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // What's New
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.maintenanceWhatsComing,
                      style: textTheme.titleSmall?.copyWith(
                        fontSize: AppConstants.fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(Icons.star,
                        AppLocalizations.of(context)!.maintenanceFeatureAi),
                    const SizedBox(height: 12),
                    _buildFeatureItem(Icons.games,
                        AppLocalizations.of(context)!.maintenanceFeatureGames),
                    const SizedBox(height: 12),
                    _buildFeatureItem(Icons.security,
                        AppLocalizations.of(context)!.maintenanceFeatureSafety),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                        Icons.speed,
                        AppLocalizations.of(context)!
                            .maintenanceFeaturePerformance),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Social Media Links
              Text(
                AppLocalizations.of(context)!.followUsForUpdates,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 14,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialIcon(Icons.facebook, colors.primary),
                  const SizedBox(width: 16),
                  _buildSocialIcon(Icons.email, colors.error),
                  const SizedBox(width: 16),
                  _buildSocialIcon(Icons.web, successColor),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
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
            color: successColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: successColor,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: textTheme.bodyMedium?.copyWith(
            fontSize: AppConstants.fontSize,
            color: colors.onSurfaceVariant,
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: () {
          // Placeholder for social media links
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context)!.openingLink(icon.toString())),
              backgroundColor: color,
            ),
          );
        },
      ),
    );
  }
}
