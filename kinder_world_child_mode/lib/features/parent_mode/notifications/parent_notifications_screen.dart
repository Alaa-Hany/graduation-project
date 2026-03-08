import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';
import 'package:kinder_world/core/providers/plan_provider.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/core/widgets/plan_status_banner.dart';
import 'package:kinder_world/core/widgets/premium_section_upsell.dart';

class ParentNotificationsScreen extends ConsumerStatefulWidget {
  const ParentNotificationsScreen({super.key});

  @override
  ConsumerState<ParentNotificationsScreen> createState() =>
      _ParentNotificationsScreenState();
}

class _ParentNotificationsScreenState
    extends ConsumerState<ParentNotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _fetchNotifications();
  }

  Future<List<Map<String, dynamic>>> _fetchNotifications() async {
    try {
      final response =
          await ref.read(networkServiceProvider).get<Map<String, dynamic>>(
                '/notifications',
              );
      final data = response.data;
      if (data == null) return [];
      final list = data['notifications'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _markAllRead() async {
    await ref.read(networkServiceProvider).post<Map<String, dynamic>>(
          '/notifications/mark-all-read',
        );
    if (!mounted) return;
    setState(() {
      _notificationsFuture = _fetchNotifications();
    });
  }

  Future<void> _markRead(String id) async {
    await ref
        .read(networkServiceProvider)
        .post<Map<String, dynamic>>('/notifications/$id/read');
    if (!mounted) return;
    setState(() {
      _notificationsFuture = _fetchNotifications();
    });
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '';
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final plan =
        ref.watch(planInfoProvider).asData?.value ?? PlanInfo.fromTier(PlanTier.free);
    final isSmartLocked = !plan.hasAiInsights;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: colors.onSurface),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/parent/dashboard');
            }
          },
        ),
        title: Text(
          l10n.notifications,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: Text(
              l10n.markAllRead,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                children: [
                  const PlanStatusBanner(),
                  if (isSmartLocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: PremiumSectionUpsell(
                        title: l10n.recommendedForYou,
                        description: l10n.planAiInsightsPro,
                        buttonLabel: l10n.upgradeNow,
                        showBadge: true,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _notificationsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  final notifications = snapshot.data ?? [];
                  if (notifications.isEmpty) {
                    return ParentEmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: l10n.noNotifications,
                      subtitle: l10n.allCaughtUp,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final isRead = notification['is_read'] == true;
                      return _NotificationCard(
                        notification: notification,
                        isRead: isRead,
                        timeLabel: _formatTime(
                          notification['created_at']?.toString(),
                        ),
                        onTap: () => _markRead(
                          notification['id'].toString(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final bool isRead;
  final String timeLabel;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.isRead,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final type = notification['type']?.toString() ?? 'info';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isRead ? colors.surface : colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? colors.outlineVariant
                : colors.primary.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getTypeColor(type).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                _getTypeIcon(type),
                size: 24,
                color: _getTypeColor(type),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification['title']?.toString() ?? l10n.notificationFallback,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: ParentColors.parentGreenLight,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification['body']?.toString() ?? '',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (timeLabel.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      timeLabel,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'achievement':
        return Icons.emoji_events;
      case 'report':
        return Icons.bar_chart;
      case 'milestone':
        return Icons.flag;
      default:
        return Icons.notifications;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'warning':
        return ParentColors.alertRed;
      case 'achievement':
        return ParentColors.parentGreenLight;
      case 'report':
        return ParentColors.infoBlue;
      case 'milestone':
        return ParentColors.streakOrange;
      default:
        return ParentColors.parentGreen;
    }
  }
}
