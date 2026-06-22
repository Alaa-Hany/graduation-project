// Unit tests for [SubscriptionService] — cached subscription/history/plans
// fetching (fresh vs cached vs error), checkout session parsing, plan
// activation, and cache invalidation. SubscriptionApi is faked; a real
// AppCacheStore over mock SharedPreferences is used.

import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/api/subscription_api.dart';
import 'package:kinder_world/core/cache/app_cache_store.dart';
import 'package:kinder_world/core/services/subscription_service.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';
import 'package:kinder_world/features/parent_mode/subscription/subscription_plan_catalog.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSubscriptionApi extends Fake implements SubscriptionApi {
  Map<String, dynamic> subscription = {'tier': 'premium'};
  Map<String, dynamic> history = {'events': []};
  List<Map<String, dynamic>> plans = [
    {'id': 'premium'},
  ];
  Map<String, dynamic> checkout = {'checkout_url': 'https://pay/x'};
  Map<String, dynamic> activation = {'status': 'active'};
  bool throwOnGet = false;

  @override
  Future<Map<String, dynamic>> getSubscription() async {
    if (throwOnGet) throw Exception('net');
    return subscription;
  }

  @override
  Future<Map<String, dynamic>> getSubscriptionHistory() async {
    if (throwOnGet) throw Exception('net');
    return history;
  }

  @override
  Future<List<Map<String, dynamic>>> listPlans() async {
    if (throwOnGet) throw Exception('net');
    return plans;
  }

  @override
  Future<Map<String, dynamic>> createCheckoutSession({
    String? planId,
    String? planType,
    String? billingInterval,
  }) async =>
      checkout;

  @override
  Future<Map<String, dynamic>> activatePlan({
    String? planId,
    String? planType,
    String? sessionId,
  }) async =>
      activation;
}

void main() {
  late _FakeSubscriptionApi api;
  late AppCacheStore cacheStore;
  late SubscriptionService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    cacheStore = AppCacheStore(prefs);
    api = _FakeSubscriptionApi();
    service = SubscriptionService(
      subscriptionApi: api,
      cacheStore: cacheStore,
      logger: Logger(level: Level.off),
    );
  });

  group('getSubscription', () {
    test('fetches from API and caches', () async {
      final data = await service.getSubscription();
      expect(data!['tier'], 'premium');
    });

    test('serves cached data on subsequent fresh reads', () async {
      await service.getSubscription();
      api.subscription = {'tier': 'changed'};
      // Cached + fresh => returns the cached value, not the new API value.
      final data = await service.getSubscription();
      expect(data!['tier'], 'premium');
    });

    test('returns null on error without cache', () async {
      api.throwOnGet = true;
      expect(await service.getSubscription(), isNull);
    });

    test('falls back to cache on error when allowed', () async {
      await service.getSubscription(); // seed cache
      api.throwOnGet = true;
      final data = await service.getSubscription(
        forceRefresh: true,
        allowCachedOnError: true,
      );
      expect(data!['tier'], 'premium');
    });
  });

  group('refreshSubscription', () {
    test('invalidates and refetches', () async {
      final data = await service.refreshSubscription();
      expect(data['tier'], 'premium');
    });

    test('throws when unavailable', () async {
      api.throwOnGet = true;
      expect(service.refreshSubscription(), throwsStateError);
    });
  });

  group('history and plans', () {
    test('getSubscriptionHistory fetches and caches', () async {
      final data = await service.getSubscriptionHistory();
      expect(data, isNotNull);
    });

    test('listPlans returns plans', () async {
      final plans = await service.listPlans();
      expect(plans.single['id'], 'premium');
    });

    test('listPlans returns empty on error without cache', () async {
      api.throwOnGet = true;
      expect(await service.listPlans(), isEmpty);
    });
  });

  group('checkout and activation', () {
    test('startCheckout parses checkout session', () async {
      api.checkout = {
        'checkout_url': 'https://pay/abc',
        'session_id': 'sess1',
        'provider': 'stripe',
        'plan_id': 'premium',
      };
      final session = await service.startCheckout(PlanTier.premium);
      expect(session.checkoutUrl, 'https://pay/abc');
      expect(session.sessionId, 'sess1');
      expect(session.provider, 'stripe');
    });

    test('startCheckout accepts the url fallback key', () async {
      api.checkout = {'url': 'https://pay/fallback'};
      final session = await service.startCheckout(
        PlanTier.familyPlus,
        billingInterval: BillingInterval.yearly,
      );
      expect(session.checkoutUrl, 'https://pay/fallback');
      expect(session.provider, 'internal'); // default
    });

    test('startCheckout throws when no url present', () async {
      api.checkout = {'session_id': 'x'};
      expect(service.startCheckout(PlanTier.premium), throwsStateError);
    });

    test('activatePlan returns response and invalidates cache', () async {
      await service.getSubscription(); // seed cache
      final response = await service.activatePlan(PlanTier.premium);
      expect(response['status'], 'active');
      // After invalidation, a fetch hits the API again (new value visible).
      api.subscription = {'tier': 'family_plus'};
      final after = await service.getSubscription();
      expect(after!['tier'], 'family_plus');
    });
  });
}
