import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/api/api_providers.dart';
import 'package:kinder_world/core/services/ai_buddy_service.dart';

final aiBuddyServiceProvider = Provider<AiBuddyService>((ref) {
  final api = ref.watch(aiBuddyApiProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  final logger = ref.watch(loggerProvider);
  return AiBuddyService(
    api: api,
    secureStorage: secureStorage,
    logger: logger,
  );
});
