import 'package:kinder_world/core/api/subscription_api.dart';
import 'package:kinder_world/core/cache/app_cache_store.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';
import 'package:kinder_world/features/parent_mode/subscription/subscription_plan_catalog.dart';
import 'package:logger/logger.dart';

class SubscriptionService {
  final SubscriptionApi _subscriptionApi;
  final AppCacheStore _cacheStore;
  final Logger _logger;

  SubscriptionService({
    required SubscriptionApi subscriptionApi,
    required AppCacheStore cacheStore,
    required Logger logger,
  })  : _subscriptionApi = subscriptionApi,
        _cacheStore = cacheStore,
        _logger = logger;

  static const _scope = 'subscription';
  static const _subscriptionKey = 'current';
  static const _historyKey = 'history';
  static const _plansKey = 'plans';
  static const _staleAfter = Duration(minutes: 10);

  Future<Map<String, dynamic>?> getSubscription({
    bool forceRefresh = false,
    bool allowCachedOnError = false,
  }) async {
    final snapshot = _cacheStore.snapshot(
      scope: _scope,
      key: _subscriptionKey,
      staleAfter: _staleAfter,
    );
    if (!forceRefresh && snapshot.hasData && !snapshot.isStale) {
      return _cacheStore.readMap(
        scope: _scope,
        key: _subscriptionKey,
      );
    }

    try {
      final data = await _subscriptionApi.getSubscription();
      await _cacheStore.storeMap(
        scope: _scope,
        key: _subscriptionKey,
        payload: data,
      );
      return data;
    } catch (e) {
      _logger.e('Error fetching subscription: $e');
      if (allowCachedOnError && snapshot.hasData) {
        return _cacheStore.readMap(
          scope: _scope,
          key: _subscriptionKey,
        );
      }
      return null;
    }
  }

  Future<Map<String, dynamic>> refreshSubscription() async {
    await _invalidateSubscriptionCache();
    final data =
        await getSubscription(forceRefresh: true, allowCachedOnError: false);
    if (data == null) {
      throw StateError('Subscription snapshot is unavailable');
    }
    return data;
  }

  Future<Map<String, dynamic>?> getSubscriptionHistory({
    bool forceRefresh = false,
    bool allowCachedOnError = false,
  }) async {
    final snapshot = _cacheStore.snapshot(
      scope: _scope,
      key: _historyKey,
      staleAfter: _staleAfter,
    );
    if (!forceRefresh && snapshot.hasData && !snapshot.isStale) {
      return _cacheStore.readMap(
        scope: _scope,
        key: _historyKey,
      );
    }

    try {
      final data = await _subscriptionApi.getSubscriptionHistory();
      await _cacheStore.storeMap(
        scope: _scope,
        key: _historyKey,
        payload: data,
      );
      return data;
    } catch (e) {
      _logger.e('Error fetching subscription history: $e');
      if (allowCachedOnError && snapshot.hasData) {
        return _cacheStore.readMap(
          scope: _scope,
          key: _historyKey,
        );
      }
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listPlans({
    bool forceRefresh = false,
  }) async {
    final snapshot = _cacheStore.snapshot(
      scope: _scope,
      key: _plansKey,
      staleAfter: _staleAfter,
    );
    if (!forceRefresh && snapshot.hasData && !snapshot.isStale) {
      return _cacheStore.readList(
        scope: _scope,
        key: _plansKey,
      );
    }

    try {
      final data = await _subscriptionApi.listPlans();
      await _cacheStore.storeList(
        scope: _scope,
        key: _plansKey,
        payload: data,
      );
      return data;
    } catch (e) {
      _logger.e('Error fetching plans: $e');
      if (snapshot.hasData) {
        return _cacheStore.readList(
          scope: _scope,
          key: _plansKey,
        );
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> activatePlan(
    PlanTier tier, {
    String? sessionId,
  }) async {
    final response = await _subscriptionApi.activatePlan(
      planType: _planTypeForTier(tier),
      sessionId: sessionId,
    );
    await _invalidateSubscriptionCache();
    return response;
  }

  Future<CheckoutSession> startCheckout(
    PlanTier tier, {
    BillingInterval billingInterval = BillingInterval.monthly,
  }) async {
    final response = await _subscriptionApi.createCheckoutSession(
      planType: _planTypeForTier(tier),
      billingInterval: _intervalKey(billingInterval),
    );
    final url = response['checkout_url'] ?? response['url'];
    if (url is! String || url.isEmpty) {
      throw StateError('Missing checkout_url from backend');
    }
    return CheckoutSession(
      checkoutUrl: url,
      sessionId: response['session_id']?.toString(),
      provider: response['provider']?.toString() ?? 'internal',
      planId: response['plan_id']?.toString(),
    );
  }

  Future<void> _invalidateSubscriptionCache() async {
    await _cacheStore.invalidate(scope: _scope, key: _subscriptionKey);
    await _cacheStore.invalidate(scope: _scope, key: _historyKey);
  }

  String _intervalKey(BillingInterval interval) {
    switch (interval) {
      case BillingInterval.yearly:
        return 'yearly';
      case BillingInterval.monthly:
        return 'monthly';
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

class CheckoutSession {
  const CheckoutSession({
    required this.checkoutUrl,
    this.sessionId,
    this.provider,
    this.planId,
  });

  final String checkoutUrl;
  final String? sessionId;
  final String? provider;
  final String? planId;
}
