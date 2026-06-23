import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/ai_buddy_models.dart';
import 'package:kinder_world/core/providers/ai_buddy_provider.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';

/// Shows AI Buddy safety interventions for a single child on the parent
/// safety dashboard: how many fired in the last 7 days, plus an expandable
/// list of the most recent ones. Best-effort — if the request fails it simply
/// renders the empty state.
class AiBuddySafetyAlertsCard extends ConsumerStatefulWidget {
  const AiBuddySafetyAlertsCard({
    super.key,
    required this.childId,
    required this.childName,
  });

  final int childId;
  final String childName;

  @override
  ConsumerState<AiBuddySafetyAlertsCard> createState() =>
      _AiBuddySafetyAlertsCardState();
}

class _AiBuddySafetyAlertsCardState
    extends ConsumerState<AiBuddySafetyAlertsCard> {
  Future<AiBuddySafetyAlerts>? _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(aiBuddyServiceProvider).getChildSafetyAlerts(
          childId: widget.childId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return ParentCard(
      child: FutureBuilder<AiBuddySafetyAlerts>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting;
          final recentCount = data == null
              ? 0
              : data.alertsSince(
                  DateTime.now().subtract(const Duration(days: 7)),
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ParentSectionHeader(
                      title: l10n.aiBuddySafetyAlertsTitle,
                      subtitle: widget.childName,
                    ),
                  ),
                  if (data != null)
                    ParentStatusBadge(
                      status: recentCount > 0
                          ? ParentBadgeStatus.alert
                          : ParentBadgeStatus.active,
                      label:
                          '$recentCount • ${l10n.aiBuddySafetyAlertsLast7Days}',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (isLoading && data == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (data == null || data.alerts.isEmpty)
                Text(
                  l10n.aiBuddySafetyAlertsEmpty,
                  style: TextStyle(color: colors.onSurfaceVariant),
                )
              else
                _AlertsExpansion(alerts: data.alerts),
            ],
          );
        },
      ),
    );
  }
}

class _AlertsExpansion extends StatelessWidget {
  const _AlertsExpansion({required this.alerts});

  final List<AiBuddySafetyAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final recent = alerts.take(5).toList();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          l10n.aiBuddySafetyAlertsViewAll,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        children: recent.map((alert) => _AlertRow(alert: alert)).toList(),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert});

  final AiBuddySafetyAlert alert;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final isRefusal = alert.classification == 'needs_refusal';
    final color = isRefusal ? context.warningColor : context.infoColor;
    final label =
        isRefusal ? l10n.aiBuddyAlertBlocked : l10n.aiBuddyAlertRedirected;
    final time = alert.occurredAt != null
        ? DateFormat('MMM d, h:mm a').format(alert.occurredAt!)
        : '';
    final topic = (alert.topic ?? '').replaceAll('_', ' ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRefusal ? Icons.block_rounded : Icons.alt_route_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontSize: 13,
                      ),
                    ),
                    if (topic.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '• $topic',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
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
