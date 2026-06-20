import 'package:kinder_world/core/network/network_service.dart';

class SubscriptionApi {
  const SubscriptionApi(this._network);

  final NetworkService _network;

  Future<Map<String, dynamic>> getSubscription() async {
    final response =
        await _network.get<Map<String, dynamic>>('/subscription/me');
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> getSubscriptionHistory() async {
    final response =
        await _network.get<Map<String, dynamic>>('/subscription/history');
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<List<Map<String, dynamic>>> listPlans() async {
    final response = await _network.get<List<dynamic>>('/plans');
    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> selectPlan({
    String? planId,
    String? planType,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/subscription/select',
      data: {
        if (planId != null) 'plan_id': planId,
        if (planType != null) 'plan_type': planType,
      },
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> createCheckoutSession({
    String? planId,
    String? planType,
    String? billingInterval,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/subscription/checkout',
      data: {
        if (planId != null) 'plan_id': planId,
        if (planType != null) 'plan_type': planType,
        if (billingInterval != null) 'billing_interval': billingInterval,
      },
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> activatePlan({
    String? planId,
    String? planType,
    String? sessionId,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/subscription/activate',
      data: {
        if (planId != null) 'plan_id': planId,
        if (planType != null) 'plan_type': planType,
        if (sessionId != null) 'session_id': sessionId,
      },
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }
}
