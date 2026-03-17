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
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/subscription/checkout',
      data: {
        if (planId != null) 'plan_id': planId,
        if (planType != null) 'plan_type': planType,
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

  Future<Map<String, dynamic>> cancelSubscription() async {
    final response = await _network.post<Map<String, dynamic>>(
      '/subscription/cancel',
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> manageSubscription() async {
    final response = await _network.post<Map<String, dynamic>>(
      '/subscription/manage',
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> openBillingPortal() async {
    final response =
        await _network.post<Map<String, dynamic>>('/billing/portal');
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    final response = await _network.get<Map<String, dynamic>>('/billing/methods');
    final data = response.data;
    final methods = data?['methods'];
    if (methods is! List) return const [];
    return methods
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> addPaymentMethod({
    String? label,
    String? providerMethodId,
    bool setDefault = false,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/billing/methods',
      data: {
        if (label != null && label.isNotEmpty) 'label': label,
        if (providerMethodId != null && providerMethodId.isNotEmpty)
          'provider_method_id': providerMethodId,
        'set_default': setDefault,
      },
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<void> deletePaymentMethod(int methodId) async {
    await _network.delete<Map<String, dynamic>>('/billing/methods/$methodId');
  }
}
