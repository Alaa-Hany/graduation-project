import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';

enum BillingInterval { monthly, yearly }

class SubscriptionPlanCardConfig {
  const SubscriptionPlanCardConfig({
    required this.title,
    required this.price,
    required this.priceLabel,
    required this.subtitle,
    required this.features,
    required this.tier,
    this.isRecommended = false,
  });

  final String title;
  final String price;
  final String priceLabel;
  final String subtitle;
  final List<String> features;
  final PlanTier tier;
  final bool isRecommended;
}

List<SubscriptionPlanCardConfig> buildSubscriptionPlanCardConfigs(
  AppLocalizations l10n, {
  BillingInterval interval = BillingInterval.monthly,
}) {
  final isYearly = interval == BillingInterval.yearly;
  final priceLabel = isYearly
      ? '${l10n.billedPerYearLabel} • ${l10n.yearlyDiscountLabel}'
      : l10n.billedPerMonthLabel;
  return [
    SubscriptionPlanCardConfig(
      title: l10n.planPremium,
      price: isYearly ? '\$27' : '\$3',
      priceLabel: priceLabel,
      subtitle: l10n.planPremiumSubtitle,
      features: [
        l10n.unlimitedActivities,
        l10n.upToThreeChildren,
        '${l10n.advancedReportsLabel} & ${l10n.aiInsights}',
        l10n.offlineDownloadsLabel,
      ],
      tier: PlanTier.premium,
    ),
    SubscriptionPlanCardConfig(
      title: l10n.planFamilyPlus,
      price: isYearly ? '\$45' : '\$5',
      priceLabel: priceLabel,
      subtitle: l10n.planFamilyPlusSubtitle,
      features: [
        l10n.unlimitedActivities,
        l10n.planUnlimitedChildren,
        '${l10n.advancedReportsLabel} & ${l10n.aiInsights}',
        l10n.offlineDownloadsLabel,
        l10n.planFamilyDashboard,
        l10n.prioritySupportLabel,
      ],
      tier: PlanTier.familyPlus,
      isRecommended: true,
    ),
  ];
}
