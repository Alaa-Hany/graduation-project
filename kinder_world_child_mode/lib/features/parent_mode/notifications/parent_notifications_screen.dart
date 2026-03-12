import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/providers/plan_provider.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/core/widgets/plan_status_banner.dart';
import 'package:kinder_world/core/widgets/premium_section_upsell.dart';
import 'package:kinder_world/features/parent_mode/notifications/parent_notification_entry.dart';
import 'package:kinder_world/features/parent_mode/notifications/parent_notification_service.dart';

class ParentNotificationsScreen extends ConsumerStatefulWidget {
  const ParentNotificationsScreen({super.key});

  @override
  ConsumerState<ParentNotificationsScreen> createState() =>
      _ParentNotificationsScreenState();
}

class _ParentNotificationsScreenState
    extends ConsumerState<ParentNotificationsScreen> {
  Future<List<ParentNotificationEntry>>? _notificationsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notificationsFuture ??= _fetchNotifications();
  }

  Future<List<ParentNotificationEntry>> _fetchNotifications() async {
    final parentId = ref.read(currentUserProvider)?.id;
    final l10n = AppLocalizations.of(context)!;
    if (parentId == null || parentId.isEmpty) return const [];
    return ref.read(parentNotificationServiceProvider).loadNotifications(
          parentId: parentId,
          l10n: l10n,
        );
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _notificationsFuture = _fetchNotifications();
    });
    await _notificationsFuture!;
  }

  Future<void> _markAllRead(List<ParentNotificationEntry> entries) async {
    await ref.read(parentNotificationServiceProvider).markAllRead(entries);
    if (!mounted) return;
    setState(() {
      _notificationsFuture = _fetchNotifications();
    });
  }

  Future<void> _markRead(ParentNotificationEntry entry) async {
    await ref.read(parentNotificationServiceProvider).markRead(entry);
    if (!mounted) return;
    setState(() {
      _notificationsFuture = _fetchNotifications();
    });
  }

  String _formatTime(AppLocalizations l10n, DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} ${l10n.hoursAgo}';
    return '${diff.inDays} ${l10n.daysAgo}';
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
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: colors.onSurface,
          ),
          onPressed: () => context.appBack(fallback: '/parent/dashboard'),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<ParentNotificationEntry>>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            final notifications = snapshot.data ?? const <ParentNotificationEntry>[];
            return Column(
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.notificationsSubtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (notifications.isNotEmpty)
                            TextButton(
                              onPressed: () => _markAllRead(notifications),
                              child: Text(l10n.markAllRead),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: Builder(
                      builder: (context) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
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
                            return _NotificationCard(
                              notification: notification,
                              timeLabel: _formatTime(l10n, notification.createdAt),
                              onTap: () => _markRead(notification),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.timeLabel,
    required this.onTap,
  });

  final ParentNotificationEntry notification;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: notification.isRead
              ? colors.surface
              : colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead
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
                color: _getTypeColor(context, notification.type).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                _getTypeIcon(notification.type),
                size: 24,
                color: _getTypeColor(context, notification.type),
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
                          notification.title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: notification.isRead
                                ? FontWeight.w600
                                : FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: context.parentTheme.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.body,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        timeLabel,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'LESSON_COMPLETED':
        return Icons.school_rounded;
      case 'STREAK_REACHED':
        return Icons.local_fire_department_rounded;
      case 'INACTIVITY_REMINDER':
        return Icons.schedule_rounded;
      case 'SCREEN_TIME_LIMIT':
        return Icons.timer_off_rounded;
      case 'SUPPORT_TICKET_UPDATE':
        return Icons.support_agent_rounded;
      case 'SUBSCRIPTION_UPDATED':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.notifications;
    }
  }

  Color _getTypeColor(BuildContext context, String type) {
    final parent = context.parentTheme;
    switch (type.toUpperCase()) {
      case 'LESSON_COMPLETED':
        return parent.info;
      case 'STREAK_REACHED':
        return parent.warning;
      case 'INACTIVITY_REMINDER':
        return parent.danger;
      case 'SCREEN_TIME_LIMIT':
        return parent.danger;
      case 'SUPPORT_TICKET_UPDATE':
        return parent.primary;
      case 'SUBSCRIPTION_UPDATED':
        return parent.reward;
      default:
        return parent.primary;
    }
  }
}
