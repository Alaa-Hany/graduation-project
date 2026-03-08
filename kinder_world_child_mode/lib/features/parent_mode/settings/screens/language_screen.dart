import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/providers/locale_provider.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';

class ParentLanguageScreen extends ConsumerStatefulWidget {
  const ParentLanguageScreen({super.key});

  @override
  ConsumerState<ParentLanguageScreen> createState() =>
      _ParentLanguageScreenState();
}

class _ParentLanguageScreenState extends ConsumerState<ParentLanguageScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentLocale = ref.watch(localeProvider);

    final languages = [
      {
        'code': 'en',
        'name': l10n.english,
        'flag': 'EN',
      },
      {
        'code': 'ar',
        'name': l10n.arabic,
        'flag': 'AR',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.language),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chooseLanguageSubtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              ...languages.map((language) {
                final isSelected = currentLocale.languageCode == language['code'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: () {
                      ref
                          .read(localeProvider.notifier)
                          .setLanguageCode(language['code']!);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? colors.primary : colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? colors.primary
                              : colors.outlineVariant,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              // Flag
                              Text(
                                language['flag']!,
                                style: const TextStyle(fontSize: 32),
                              ),
                              const SizedBox(width: 16),

                              // Language Name
                              Text(
                                language['name']!,
                                style: TextStyle(
                                  fontSize: AppConstants.fontSize,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? colors.onPrimary
                                      : colors.onSurface,
                                ),
                              ),
                            ],
                          ),

                          // Selection Indicator
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? colors.onPrimary
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? colors.onPrimary
                                    : colors.onSurfaceVariant,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    size: 16,
                                    color: colors.primary,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    context.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    l10n.continueText,
                    style: const TextStyle(
                      fontSize: AppConstants.fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
