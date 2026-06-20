enum PlanTier { free, premium, familyPlus }

class PlanInfo {
  final PlanTier tier;
  final int maxChildren;
  final bool hasBasicReports;
  final bool hasAdvancedReports;
  final bool hasAiInsights;
  final bool hasOfflineDownloads;
  final bool hasSmartControls;
  final bool hasExclusiveContent;
  final bool hasFamilyDashboard;
  final bool hasPrioritySupport;

  const PlanInfo({
    required this.tier,
    required this.maxChildren,
    required this.hasBasicReports,
    required this.hasAdvancedReports,
    required this.hasAiInsights,
    required this.hasOfflineDownloads,
    required this.hasSmartControls,
    required this.hasExclusiveContent,
    required this.hasFamilyDashboard,
    required this.hasPrioritySupport,
  });

  factory PlanInfo.fromTier(PlanTier tier) {
    switch (tier) {
      case PlanTier.free:
        return const PlanInfo(
          tier: PlanTier.free,
          maxChildren: 1,
          hasBasicReports: true,
          hasAdvancedReports: false,
          hasAiInsights: false,
          hasOfflineDownloads: false,
          hasSmartControls: false,
          hasExclusiveContent: false,
          hasFamilyDashboard: false,
          hasPrioritySupport: false,
        );
      case PlanTier.premium:
        return const PlanInfo(
          tier: PlanTier.premium,
          maxChildren: 3,
          hasBasicReports: true,
          hasAdvancedReports: true,
          hasAiInsights: true,
          hasOfflineDownloads: true,
          hasSmartControls: true,
          hasExclusiveContent: true,
          hasFamilyDashboard: false,
          hasPrioritySupport: false,
        );
      case PlanTier.familyPlus:
        return const PlanInfo(
          tier: PlanTier.familyPlus,
          maxChildren: 99,
          hasBasicReports: true,
          hasAdvancedReports: true,
          hasAiInsights: true,
          hasOfflineDownloads: true,
          hasSmartControls: true,
          hasExclusiveContent: true,
          hasFamilyDashboard: true,
          hasPrioritySupport: true,
        );
    }
  }

  bool get isRecurringSubscription => tier != PlanTier.free;
  bool get isUnlimitedChildren => tier == PlanTier.familyPlus;

  bool canAccess(PlanTier requiredTier) {
    return tier.index >= requiredTier.index;
  }

  bool canAddChild(int currentCount) {
    if (isUnlimitedChildren) return true;
    return currentCount < maxChildren;
  }
}
