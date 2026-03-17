import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/services/content_service.dart';
import 'package:kinder_world/router.dart';

class ParentAboutScreen extends ConsumerStatefulWidget {
  const ParentAboutScreen({super.key});

  @override
  ConsumerState<ParentAboutScreen> createState() => _ParentAboutScreenState();
}

class _ParentAboutScreenState extends ConsumerState<ParentAboutScreen> {
  late final Future<PackageInfo> _packageInfo;
  late Future<String> _aboutTextFuture;

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
    _aboutTextFuture = _fetchAbout();
  }

  Future<String> _fetchAbout() async {
    return ref.read(contentServiceProvider).getAbout();
  }

  void _openLegal(String type) {
    switch (type) {
      case 'terms':
        context.push(Routes.parentTerms);
        break;
      case 'privacy':
        context.push(Routes.parentPrivacyPolicy);
        break;
      case 'coppa':
        context.push(Routes.parentCoppa);
        break;
      default:
        context.push(Routes.parentTerms);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.parentAbout),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Icon(Icons.school, size: 80, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              l10n.aboutAppName,
              style: textTheme.titleLarge?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<PackageInfo>(
              future: _packageInfo,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    l10n.versionBuildLabel(
                      snapshot.data!.version,
                      snapshot.data!.buildNumber,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                return Text(l10n.loadingVersion);
              },
            ),
            const SizedBox(height: 20),
            FutureBuilder<String>(
              future: _aboutTextFuture,
              builder: (context, snapshot) {
                final raw = snapshot.data;
                final text = (raw == null)
                    ? l10n.loading
                    : raw.isEmpty
                        ? l10n.aboutFallbackText
                        : raw;
                return Text(
                  text,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                );
              },
            ),
            const Spacer(),
            _LegalButton(
              title: l10n.termsOfService,
              onTap: () => _openLegal('terms'),
            ),
            const SizedBox(height: 10),
            _LegalButton(
              title: l10n.privacyPolicy,
              onTap: () => _openLegal('privacy'),
            ),
            const SizedBox(height: 10),
            _LegalButton(
              title: l10n.legalCoppaTitle,
              onTap: () => _openLegal('coppa'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _LegalButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _LegalButton({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        child: Text(title),
      ),
    );
  }
}
