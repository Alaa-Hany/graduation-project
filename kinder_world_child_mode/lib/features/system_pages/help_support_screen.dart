import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/models/faq_item.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/services/content_service.dart';
import 'package:kinder_world/router.dart';

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  late Future<List<FaqItem>> _faqFuture;

  @override
  void initState() {
    super.initState();
    _faqFuture = ref.read(contentServiceProvider).getFaq();
  }

  List<FaqItem> _fallbackFaqs(AppLocalizations l10n) {
    return [
      FaqItem(id: '1', question: l10n.helpFaqQ1, answer: l10n.helpFaqA1),
      FaqItem(id: '2', question: l10n.helpFaqQ2, answer: l10n.helpFaqA2),
      FaqItem(id: '3', question: l10n.helpFaqQ3, answer: l10n.helpFaqA3),
      FaqItem(id: '4', question: l10n.helpFaqQ4, answer: l10n.helpFaqA4),
      FaqItem(id: '5', question: l10n.helpFaqQ5, answer: l10n.helpFaqA5),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: AppBackButton(
          fallback: Routes.parentDashboard,
          color: colors.onSurface,
          icon: Icons.arrow_back,
          iconSize: 24,
        ),
        title: Text(
          AppLocalizations.of(context)!.helpSupportTitle,
          style: textTheme.titleMedium?.copyWith(
            fontSize: AppConstants.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Icon(
                        Icons.help_outline,
                        size: 30,
                        color: colors.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.helpNeedHelpTitle,
                            style: textTheme.titleLarge?.copyWith(
                              fontSize: AppConstants.largeFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            AppLocalizations.of(context)!.weAreHereToSupportYou,
                            style: textTheme.bodyMedium?.copyWith(
                              fontSize: 16,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // FAQ Section
              Text(
                AppLocalizations.of(context)!.helpFaqTitle,
                style: textTheme.titleMedium?.copyWith(
                  fontSize: AppConstants.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<FaqItem>>(
                future: _faqFuture,
                builder: (context, snapshot) {
                  final items = snapshot.data?.isNotEmpty == true
                      ? snapshot.data!
                      : _fallbackFaqs(AppLocalizations.of(context)!);
                  return Column(
                    children: [
                      for (var index = 0; index < items.length; index++) ...[
                        _FAQItem(
                          question: items[index].question,
                          answer: items[index].answer,
                        ),
                        if (index != items.length - 1) const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 32),

              // Contact Support
              Text(
                AppLocalizations.of(context)!.helpContactSupportTitle,
                style: textTheme.titleMedium?.copyWith(
                  fontSize: AppConstants.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _ContactOption(
                      icon: Icons.email,
                      title: AppLocalizations.of(context)!.emailSupport,
                      subtitle: 'support@kinderworld.app',
                      onTap: () {
                        // Open email client
                      },
                    ),
                    const SizedBox(height: 16),
                    _ContactOption(
                      icon: Icons.chat,
                      title: AppLocalizations.of(context)!.liveChat,
                      subtitle: AppLocalizations.of(context)!.available247,
                      onTap: () {
                        // Open chat
                      },
                    ),
                    const SizedBox(height: 16),
                    _ContactOption(
                      icon: Icons.phone,
                      title: AppLocalizations.of(context)!.phoneSupport,
                      subtitle: AppLocalizations.of(context)!.phoneNumber,
                      onTap: () {
                        // Make phone call
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Additional Resources
              Text(
                AppLocalizations.of(context)!.additionalResources,
                style: textTheme.titleMedium?.copyWith(
                  fontSize: AppConstants.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _ResourceItem(
                      icon: Icons.description,
                      title: AppLocalizations.of(context)!.helpUserGuide,
                      onTap: () {
                        context.go('/legal?type=guide');
                      },
                    ),
                    const SizedBox(height: 16),
                    _ResourceItem(
                      icon: Icons.privacy_tip,
                      title:
                          AppLocalizations.of(context)!.privacyPolicyResource,
                      onTap: () {
                        context.go('/legal?type=privacy');
                      },
                    ),
                    const SizedBox(height: 16),
                    _ResourceItem(
                      icon: Icons.gavel,
                      title:
                          AppLocalizations.of(context)!.termsOfServiceResource,
                      onTap: () {
                        context.go('/legal?type=terms');
                      },
                    ),
                    const SizedBox(height: 16),
                    _ResourceItem(
                      icon: Icons.update,
                      title: AppLocalizations.of(context)!.helpAppUpdates,
                      onTap: () {
                        // Check for updates
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // App version
              Center(
                child: Text(
                  AppLocalizations.of(context)!
                      .appVersionLabel(AppConstants.appVersion),
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 14,
                    color: colors.onSurfaceVariant,
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

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: textTheme.titleSmall?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 24,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                widget.answer,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 14,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              icon,
              size: 24,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 14,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 24,
            color: colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _ResourceItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ResourceItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.secondaryContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 20,
              color: colors.secondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 16,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 24,
            color: colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
