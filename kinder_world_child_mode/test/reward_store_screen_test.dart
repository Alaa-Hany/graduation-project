import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kinder_world/core/models/achievement.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/features/child_mode/store/reward_store_screen.dart';

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

  test('coin floor gives 2 coins per completed activity', () {
    final child = ChildProfile(
      id: 'kid-1',
      name: 'Lina',
      age: 7,
      avatar: 'bear',
      interests: const <String>[],
      level: 1,
      xp: 0,
      streak: 0,
      favorites: const <String>[],
      parentId: 'parent-1',
      picturePassword: const <String>['sun'],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      totalTimeSpent: 0,
      activitiesCompleted: 3,
    );

    const gamification = GamificationState(
      childId: 'kid-1',
      totalXP: 40,
      level: 1,
      streak: 0,
      achievements: <Achievement>[],
      badges: <Badge>[],
      activitiesCompleted: 3,
    );

    expect(rewardStoreCoinFloor(gamification: null, child: child), 6);
    expect(rewardStoreCoinFloor(gamification: gamification, child: child), 6);
  });

  test('redeem buys item directly without parent approval', () {
    final box = Hive.box<dynamic>('gamification_data');
    final notifier = RewardStoreNotifier(box, 'kid-1', 10);
    final item = rewardCatalog.firstWhere((reward) => reward.id == 'av_robot');

    final result = notifier.redeem(item);

    expect(result.outcome, RewardRedeemOutcome.purchased);
    expect(notifier.state.pendingRequests, isEmpty);
    expect(notifier.state.ownedIds, contains(item.id));
    expect(notifier.state.coins, 6);
  });

  test('legacy pending approvals are cleared on load', () {
    final box = Hive.box<dynamic>('gamification_data');
    box.put(
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

    final notifier = RewardStoreNotifier(box, 'kid-1', 0);

    expect(notifier.state.pendingRequests, isEmpty);
    expect(box.get('store_pending_requests_kid-1'), '[]');
  });
}
