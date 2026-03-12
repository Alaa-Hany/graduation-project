import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';
import 'package:logger/logger.dart';

class SubscriptionService {
  final NetworkService _networkService;
  final Logger _logger;

  SubscriptionService({
    required NetworkService networkService,
    required Logger logger,
  })  : _networkService = networkService,
        _logger = logger;

  Future<bool> activateSubscription(PlanTier tier) async {
    if (tier != PlanTier.free) {
      _logger.w(
        'Blocked activation for paid tier $tier because payment is not configured.',
      );
      return false;
    }
    try {
      final response = await _networkService.post<Map<String, dynamic>>(
        '/subscription/select',
        data: {
          'plan_type': _planTypeForTier(tier),
        },
      );
      return response.data != null;
    } catch (e) {
      _logger.e('Error activating subscription: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getSubscription() async {
    try {
      final response = await _networkService.get<Map<String, dynamic>>(
        '/subscription/me',
      );
      return response.data;
    } catch (e) {
      _logger.e('Error fetching subscription: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listPlans() async {
    try {
      final response = await _networkService.get<List<dynamic>>('/plans');
      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (e) {
      _logger.e('Error fetching plans: $e');
    }
    return [];
  }

  Future<bool> openBillingPortal() async {
    try {
      await _networkService.post<Map<String, dynamic>>('/billing/portal');
      return true;
    } catch (e) {
      _logger.e('Error opening billing portal: $e');
      return false;
    }
  }

  String _planTypeForTier(PlanTier tier) {
    switch (tier) {
      case PlanTier.familyPlus:
        return 'family_plus';
      case PlanTier.premium:
        return 'premium';
      case PlanTier.free:
        return 'free';
    }
  }
}
