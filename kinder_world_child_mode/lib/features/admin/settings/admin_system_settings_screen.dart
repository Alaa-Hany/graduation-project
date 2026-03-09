import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_subscription_models.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';

class AdminSystemSettingsScreen extends ConsumerStatefulWidget {
  const AdminSystemSettingsScreen({super.key});

  @override
  ConsumerState<AdminSystemSettingsScreen> createState() =>
      _AdminSystemSettingsScreenState();
}

class _AdminSystemSettingsScreenState
    extends ConsumerState<AdminSystemSettingsScreen> {
  bool _loading = true;
  String? _error;
  AdminSystemSettingsPayload? _payload;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await ref
          .read(adminManagementRepositoryProvider)
          .fetchAdminSettings();
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save(Map<String, dynamic> updates) async {
    final payload = await ref
        .read(adminManagementRepositoryProvider)
        .updateAdminSettings(updates);
    if (!mounted) return;
    setState(() => _payload = payload);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final admin = ref.watch(currentAdminProvider);
    if (!(admin?.hasPermission('admin.settings.edit') ?? false)) {
      return const AdminPermissionPlaceholder();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminSystemSettingsTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.adminSystemSettingsSubtitle,
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16), child: Text(_error!)))
          else if (_payload != null)
            _buildSettings(context, l10n, _payload!),
        ],
      ),
    );
  }

  Widget _buildSettings(
    BuildContext context,
    AppLocalizations l10n,
    AdminSystemSettingsPayload payload,
  ) {
    final effective = payload.effective;
    final featureFlags = effective['feature_flags'] is Map
        ? Map<String, dynamic>.from(effective['feature_flags'] as Map)
        : <String, dynamic>{};
    final defaults = effective['defaults'] is Map
        ? Map<String, dynamic>.from(effective['defaults'] as Map)
        : <String, dynamic>{};
    final defaultPlanController = TextEditingController(
        text: defaults['default_plan']?.toString() ?? 'FREE');
    final childLimitController = TextEditingController(
      text: defaults['default_child_limit']?.toString() ?? '1',
    );

    return Column(
      children: [
        Card(
          child: SwitchListTile(
            title: Text(l10n.adminSettingsMaintenanceMode),
            subtitle: Text(l10n.adminSettingsMaintenanceModeHint),
            value: effective['maintenance_mode'] as bool? ?? false,
            onChanged: (value) => _save({'maintenance_mode': value}),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            title: Text(l10n.adminSettingsRegistrationEnabled),
            subtitle: Text(l10n.adminSettingsRegistrationEnabledHint),
            value: effective['registration_enabled'] as bool? ?? true,
            onChanged: (value) => _save({'registration_enabled': value}),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            title: Text(l10n.adminSettingsAiBuddyEnabled),
            subtitle: Text(l10n.adminSettingsAiBuddyEnabledHint),
            value: effective['ai_buddy_enabled'] as bool? ?? true,
            onChanged: (value) => _save({'ai_buddy_enabled': value}),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.adminSettingsFeatureFlagsTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ...featureFlags.entries.map(
                  (entry) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.key),
                    value: entry.value as bool? ?? false,
                    onChanged: (value) {
                      final updated = Map<String, dynamic>.from(featureFlags)
                        ..[entry.key] = value;
                      _save({'feature_flags': updated});
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.adminSettingsDefaultsTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: defaultPlanController,
                  decoration: InputDecoration(
                    labelText: l10n.adminSettingsDefaultPlanLabel,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: childLimitController,
                  decoration: InputDecoration(
                    labelText: l10n.adminSettingsDefaultChildLimitLabel,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _save({
                    'defaults': {
                      'default_plan': defaultPlanController.text.trim().isEmpty
                          ? 'FREE'
                          : defaultPlanController.text.trim().toUpperCase(),
                      'default_child_limit':
                          int.tryParse(childLimitController.text.trim()) ?? 1,
                    }
                  }),
                  child: Text(l10n.save),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
