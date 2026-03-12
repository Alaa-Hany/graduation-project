import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return planAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      error: (_, __) => child,
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
