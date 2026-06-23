import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_cms_models.dart';
import 'package:kinder_world/core/models/admin_subscription_models.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_control_center_panel.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';
import 'package:kinder_world/features/admin/shared/admin_state_widgets.dart';
import 'package:kinder_world/core/utils/color_compat.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/router.dart';

class AdminSystemSettingsScreen extends ConsumerStatefulWidget {
  const AdminSystemSettingsScreen({super.key});

  @override
  ConsumerState<AdminSystemSettingsScreen> createState() =>
      _AdminSystemSettingsScreenState();
}

class _AdminSystemSettingsScreenState
    extends ConsumerState<AdminSystemSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  AdminSystemSettingsPayload? _payload;
  List<AdminCmsAxisSummary> _axes = const [];

  final TextEditingController _defaultPlanController = TextEditingController();
  final TextEditingController _childLimitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _defaultPlanController.dispose();
    _childLimitController.dispose();
    super.dispose();
  }

  void _syncDefaultControllers(AdminSystemSettingsPayload payload) {
    final effective = payload.effective;
    final defaults = effective['defaults'] is Map
        ? Map<String, dynamic>.from(effective['defaults'] as Map)
        : <String, dynamic>{};
    _defaultPlanController.text = defaults['default_plan']?.toString() ?? 'FREE';
    _childLimitController.text =
        defaults['default_child_limit']?.toString() ?? '1';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(adminManagementRepositoryProvider);
      final results = await Future.wait<dynamic>([
        repo.fetchAdminSettings(),
        repo.fetchCmsCatalog(),
      ]);
      final payload = results[0] as AdminSystemSettingsPayload;
      final catalog = results[1] as AdminCmsCatalogResponse;
      if (!mounted) return;
      _syncDefaultControllers(payload);
      setState(() {
        _payload = payload;
        _axes = catalog.axes;
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
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      final payload = await ref
          .read(adminManagementRepositoryProvider)
          .updateAdminSettings(updates);
      if (!mounted) return;
      _syncDefaultControllers(payload);
      setState(() {
        _payload = payload;
        _saving = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminSettingsSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.adminSettingsSaveFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final admin = ref.watch(currentAdminProvider);
    if (!(admin?.hasPermission('admin.settings.edit') ?? false)) {
      return const AdminPermissionPlaceholder();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final contextActions = [
      AdminControlCenterAction(
        icon: Icons.auto_stories_outlined,
        label: l10n.adminSidebarContent,
        route: Routes.adminContent,
        accent: colorScheme.tertiaryContainer,
      ),
      AdminControlCenterAction(
        icon: Icons.people_outline,
        label: l10n.adminSidebarUsers,
        route: Routes.adminUsers,
        accent: colorScheme.primaryContainer,
      ),
      AdminControlCenterAction(
        icon: Icons.insights_outlined,
        label: l10n.adminSidebarReports,
        route: Routes.adminReports,
        accent: colorScheme.secondaryContainer,
      ),
      AdminControlCenterAction(
        icon: Icons.workspace_premium_outlined,
        label: l10n.adminSidebarSubscriptions,
        route: Routes.adminSubscriptions,
        accent: colorScheme.surfaceContainerHigh,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          AdminControlCenterPanel(
            title: l10n.adminDashboard,
            actions: contextActions,
            axes: _axes,
            categoriesLabel: l10n.adminCmsCategoriesTab,
            contentsLabel: l10n.adminCmsContentsTab,
            quizzesLabel: l10n.adminCmsQuizzesTab,
            onAxisTap: (_) => context.go(Routes.adminContent),
          ),
          if (contextActions.isNotEmpty || _axes.isNotEmpty)
            const SizedBox(height: 24),
          if (_loading)
            const AdminLoadingState()
          else if (_error != null)
            AdminErrorState(message: _error!, onRetry: _load)
          else if (_payload != null)
            _buildSettings(context, l10n, _payload!)
          else
            AdminEmptyState(message: l10n.noSettingsFound),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                title: Text(
                  l10n.adminSettingsMaintenanceMode,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  l10n.adminSettingsMaintenanceModeHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValuesCompat(alpha: 0.6),
                  ),
                ),
                value: effective['maintenance_mode'] as bool? ?? false,
                onChanged: _saving
                    ? null
                    : (value) => _save({'maintenance_mode': value}),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.how_to_reg_rounded,
                    size: 18,
                    color: cs.primary,
                  ),
                ),
                title: Text(
                  l10n.adminSettingsRegistrationEnabled,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  l10n.adminSettingsRegistrationEnabledHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValuesCompat(alpha: 0.6),
                  ),
                ),
                value: effective['registration_enabled'] as bool? ?? true,
                onChanged: _saving
                    ? null
                    : (value) => _save({'registration_enabled': value}),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.smart_toy_outlined,
                    size: 18,
                    color: cs.tertiary,
                  ),
                ),
                title: Text(
                  l10n.adminSettingsAiBuddyEnabled,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  l10n.adminSettingsAiBuddyEnabledHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValuesCompat(alpha: 0.6),
                  ),
                ),
                value: effective['ai_buddy_enabled'] as bool? ?? true,
                onChanged: _saving
                    ? null
                    : (value) => _save({'ai_buddy_enabled': value}),
              ),
            ],
          ),
        ),
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
                      title: Text(
                        entry.key,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      value: entry.value as bool? ?? false,
                      onChanged: _saving
                          ? null
                          : (value) {
                              final updated =
                                  Map<String, dynamic>.from(featureFlags)
                                    ..[entry.key] = value;
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
                  controller: _defaultPlanController,
                  decoration: InputDecoration(
                    labelText: l10n.adminSettingsDefaultPlanLabel,
                    prefixIcon: const Icon(Icons.card_membership_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _childLimitController,
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
                    onPressed: _saving
                        ? null
                        : () => _save({
                              'defaults': {
                                'default_plan':
                                    _defaultPlanController.text.trim().isEmpty
                                        ? 'FREE'
                                        : _defaultPlanController.text
                                            .trim()
                                            .toUpperCase(),
                                'default_child_limit': int.tryParse(
                                        _childLimitController.text.trim()) ??
                                    1,
                              },
                            }),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
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
