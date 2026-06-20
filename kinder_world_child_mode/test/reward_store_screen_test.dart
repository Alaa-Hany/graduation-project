import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kinder_world/core/repositories/gamification_repository.dart';
import 'package:kinder_world/features/child_mode/store/reward_store_screen.dart';
import 'package:logger/logger.dart';

import 'support/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHarness.ensureHiveReady(
        boxes: const <String>['gamification_data']);
  });

  setUp(() async {
    await Hive.box<dynamic>('gamification_data').clear();
  });


  test('redeem buys item directly without parent approval', () async {
    final box = Hive.box<dynamic>('gamification_data');
    await box.put('gam_coins_kid-1', 10);
    final gamRepo =
        GamificationRepository(gamificationBox: box, logger: Logger());
    final notifier = RewardStoreNotifier(box, 'kid-1', gamRepo);
    // The constructor kicks off an async _load() (reads coins from gamRepo)
    // without awaiting it, so state still has the coins:0 default until the
    // next microtask runs.
    await Future<void>.delayed(Duration.zero);
    final item = rewardCatalog.firstWhere((reward) => reward.id == 'av_robot');

    // The real screen calls redeemAsync (reward_store_screen.dart:751); the
    // sync redeem() is an unused, non-persisting optimistic pre-check that
    // never mutates state, so it isn't a meaningful thing to assert against.
    final result = await notifier.redeemAsync(item);

    expect(result.outcome, RewardRedeemOutcome.purchased);
    expect(notifier.state.pendingRequests, isEmpty);
    expect(notifier.state.ownedIds, contains(item.id));
    expect(notifier.state.coins, 6);
  });

  test('legacy pending approvals are cleared on load', () async {
    final box = Hive.box<dynamic>('gamification_data');
    await box.put(
      'store_pending_requests_kid-1',
      jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'legacy',
          'child_id': 'kid-1',
          'item_id': 'av_robot',
          'status': 'pending',
          'requires_parent_approval': true,
          'requested_at': DateTime(2026, 1, 1).toIso8601String(),
        },
      ]),
    );

    final gamRepo =
        GamificationRepository(gamificationBox: box, logger: Logger());
    final notifier = RewardStoreNotifier(box, 'kid-1', gamRepo);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.pendingRequests, isEmpty);
    expect(box.get('store_pending_requests_kid-1'), '[]');
  });
}
