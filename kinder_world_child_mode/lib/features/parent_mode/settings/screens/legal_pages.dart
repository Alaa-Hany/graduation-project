import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';

class ParentTermsScreen extends StatelessWidget {
  const ParentTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _ParentLegalPage(
      title: l10n.legalTermsTitle,
      endpoint: '/legal/terms',
      placeholder: l10n.legalTermsPlaceholder,
      style: _LegalPageStyle.terms,
    );
  }
}

class ParentPrivacyPolicyScreen extends StatelessWidget {
  const ParentPrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _ParentLegalPage(
      title: l10n.legalPrivacyTitle,
      endpoint: '/legal/privacy',
      placeholder: l10n.legalPrivacyPlaceholder,
      style: _LegalPageStyle.privacy,
    );
  }
}

class ParentCoppaScreen extends StatelessWidget {
  const ParentCoppaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _ParentLegalPage(
      title: l10n.legalCoppaTitle,
      endpoint: '/legal/coppa',
      placeholder: l10n.legalCoppaPlaceholder,
      style: _LegalPageStyle.coppa,
    );
  }
}

class _ParentLegalPage extends ConsumerWidget {
  final String title;
  final String endpoint;
  final String placeholder;
  final _LegalPageStyle style;

  const _ParentLegalPage({
    required this.title,
    required this.endpoint,
    required this.placeholder,
    required this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final config = style.config(AppLocalizations.of(context)!);

    return Scaffold(
      backgroundColor: config.baseBackground,
      appBar: AppBar(
        backgroundColor: config.baseBackground,
        elevation: 0,
        title: Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            fontSize: AppConstants.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colors.onSurface),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: ref
              .read(networkServiceProvider)
              .get<Map<String, dynamic>>(endpoint)
              .then((value) => value.data ?? {}),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final body = snapshot.data?['body']?.toString();
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroCard(
                    title: config.heroTitle,
                    subtitle: config.heroSubtitle,
                    icon: config.heroIcon,
                    accent: config.accent,
                    gradient: config.heroGradient,
                  ),
                  const SizedBox(height: 18),
                  _SectionCard(
                    title: config.sectionTitle,
                    icon: config.sectionIcon,
                    accent: config.accent,
                    child: body == null || body.isEmpty
                        ? _EmptyState(
                            message: placeholder,
                            accent: config.accent,
                            textColor: colors.onSurfaceVariant,
                          )
                        : Text(
                            body,
                            style: textTheme.bodyMedium?.copyWith(
                              fontSize: 16,
                              height: 1.6,
                              color: colors.onSurface,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  _GuidanceRow(
                    icon: config.footerIcon,
                    text: config.footerText,
                    accent: config.accent,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _LegalPageStyle { terms, privacy, coppa }

class _LegalStyleConfig {
  final Color baseBackground;
  final Color accent;
  final Gradient heroGradient;
  final IconData heroIcon;
  final String heroTitle;
  final String heroSubtitle;
  final String sectionTitle;
  final IconData sectionIcon;
  final IconData footerIcon;
  final String footerText;

  const _LegalStyleConfig({
    required this.baseBackground,
    required this.accent,
    required this.heroGradient,
    required this.heroIcon,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.sectionTitle,
    required this.sectionIcon,
    required this.footerIcon,
    required this.footerText,
  });
}

extension _LegalStyleConfigExt on _LegalPageStyle {
  _LegalStyleConfig config(AppLocalizations l10n) {
    switch (this) {
      case _LegalPageStyle.terms:
        return _LegalStyleConfig(
          baseBackground: const Color(0xFFF8F4EF),
          accent: const Color(0xFF9A3F1C),
          heroGradient: const LinearGradient(
            colors: [
             Color(0xFFFFE2CF),
             Color(0xFFF6D1C1)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          heroIcon: Icons.rule,
          heroTitle: l10n.legalTermsHeroTitle,
          heroSubtitle: l10n.legalTermsHeroSubtitle,
          sectionTitle: l10n.legalTermsSectionTitle,
          sectionIcon: Icons.fact_check,
          footerIcon: Icons.verified_user,
          footerText: l10n.legalTermsFooterText,
        );
      case _LegalPageStyle.privacy:
        return _LegalStyleConfig(
          baseBackground: const Color(0xFFF3F8FF),
          accent: const Color(0xFF1F6FEB),
          heroGradient: const LinearGradient(
            colors: [
               Color(0xFFDDEBFF),
               Color(0xFFCDE0FF)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          heroIcon: Icons.shield_moon,
          heroTitle: l10n.legalPrivacyHeroTitle,
          heroSubtitle: l10n.legalPrivacyHeroSubtitle,
          sectionTitle: l10n.legalPrivacySectionTitle,
          sectionIcon: Icons.lock_outline,
          footerIcon: Icons.visibility_outlined,
          footerText: l10n.legalPrivacyFooterText,
        );
      case _LegalPageStyle.coppa:
        return _LegalStyleConfig(
          baseBackground: const Color(0xFFF4FFF6),
          accent: const Color(0xFF2E7D32),
          heroGradient: const LinearGradient(
            colors: [
               Color(0xFFD7F5DD),
               Color(0xFFC5EED0)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          heroIcon: Icons.child_friendly,
          heroTitle: l10n.legalCoppaHeroTitle,
          heroSubtitle: l10n.legalCoppaHeroSubtitle,
          sectionTitle: l10n.legalCoppaSectionTitle,
          sectionIcon: Icons.policy_outlined,
          footerIcon: Icons.family_restroom,
          footerText: l10n.legalCoppaFooterText,
        );
    }
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Gradient gradient;

  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final Color accent;
  final Color textColor;

  const _EmptyState({
    required this.message,
    required this.accent,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.description_outlined, color: accent, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context)!.legalNoContent,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: textColor,
                height: 1.5,
              ),
        ),
      ],
    );
  }
}

class _GuidanceRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;

  const _GuidanceRow({
    required this.icon,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
