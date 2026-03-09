# Flutter Cleanup & Optimization TODO — ✅ ALL COMPLETE

## Status Legend
- [ ] Pending
- [x] Done

---

## 1. Fix authControllerProvider — remove .autoDispose
- [x] `lib/core/providers/auth_controller.dart` — changed `StateNotifierProvider.autoDispose` → `StateNotifierProvider`

## 2. Fix DataSyncScreen — remove unnecessary ConsumerStatefulWidget
- [x] `lib/features/system_pages/data_sync_screen.dart` — ConsumerStatefulWidget → StatefulWidget, removed flutter_riverpod import

## 3. Fix HelpSupportScreen — remove unnecessary ConsumerWidget
- [x] `lib/features/system_pages/help_support_screen.dart` — ConsumerWidget → StatelessWidget, removed flutter_riverpod import

## 4. Fix LegalScreen — cache FutureBuilder future to prevent rebuild recreation
- [x] `lib/features/system_pages/legal_screen.dart` — converted to ConsumerStatefulWidget, future cached in initState, refresh button triggers setState

## 5. Fix child_home_screen — cache daily goal future
- [x] `lib/features/child_mode/home/child_home_screen.dart` — cached loadTodayProgress future in `_dailyGoalFuture` state field, set via addPostFrameCallback in initState

## 6. Mark dead-code files
- [x] `lib/core/providers/activity_filter_controller.dart` — added dead-code header comment
- [x] `lib/core/providers/child_sync_provider.dart` — added dead-code header comment
- [x] `lib/core/providers/content_provider.dart` — added dead-code header comment
- [x] `lib/core/widgets/theme_mode_toggle.dart` — added dead-code header comment
- [x] `lib/core/widgets/premium_upsell_section.dart` — added dead-code header comment (empty file)

## 7. Run flutter analyze
- [x] Executed `flutter analyze --no-fatal-infos` → **No issues found!** (ran in 4.6s)
