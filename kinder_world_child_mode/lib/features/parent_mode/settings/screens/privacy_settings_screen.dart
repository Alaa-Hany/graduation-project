import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/providers/privacy_provider.dart';

class ParentPrivacySettingsScreen extends ConsumerWidget {
  const ParentPrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacyState = ref.watch(privacyProvider);
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.parentPrivacySettings),
        elevation: 0,
      ),
      body: privacyState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.privacySettingsError),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(privacyProvider),
                child: Text(l10n.retryAction),
              ),
            ],
          ),
        ),
        data: (privacySettings) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // Analytics toggle
                SwitchListTile(
                  title: Text(l10n.analyticsTitle),
                  subtitle: Text(l10n.analyticsSubtitle),
                  value: privacySettings.analyticsEnabled,
                  onChanged: (value) {
                    ref.read(privacyControllerProvider.notifier).updateSettings(
                          privacySettings.copyWith(
                            analyticsEnabled: value,
                          ),
                        );
                  },
                ),
                const Divider(),

                // Personalized recommendations toggle
                SwitchListTile(
                  title: Text(l10n.personalizedRecommendationsTitle),
                  subtitle: Text(l10n.personalizedRecommendationsSubtitle),
                  value: privacySettings.personalizedRecommendations,
                  onChanged: (value) {
                    ref.read(privacyControllerProvider.notifier).updateSettings(
                          privacySettings.copyWith(
                            personalizedRecommendations: value,
                          ),
                        );
                  },
                ),
                const Divider(),

                // Data collection opt-out toggle
                SwitchListTile(
                  title: Text(l10n.dataCollectionOptOutTitle),
                  subtitle: Text(l10n.dataCollectionOptOutSubtitle),
                  value: privacySettings.dataCollectionOptOut,
                  onChanged: (value) {
                    ref.read(privacyControllerProvider.notifier).updateSettings(
                          privacySettings.copyWith(
                            dataCollectionOptOut: value,
                          ),
                        );
                  },
                ),

                const SizedBox(height: 32),

                // Info section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    border: Border.all(color: colors.primary),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.privacyInfoTitle,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.privacyInfoBody,
                        style: textTheme.bodySmall?.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
