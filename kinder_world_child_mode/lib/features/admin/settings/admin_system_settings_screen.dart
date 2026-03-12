import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_subscription_models.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';
import 'package:kinder_world/features/admin/shared/admin_state_widgets.dart';

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
          // ── Header ──────────────────────────────────────────────────
          AdminPageHeader(
            title: l10n.adminSystemSettingsTitle,
            subtitle: l10n.adminSystemSettingsSubtitle,
            actions: [
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.retry),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_loading)
            const AdminLoadingState()
          else if (_error != null)
            AdminErrorState(message: _error!, onRetry: _load)
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
        text: defaults['default_child_limit']?.toString() ?? '1');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section: Global Toggles ──────────────────────────────────
        _SectionHeader(
          icon: Icons.tune_rounded,
          label: l10n.adminSettingsFeatureFlagsTitle,
          color: cs.primary,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.build_rounded, size: 18, color: cs.error),
                ),
                title: Text(l10n.adminSettingsMaintenanceMode,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                subtitle: Text(l10n.adminSettingsMaintenanceModeHint,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
                value: effective['maintenance_mode'] as bool? ?? false,
                onChanged: (v) => _save({'maintenance_mode': v}),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.how_to_reg_rounded,
                      size: 18, color: cs.primary),
                ),
                title: Text(l10n.adminSettingsRegistrationEnabled,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                subtitle: Text(l10n.adminSettingsRegistrationEnabledHint,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
                value: effective['registration_enabled'] as bool? ?? true,
                onChanged: (v) => _save({'registration_enabled': v}),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.smart_toy_outlined,
                      size: 18, color: cs.tertiary),
                ),
                title: Text(l10n.adminSettingsAiBuddyEnabled,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                subtitle: Text(l10n.adminSettingsAiBuddyEnabledHint,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
                value: effective['ai_buddy_enabled'] as bool? ?? true,
                onChanged: (v) => _save({'ai_buddy_enabled': v}),
              ),
            ],
          ),
        ),

        // ── Section: Feature Flags ───────────────────────────────────
        if (featureFlags.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionHeader(
            icon: Icons.flag_outlined,
            label: l10n.adminSettingsFeatureFlagsTitle,
            color: cs.secondary,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: featureFlags.entries.map((entry) {
                final isLast = entry.key == featureFlags.keys.last;
                return Column(
                  children: [
                    SwitchListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      title: Text(entry.key,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500)),
                      value: entry.value as bool? ?? false,
                      onChanged: (v) {
                        final updated = Map<String, dynamic>.from(featureFlags)
                          ..[entry.key] = v;
                        _save({'feature_flags': updated});
                      },
                    ),
                    if (!isLast)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                );
              }).toList(),
            ),
          ),
        ],

        // ── Section: Defaults ────────────────────────────────────────
        const SizedBox(height: 24),
        _SectionHeader(
          icon: Icons.settings_suggest_outlined,
          label: l10n.adminSettingsDefaultsTitle,
          color: cs.tertiary,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: defaultPlanController,
                  decoration: InputDecoration(
                    labelText: l10n.adminSettingsDefaultPlanLabel,
                    prefixIcon: const Icon(Icons.card_membership_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: childLimitController,
                  decoration: InputDecoration(
                    labelText: l10n.adminSettingsDefaultChildLimitLabel,
                    prefixIcon: const Icon(Icons.child_care_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _save({
                      'defaults': {
                        'default_plan': defaultPlanController.text
                                .trim()
                                .isEmpty
                            ? 'FREE'
                            : defaultPlanController.text.trim().toUpperCase(),
                        'default_child_limit':
                            int.tryParse(childLimitController.text.trim()) ?? 1,
                      }
                    }),
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text(l10n.save),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────── Section Header ───────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
