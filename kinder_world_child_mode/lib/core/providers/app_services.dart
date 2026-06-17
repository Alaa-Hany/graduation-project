import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/providers/maintenance_mode_provider.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) {
  throw UnimplementedError('secureStorageProvider must be overridden');
});

final loggerProvider = Provider<Logger>((ref) {
  throw UnimplementedError('loggerProvider must be overridden');
});

final networkServiceProvider = Provider<NetworkService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final logger = ref.watch(loggerProvider);
  final maintenanceController =
      ref.watch(maintenanceModeControllerProvider.notifier);
  return NetworkService(
    secureStorage: secureStorage,
    logger: logger,
    onMaintenanceModeChanged: maintenanceController.setMaintenanceMode,
  );
});
