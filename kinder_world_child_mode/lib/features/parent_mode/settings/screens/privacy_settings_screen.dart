import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/privacy_settings.dart';
import 'package:kinder_world/core/providers/privacy_provider.dart';

class ParentPrivacySettingsScreen extends ConsumerStatefulWidget {
  const ParentPrivacySettingsScreen({super.key});

  @override
  ConsumerState<ParentPrivacySettingsScreen> createState() =>
      _ParentPrivacySettingsScreenState();
}

class _ParentPrivacySettingsScreenState
    extends ConsumerState<ParentPrivacySettingsScreen> {
  PrivacySettings? _localSettings;
  bool _saving = false;

  Future<void> _updateSettings(PrivacySettings next) async {
    if (_saving) return;
    final previous = _localSettings;
    setState(() {
      _saving = true;
      _localSettings = next;
    });

    final success =
        await ref.read(privacyControllerProvider.notifier).updateSettings(next);
    if (!mounted) return;
    if (!success) {
      setState(() {
        _localSettings = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.error)),
      );
    } else {
      ref.invalidate(privacyProvider);
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
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
          final current = _localSettings ?? privacySettings;
          _localSettings ??= privacySettings;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                SwitchListTile(
                  title: Text(l10n.analyticsTitle),
                  subtitle: Text(l10n.analyticsSubtitle),
                  value: current.analyticsEnabled,
                  onChanged: _saving
                      ? null
                      : (value) => _updateSettings(
                            current.copyWith(analyticsEnabled: value),
                          ),
                ),
                const Divider(),
                SwitchListTile(
                  title: Text(l10n.personalizedRecommendationsTitle),
                  subtitle: Text(l10n.personalizedRecommendationsSubtitle),
                  value: current.personalizedRecommendations,
                  onChanged: _saving
                      ? null
                      : (value) => _updateSettings(
                            current.copyWith(
                              personalizedRecommendations: value,
                            ),
                          ),
                ),
                const Divider(),
                SwitchListTile(
                  title: Text(l10n.dataCollectionOptOutTitle),
                  subtitle: Text(l10n.dataCollectionOptOutSubtitle),
                  value: current.dataCollectionOptOut,
                  onChanged: _saving
                      ? null
                      : (value) => _updateSettings(
                            current.copyWith(dataCollectionOptOut: value),
                          ),
                ),
                if (_saving) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                const SizedBox(height: 32),
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
