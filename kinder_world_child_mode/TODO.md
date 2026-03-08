# i18n Full Refactoring TODO

## Phase 1: Add missing localization keys
- [ ] 1.1 Add new abstract getters to `app_localizations.dart`
- [ ] 1.2 Add EN implementations to `app_localizations_en.dart`
- [ ] 1.3 Complete ALL Arabic translations in `app_localizations_ar.dart`

## Phase 2: Replace hardcoded strings in screens
- [ ] 2.1 `splash_screen.dart` — "Kinder World", "Learn • Play • Grow"
- [ ] 2.2 `welcome_screen.dart` — "Kinder World", "Learn. Play. Grow.", feature descriptions
- [ ] 2.3 `router.dart` — error/fallback messages
- [ ] 2.4 `no_internet_screen.dart` — all hardcoded strings
- [ ] 2.5 `error_screen.dart` — all hardcoded strings
- [ ] 2.6 `maintenance_screen.dart` — all hardcoded strings
- [ ] 2.7 `legal_screen.dart` — all hardcoded strings
- [ ] 2.8 `help_support_screen.dart` — all hardcoded strings
- [ ] 2.9 `data_sync_screen.dart` — all hardcoded strings
- [ ] 2.10 `parent_pin_screen.dart` — all hardcoded strings
- [ ] 2.11 `child_header.dart` — "Hello, $name", "Level $level", "Friend"
- [ ] 2.12 `auth_design_system.dart` — password strength labels
- [ ] 2.13 `subject_screen.dart` — subject names, lesson data, labels
- [ ] 2.14 `lesson_flow_screen.dart` — all hardcoded strings
- [ ] 2.15 `coloring_gallery_screen.dart` — all hardcoded strings
- [ ] 2.16 `ai_buddy_screen.dart` — UI labels (not AI responses)
- [ ] 2.17 `child_login_screen.dart` — validation messages
- [ ] 2.18 `theme_palette.dart` — palette names (use localized names in UI)

## Phase 3: Verification
- [ ] 3.1 Run flutter analyze
- [ ] 3.2 Document remaining manual-review items
