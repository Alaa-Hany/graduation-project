import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/providers/plan_provider.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';
import 'package:kinder_world/core/widgets/premium_upsell_widget.dart';

class PlanGuard extends ConsumerWidget {
  final PlanTier requiredTier;
  final Widget child;
  final String? featureLabel;
  final EdgeInsetsGeometry padding;

  const PlanGuard({
    super.key,
    required this.requiredTier,
    required this.child,
    this.featureLabel,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(planInfoProvider);
    final l10n = AppLocalizations.of(context)!;

    return planAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      error: (_, __) => Padding(
        padding: padding,
        child: _PlanGuardStateCard(
          icon: Icons.cloud_off_rounded,
          title: l10n.error,
          subtitle: l10n.tryAgain,
          actionLabel: l10n.retry,
          onPressed: () => ref.invalidate(subscriptionSnapshotProvider),
        ),
      ),
      data: (plan) {
        if (plan.canAccess(requiredTier)) {
          return child;
        }
        return Padding(
          padding: padding,
          child: PremiumUpsellWidget(
            plan: plan,
            requiredTier: requiredTier,
            featureLabel: featureLabel,
          ),
        );
      },
    );
  }
}

class _PlanGuardStateCard extends StatelessWidget {
  const _PlanGuardStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.primary, size: 30),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onPressed,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
