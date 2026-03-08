import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/providers/plan_provider.dart';
import 'package:kinder_world/core/providers/subscription_provider.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/features/child_mode/paywall/payment_methods_screen.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isProcessing = false;
  PlanTier? _processingTier;

  String _planTitle(PlanTier tier, AppLocalizations l10n) {
    switch (tier) {
      case PlanTier.free:
        return l10n.basicFeaturesOnly;
      case PlanTier.premium:
        return l10n.subscriptionTitle;
      case PlanTier.familyPlus:
        return l10n.bestForFamilies;
    }
  }

  Future<void> _applyPlan(PlanTier tier) async {
    await ref.read(authControllerProvider.notifier).applyPlanSelection(tier);
    ref.invalidate(planInfoProvider);
  }

  Future<void> _selectPlan({
    required PlanTier tier,
    required bool requiresPayment,
  }) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _processingTier = tier;
    });
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (requiresPayment) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PaymentMethodsScreen()),
        );
        if (!mounted) return;

        final activated = await ref
            .read(subscriptionServiceProvider)
            .activateSubscription(tier);
        if (!activated) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Failed to activate subscription.')),
          );
          return;
        }
      }

      await _applyPlan(tier);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text(
                '${_planTitle(tier, AppLocalizations.of(context)!)} activated.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingTier = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final plan = ref.watch(planInfoProvider).asData?.value ??
        PlanInfo.fromTier(PlanTier.free);
    final isPremium = plan.tier != PlanTier.free;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: colors.onSurface),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/parent/dashboard');
            }
          },
        ),
        title: Text(
          l10n.subscriptionTitle,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Current Plan Banner ─────────────────────────────────────
              ParentCard(
                backgroundColor: isPremium
                    ? ParentColors.xpGold.withValues(alpha: 0.08)
                    : colors.surfaceContainerHighest,
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: (isPremium
                                ? ParentColors.xpGold
                                : colors.onSurfaceVariant)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isPremium
                            ? Icons.workspace_premium_rounded
                            : Icons.lock_open_rounded,
                        size: 26,
                        color: isPremium
                            ? ParentColors.xpGold
                            : colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _planTitle(plan.tier, l10n),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isPremium
                                ? l10n.subscriptionActiveLabel
                                : l10n.choosePlanLabel,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isPremium)
                      const ParentStatusBadge(status: ParentBadgeStatus.premium)
                    else
                      const ParentStatusBadge(status: ParentBadgeStatus.active),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── What's Included ─────────────────────────────────────────
              ParentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ParentSectionHeader(title: l10n.yourPlanIncludes),
                    const SizedBox(height: 16),
                    _buildFeatureRow(
                        Icons.people_rounded,
                        l10n.planChildProfiles(plan.maxChildren),
                        ParentColors.parentGreen),
                    _buildFeatureRow(Icons.school_rounded,
                        l10n.unlimitedActivities, ParentColors.infoBlue),
                    _buildFeatureRow(Icons.bar_chart_rounded,
                        l10n.advancedReportsLabel, ParentColors.activityPurple),
                    _buildFeatureRow(Icons.psychology_rounded, l10n.aiInsights,
                        ParentColors.parentGreenLight),
                    _buildFeatureRow(Icons.download_rounded,
                        l10n.offlineDownloadsLabel, ParentColors.streakOrange),
                    _buildFeatureRow(Icons.support_agent_rounded,
                        l10n.prioritySupportLabel, ParentColors.xpGold),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Available Plans ─────────────────────────────────────────
              ParentSectionHeader(title: l10n.availablePlans),
              const SizedBox(height: 12),

              _buildPlanCard(
                currentPlan: plan,
                title: 'Free',
                price: '\$0',
                priceLabel: 'forever',
                subtitle: l10n.basicFeaturesOnly,
                features: [
                  l10n.limitedActivities,
                  l10n.oneChildProfile,
                  l10n.advancedReportsLabel,
                ],
                tier: PlanTier.free,
                accentColor: colors.onSurfaceVariant,
                l10n: l10n,
              ),
              const SizedBox(height: 12),

              _buildPlanCard(
                currentPlan: plan,
                title: 'Family',
                price: '\$9.99',
                priceLabel: '/ month',
                subtitle: l10n.bestForFamilies,
                features: [
                  l10n.unlimitedActivities,
                  l10n.upToThreeChildren,
                  '${l10n.advancedReportsLabel} & ${l10n.aiInsights}',
                  l10n.offlineDownloadsLabel,
                  l10n.prioritySupportLabel,
                ],
                tier: PlanTier.familyPlus,
                isRecommended: true,
                accentColor: ParentColors.parentGreen,
                l10n: l10n,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required PlanInfo currentPlan,
    required String title,
    required String price,
    required String priceLabel,
    required String subtitle,
    required List<String> features,
    required PlanTier tier,
    required Color accentColor,
    required AppLocalizations l10n,
    bool isRecommended = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isCurrent = currentPlan.tier == tier;
    final isProcessingThis = _processingTier == tier;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecommended
              ? ParentColors.parentGreen
              : colors.outlineVariant.withValues(alpha: 0.6),
          width: isRecommended ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: isRecommended ? 0.10 : 0.05),
            blurRadius: isRecommended ? 18 : 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recommended badge
            if (isRecommended)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: ParentColors.parentGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.recommendedLabel.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            if (isRecommended) const SizedBox(height: 12),

            // Title + price row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      priceLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Feature list
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 16, color: accentColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 20),

            // CTA button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: isCurrent || _isProcessing
                    ? null
                    : () => _selectPlan(
                          tier: tier,
                          requiresPayment: tier != PlanTier.free,
                        ),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isCurrent ? colors.surfaceContainerHighest : accentColor,
                  foregroundColor: isCurrent ? colors.onSurface : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isProcessingThis
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isCurrent
                            ? l10n.currentPlanLabel
                            : l10n.choosePlanLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
