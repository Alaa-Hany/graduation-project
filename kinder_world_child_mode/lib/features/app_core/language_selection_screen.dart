import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/providers/locale_provider.dart';
import 'package:kinder_world/core/providers/app_launch_provider.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/auth_design_system.dart';
import 'package:kinder_world/router.dart';

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectLanguage(String code) {
    ref.read(localeProvider.notifier).setLanguageCode(code);
  }

  Future<void> _continue() async {
    final currentLocale = ref.read(localeProvider);
    await ref
        .read(appLaunchProvider)
        .ensureLocaleSaved(currentLocale.languageCode);
    if (!mounted) return;
    context.go(Routes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final auth = context.authTheme;
    final textTheme = context.text;

    return Scaffold(
      backgroundColor: auth.pageBackground,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 48),

                  // Brand mark + globe icon
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: auth.brand.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Icon(
                        Icons.language_rounded,
                        size: 52,
                        color: auth.brand,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  Text(
                    l10n.chooseLanguageTitle,
                    style: textTheme.displayMedium?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: auth.textPrimary,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),

                  Text(
                    l10n.chooseLanguageSubtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      color: auth.textMuted,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Language cards
                  _LanguageCard(
                    flag: '🇺🇸',
                    name: l10n.english,
                    nativeName: 'English',
                    isSelected: currentLocale.languageCode == 'en',
                    onTap: () => _selectLanguage('en'),
                  ),
                  const SizedBox(height: 16),
                  _LanguageCard(
                    flag: '🇸🇦',
                    name: l10n.arabic,
                    nativeName: 'العربية',
                    isSelected: currentLocale.languageCode == 'ar',
                    onTap: () => _selectLanguage('ar'),
                  ),

                  const SizedBox(height: 40),

                  // Continue button
                  AuthPrimaryButton(
                    label: l10n.continueText,
                    onPressed: _continue,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String flag;
  final String name;
  final String nativeName;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.flag,
    required this.name,
    required this.nativeName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.authTheme;
    final textTheme = context.text;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? auth.brand.withValues(alpha: 0.06)
            : context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? auth.brand : auth.inputBorder,
          width: isSelected ? 2.0 : 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: auth.brand.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              // Flag emoji
              Text(flag, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 16),

              // Names
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nativeName,
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? auth.brand : auth.textPrimary,
                      ),
                    ),
                    Text(
                      name,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: auth.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Check indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? auth.brand : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? auth.brand : auth.inputBorder,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: context.colors.onPrimary,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
