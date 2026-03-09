// ─────────────────────────────────────────────────────────────────────────────
// DEAD CODE — childSyncServiceProvider is not imported anywhere in the app.
// Safe to delete once background-sync feature is implemented or abandoned.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/services/child_sync_service.dart';

final childSyncServiceProvider = Provider<ChildSyncService>((ref) {
  final childRepository = ref.watch(childRepositoryProvider);
  final networkService = ref.watch(networkServiceProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  final logger = ref.watch(loggerProvider);

  return ChildSyncService(
    childRepository: childRepository,
    networkService: networkService,
    secureStorage: secureStorage,
    logger: logger,
  );
});
