import 'package:hive_flutter/hive_flutter.dart';

/// Hive box opened eagerly at startup because the parent auth flow needs it
/// before the first screen renders.
const String startupHiveBox = 'child_profiles';

/// Boxes only required once child-mode (and the parent dashboard features that
/// read child progress) is reached. They are opened by [openChildModeBoxes]
/// rather than blocking the first frame in `main()`.
const List<String> childModeHiveBoxes = <String>[
  'activities',
  'progress_records',
  'gamification_data',
  'mood_entries',
];

/// Open the deferred child-mode boxes.
///
/// Idempotent: boxes already open are skipped, so this is safe to call from
/// both app bootstrap and child-mode route entry without double-opening. The
/// four boxes are opened in parallel.
Future<void> openChildModeBoxes() async {
  await Future.wait(
    childModeHiveBoxes.map((name) async {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox<dynamic>(name);
      }
    }),
  );
}
