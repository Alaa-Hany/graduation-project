import 'package:flutter_riverpod/flutter_riverpod.dart';

class MaintenanceModeController extends StateNotifier<bool> {
  MaintenanceModeController() : super(false);

  void setMaintenanceMode(bool value) {
    if (state == value) {
      return;
    }
    state = value;
  }

  void clear() => setMaintenanceMode(false);
}

final maintenanceModeControllerProvider =
    StateNotifierProvider<MaintenanceModeController, bool>(
  (ref) => MaintenanceModeController(),
);

final maintenanceModeProvider = Provider<bool>(
  (ref) => ref.watch(maintenanceModeControllerProvider),
);
