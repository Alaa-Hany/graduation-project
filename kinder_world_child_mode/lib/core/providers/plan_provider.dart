import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';

final planInfoProvider = FutureProvider.autoDispose<PlanInfo>((ref) async {
  final storage = ref.read(secureStorageProvider);
  final storedPlan = await storage.getPlanType();
  final isPremium = await storage.getIsPremium() ?? false;
  final user = ref.read(authControllerProvider).user;

  final storedTier = _planTierFromString(storedPlan);
  if (storedTier != null) {
    return PlanInfo.fromTier(storedTier);
  }

  final hasActiveSubscription = user?.hasActiveSubscription == true;
  if (hasActiveSubscription || isPremium) {
    return PlanInfo.fromTier(PlanTier.premium);
  }

  return PlanInfo.fromTier(PlanTier.free);
});

PlanTier? _planTierFromString(String? value) {
  if (value == null) return null;
  switch (value.trim().toLowerCase()) {
    case 'family_plus':
    case 'family+':
    case 'family':
      return PlanTier.familyPlus;
    case 'premium':
      return PlanTier.premium;
    case 'free':
      return PlanTier.free;
  }
  return null;
}
