import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/api/admin_api.dart';
import 'package:kinder_world/core/api/ai_buddy_api.dart';
import 'package:kinder_world/core/api/auth_api.dart';
import 'package:kinder_world/core/api/children_api.dart';
import 'package:kinder_world/core/api/reports_api.dart';
import 'package:kinder_world/core/api/subscription_api.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  final network = ref.watch(networkServiceProvider);
  return AuthApi(network);
});

final childrenApiProvider = Provider<ChildrenApi>((ref) {
  final network = ref.watch(networkServiceProvider);
  return ChildrenApi(network);
});

final subscriptionApiProvider = Provider<SubscriptionApi>((ref) {
  final network = ref.watch(networkServiceProvider);
  return SubscriptionApi(network);
});

final reportsApiProvider = Provider<ReportsApi>((ref) {
  final network = ref.watch(networkServiceProvider);
  return ReportsApi(network);
});

final adminApiProvider = Provider<AdminApi>((ref) {
  final network = ref.watch(networkServiceProvider);
  return AdminApi(network);
});

final aiBuddyApiProvider = Provider<AiBuddyApi>((ref) {
  final network = ref.watch(networkServiceProvider);
  return AiBuddyApi(network);
});
