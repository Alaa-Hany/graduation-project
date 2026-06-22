import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/providers/plan_provider.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/core/widgets/plan_status_banner.dart';
import 'package:kinder_world/core/widgets/premium_badge.dart';
import 'package:kinder_world/core/widgets/premium_section_upsell.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/router.dart';
import 'package:kinder_world/core/utils/color_compat.dart';

class ParentalControlsScreen extends ConsumerStatefulWidget {
  const ParentalControlsScreen({super.key});

  @override
  ConsumerState<ParentalControlsScreen> createState() =>
      _ParentalControlsScreenState();
}

class _ParentalControlsScreenState
    extends ConsumerState<ParentalControlsScreen> {
  bool _sleepMode = true;
  String _bedtime = '20:00';
  String _wakeTime = '07:00';
  bool _isLoading = true;

  // Full settings map loaded from the backend. Preserved on save so we never
  // drop required fields (daily_limit_enabled, hours_per_day, ...).
  Map<String, dynamic> _settings = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _loadControls();
  }

  Future<void> _loadControls() async {
    try {
      final response = await ref
          .read(networkServiceProvider)
          .get<Map<String, dynamic>>('/parental-controls/settings');
      final data = response.data?['settings'];
      if (data is Map) {
        setState(() {
          _settings = Map<String, dynamic>.from(data);
          _sleepMode = data['sleep_mode'] == true;
          _bedtime = _normalizeTime(data['bedtime']?.toString() ?? _bedtime);
          _wakeTime = _normalizeTime(data['wake_time']?.toString() ?? _wakeTime);
        });
      }
    } catch (_) {
      if (mounted) {
        _showNetworkError();
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveControls() async {
    try {
      await ref.read(networkServiceProvider).put<Map<String, dynamic>>(
        '/parental-controls/settings',
        // Merge the edited fields into the full settings map so required
        // fields (daily_limit_enabled, hours_per_day, ...) are kept intact.
        data: {
          ..._settings,
          'sleep_mode': _sleepMode,
          'bedtime': _bedtime,
          'wake_time': _wakeTime,
        },
      );
    } catch (_) {
      if (mounted) {
        _showNetworkError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final planAsync = ref.watch(planInfoStateProvider);
    final isAdvancedLocked = planAsync.when(
      data: (plan) => !plan.hasSmartControls,
      loading: () => false,
      error: (_, __) => false,
    );
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: AppBackButton(
          fallback: Routes.parentDashboard,
          color: colors.onSurface,
        ),
        title: Text(
          l10n.parentalControls,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
              height: 1,
              color: colors.outlineVariant.withValuesCompat(alpha: 0.4)),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoading)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(
                          color: ParentColors.parentGreenLight,
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.contentRestrictionsAndScreenTime,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.manageChildAccess,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const PlanStatusBanner(),
                    const SizedBox(height: 24),

                    _buildControlSection(
                      l10n.timeRestrictions,
                      Icons.access_time,
                      [
                        _buildToggleSetting(
                          l10n.sleepMode,
                          _sleepMode,
                          (value) {
                            setState(() => _sleepMode = value);
                            _saveControls();
                          },
                        ),
                        _buildTimeSetting(l10n.bedtime, _bedtime,
                            isBedtime: true),
                        _buildTimeSetting(l10n.wakeTime, _wakeTime,
                            isBedtime: false),
                      ],
                      trailing: const PremiumBadge(),
                      isDimmed: isAdvancedLocked,
                      footer: isAdvancedLocked
                          ? PremiumSectionUpsell(
                              title: l10n.planFeatureInPremium,
                              description: l10n.smartControl,
                              buttonLabel: l10n.upgradeNow,
                              showBadge: false,
                              padding: const EdgeInsets.all(12),
                            )
                          : null,
                    ),

                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlSection(
    String title,
    IconData icon,
    List<Widget> controls, {
    Widget? trailing,
    bool isDimmed = false,
    Widget? footer,
  }) {
    return Opacity(
      opacity: isDimmed ? 0.6 : 1.0,
      child: ParentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color:
                        ParentColors.parentGreen.withValuesCompat(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: ParentColors.parentGreen, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 16),
            Column(children: controls),
            if (footer != null) ...[
              const SizedBox(height: 12),
              footer,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToggleSetting(
      String title, bool value, ValueChanged<bool> onChanged,
      {bool enabled = true}) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: textTheme.bodyMedium,
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            thumbColor: WidgetStateProperty.resolveWith(
              (states) =>
                  states.contains(WidgetState.selected) ? colors.primary : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSetting(String title, String time,
      {required bool isBedtime}) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: textTheme.bodyMedium,
          ),
          TextButton(
            onPressed: () {
              _showTimePicker(
                isBedtime,
                (value) {
                  setState(() {
                    if (isBedtime) {
                      _bedtime = value;
                    } else {
                      _wakeTime = value;
                    }
                  });
                  _saveControls();
                },
              );
            },
            child: Text(
              time,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Every half hour across the full 24-hour day, formatted as "HH:MM".
  static List<String> _timeOptions() {
    final options = <String>[];
    for (var hour = 0; hour < 24; hour++) {
      for (final minute in const [0, 30]) {
        options.add(
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
        );
      }
    }
    return options;
  }

  /// Normalizes a stored time into 24-hour "HH:MM". Accepts both 24-hour
  /// values and legacy 12-hour values like "8:00 PM".
  static String _normalizeTime(String value) {
    final text = value.trim();
    final ampm =
        RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$').firstMatch(text);
    if (ampm != null) {
      var hour = int.parse(ampm.group(1)!);
      final minute = int.parse(ampm.group(2)!);
      final isPm = ampm.group(3)!.toUpperCase() == 'PM';
      if (hour == 12) hour = 0;
      if (isPm) hour += 12;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
    final hhmm = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
    if (hhmm != null) {
      final hour = int.parse(hhmm.group(1)!);
      final minute = int.parse(hhmm.group(2)!);
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
    return text;
  }

  void _showTimePicker(bool isBedtime, ValueChanged<String> onSelected) {
    final options = _timeOptions();
    final current = isBedtime ? _bedtime : _wakeTime;
    final selectedIndex = options.indexOf(current);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            // Scroll so the current selection is roughly centered on open.
            controller: ScrollController(
              initialScrollOffset:
                  selectedIndex > 2 ? (selectedIndex - 2) * 64.0 : 0,
            ),
            itemCount: options.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final value = options[index];
              final isSelected = value == current;
              return ListTile(
                title: Text(value),
                trailing: isSelected
                    ? Icon(Icons.check, color: colors.primary)
                    : null,
                onTap: () {
                  onSelected(value);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showNetworkError() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.connectionError)),
    );
  }
}
