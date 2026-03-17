import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_subscription_models.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_filter_bar.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';
import 'package:kinder_world/features/admin/shared/admin_state_widgets.dart';
import 'package:kinder_world/features/admin/shared/admin_table_widgets.dart';

class AdminSubscriptionsScreen extends ConsumerStatefulWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  ConsumerState<AdminSubscriptionsScreen> createState() =>
      _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState
    extends ConsumerState<AdminSubscriptionsScreen> {
  bool _loading = true;
  bool _detailLoading = false;
  String? _error;
  String? _detailError;
  List<AdminSubscriptionRecord> _items = const [];
  Map<String, dynamic> _pagination = const {};
  AdminSubscriptionRecord? _selected;
  String _search = '';
  String _status = '';
  String _plan = '';
  int _page = 1;

  final _searchController = TextEditingController();

  List<DropdownMenuItem<String>> _planItems(AppLocalizations l10n) => [
        DropdownMenuItem(value: 'FREE', child: Text(l10n.adminPlanFree)),
        DropdownMenuItem(value: 'PREMIUM', child: Text(l10n.adminPlanPremium)),
        DropdownMenuItem(
            value: 'FAMILY_PLUS', child: Text(l10n.familyPlanLabel)),
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '—';
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    return DateFormat('MMM d, y • h:mm a').format(parsed);
  }

  String _formatAmount(int amountCents, String currency) {
    return '${(amountCents / 100).toStringAsFixed(2)} ${currency.toUpperCase()}';
  }

  String _displayStatus(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Future<void> _load({int? selectId}) async {
    setState(() {
      _loading = true;
      _error = null;
      _detailError = null;
    });
    try {
      final repository = ref.read(adminManagementRepositoryProvider);
      final response = await repository.fetchSubscriptions(
        search: _search,
        status: _status,
        plan: _plan,
        page: _page,
      );
      AdminSubscriptionRecord? selected;
      final targetId = selectId ?? _selected?.id;
      if (targetId != null) {
        for (final item in response.items) {
          if (item.id == targetId) {
            selected = item;
            break;
          }
        }
      }
      selected ??= response.items.isNotEmpty ? response.items.first : null;
      if (!mounted) return;
      setState(() {
        _items = response.items;
        _pagination = response.pagination;
        _selected = selected;
        _loading = false;
        _detailLoading = false;
      });
      if (selected != null) {
        await _selectSubscription(selected.id, quiet: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _detailLoading = false;
      });
    }
  }

  Future<void> _selectSubscription(int subscriptionId,
      {bool quiet = false}) async {
    final placeholder = _items.cast<AdminSubscriptionRecord?>().firstWhere(
          (item) => item?.id == subscriptionId,
          orElse: () => _selected,
        );
    if (mounted) {
      setState(() {
        _selected = placeholder;
        _detailLoading = true;
        _detailError = null;
        _error = quiet ? _error : null;
      });
    }
    try {
      final detail = await ref
          .read(adminManagementRepositoryProvider)
          .fetchSubscriptionDetail(subscriptionId);
      if (!mounted) return;
      setState(() {
        _selected = detail;
        _detailLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detailError = e.toString();
        _detailLoading = false;
      });
    }
  }

  Future<void> _overridePlan() async {
    final l10n = AppLocalizations.of(context)!;
    final subscription = _selected;
    if (subscription == null) return;
    String plan = subscription.plan;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(l10n.adminSubscriptionsOverrideTitle),
              content: DropdownButtonFormField<String>(
                initialValue: plan,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _planItems(l10n),
                onChanged: (value) =>
                    setDialogState(() => plan = value ?? 'FREE'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.save),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref
        .read(adminManagementRepositoryProvider)
        .overrideSubscriptionPlan(subscription.id, plan);
    if (!mounted) return;
    await _load(selectId: subscription.id);
  }

  Future<void> _cancelSubscription() async {
    final l10n = AppLocalizations.of(context)!;
    final subscription = _selected;
    if (subscription == null) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.adminSubscriptionsCancelTitle),
            content: Text(l10n.adminSubscriptionsCancelConfirm),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel)),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.adminSubscriptionsCancelAction),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref
        .read(adminManagementRepositoryProvider)
        .cancelSubscription(subscription.id);
    if (!mounted) return;
    await _load(selectId: subscription.id);
  }

  Future<void> _refundSubscription() async {
    final l10n = AppLocalizations.of(context)!;
    final subscription = _selected;
    if (subscription == null) return;
    final message = await ref
        .read(adminManagementRepositoryProvider)
        .refundSubscription(subscription.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message.isEmpty
              ? l10n.adminSubscriptionsRefundNotSupported
              : message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final admin = ref.watch(currentAdminProvider);
    if (!(admin?.hasPermission('admin.subscription.view') ?? false)) {
      return const AdminPermissionPlaceholder();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page header ─────────────────────────────────────────
              AdminPageHeader(
                title: l10n.adminSubscriptionsTitle,
                subtitle: l10n.adminSubscriptionsSubtitle,
                actions: [
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Filters ─────────────────────────────────────────────
              AdminFilterBar(
                children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: l10n.adminSubscriptionsSearchLabel,
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onSubmitted: (value) {
                        setState(() {
                          _search = value.trim();
                          _page = 1;
                        });
                        _load();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: l10n.adminSubscriptionsStatusFilter,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: '',
                            child: Text(l10n.adminSubscriptionsStatusAll)),
                        DropdownMenuItem(
                            value: 'active',
                            child: Text(l10n.adminSubscriptionsStatusActive)),
                        DropdownMenuItem(
                            value: 'free',
                            child: Text(l10n.adminSubscriptionsStatusFree)),
                        DropdownMenuItem(
                            value: 'disabled',
                            child: Text(l10n.adminSubscriptionsStatusDisabled)),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _status = value ?? '';
                          _page = 1;
                        });
                        _load();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _plan,
                      isExpanded: true,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: l10n.adminSubscriptionsPlanFilter,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: '',
                            child: Text(l10n.adminSubscriptionsPlanAll)),
                        ..._planItems(l10n),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _plan = value ?? '';
                          _page = 1;
                        });
                        _load();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Content ─────────────────────────────────────────────
              if (_loading)
                const AdminLoadingState()
              else if (_error != null)
                AdminErrorState(message: _error!, onRetry: _load)
              else if (_items.isEmpty)
                AdminEmptyState(
                  message: l10n.adminSubscriptionsNoItems,
                  icon: Icons.subscriptions_outlined,
                )
              else if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _buildList(context, l10n)),
                    const SizedBox(width: 16),
                    Expanded(
                        flex: 4, child: _buildDetail(context, l10n, admin)),
                  ],
                )
              else ...[
                _buildList(context, l10n),
                const SizedBox(height: 16),
                _buildDetail(context, l10n, admin),
              ],
              const SizedBox(height: 16),

              // ── Pagination ──────────────────────────────────────────
              AdminPaginationBar(
                summary: l10n.adminPaginationSummary(
                  (_pagination['page'] as int?) ?? _page,
                  (_pagination['total_pages'] as int?) ?? 1,
                  (_pagination['total'] as int?) ?? _items.length,
                ),
                hasPrevious: (_pagination['has_previous'] as bool?) ?? false,
                hasNext: (_pagination['has_next'] as bool?) ?? false,
                previousLabel: l10n.adminPaginationPrevious,
                nextLabel: l10n.adminPaginationNext,
                onPrevious: () {
                  setState(() => _page -= 1);
                  _load();
                },
                onNext: () {
                  setState(() => _page += 1);
                  _load();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: _items.map((item) {
        final isSelected = _selected?.id == item.id;
        return Card(
          elevation: isSelected ? 2 : 0,
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.35)
              : colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isSelected
                ? BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.4),
                    width: 1.5)
                : BorderSide.none,
          ),
          child: ListTile(
            onTap: () => _selectSubscription(item.id),
            leading: CircleAvatar(
              backgroundColor: colorScheme.secondaryContainer,
              child: Text(
                item.email.isNotEmpty ? item.email[0].toUpperCase() : '?',
                style: TextStyle(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            title: Text(
              item.email,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              item.name.isEmpty ? item.status : '${item.name} • ${item.status}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            trailing: _PlanChip(plan: item.plan),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetail(BuildContext context, AppLocalizations l10n, admin) {
    final item = _selected;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (item == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AdminEmptyState(
            message: l10n.adminSubscriptionsNoSelection,
            icon: Icons.subscriptions_outlined,
          ),
        ),
      );
    }

    if (_detailLoading) {
      return const Card(
        child: AdminLoadingState(padding: EdgeInsets.all(24)),
      );
    }

    if (_detailError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AdminErrorState(
            message: _detailError!,
            onRetry: () => _selectSubscription(item.id),
          ),
        ),
      );
    }

    final canOverride =
        admin?.hasPermission('admin.subscription.override') ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.email,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                _PlanChip(plan: item.plan),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.name.isEmpty ? '-' : item.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Divider(height: 24),

            // ── Info rows ────────────────────────────────────────────
            _InfoRow(
              icon: Icons.info_outline_rounded,
              label: l10n.adminSubscriptionsStatusLabel,
              value: item.status,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.child_care_outlined,
              label: l10n.adminSubscriptionsChildrenMetric,
              value: '${item.childCount}',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.payment_outlined,
              label: l10n.adminSubscriptionsPaymentMethodsMetric,
              value: '${item.paymentMethodCount}',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.sync_alt_rounded,
                    size: 18, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Lifecycle',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.flag_circle_outlined,
              label: 'Current status',
              value: _displayStatus(item.lifecycle.status),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.play_circle_outline_rounded,
              label: 'Started at',
              value: _formatDate(item.lifecycle.startedAt),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.event_available_outlined,
              label: 'Expires at',
              value: _formatDate(item.lifecycle.expiresAt),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.event_busy_outlined,
              label: 'Cancel at',
              value: _formatDate(item.lifecycle.cancelAt),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.autorenew_rounded,
              label: 'Will renew',
              value: item.lifecycle.willRenew ? 'Yes' : 'No',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.credit_score_rounded,
              label: 'Last payment',
              value: _displayStatus(item.lifecycle.lastPaymentStatus),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.cloud_done_outlined,
              label: 'Provider',
              value: item.lifecycle.provider,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                  icon: Icons.timeline_rounded,
                  label: 'Events',
                  value: '${item.historySummary.eventCount}',
                ),
                _MetricChip(
                  icon: Icons.receipt_long_rounded,
                  label: 'Transactions',
                  value: '${item.historySummary.billingTransactionCount}',
                ),
                _MetricChip(
                  icon: Icons.credit_card_rounded,
                  label: 'Attempts',
                  value: '${item.historySummary.paymentAttemptCount}',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Features ─────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.featured_play_list_outlined,
                    size: 18, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  l10n.adminSubscriptionsFeaturesTitle,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.features.entries.take(8).map((entry) {
                final isEnabled = entry.value == true ||
                    entry.value.toString().toLowerCase() == 'true';
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isEnabled
                            ? Icons.check_circle_outline_rounded
                            : Icons.cancel_outlined,
                        size: 13,
                        color: isEnabled
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        entry.key,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isEnabled
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _TimelineSection(
              title: 'Recent Events',
              icon: Icons.event_note_rounded,
              children: item.recentEvents
                  .take(8)
                  .map((event) => _TimelineEntry(
                        title:
                            '${_displayStatus(event.eventType)} • ${event.planId}',
                        subtitle:
                            '${_displayStatus(event.status)} • ${event.source}',
                        trailing: _formatDate(event.occurredAt),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            _TimelineSection(
              title: 'Billing History',
              icon: Icons.receipt_rounded,
              children: item.billingHistory
                  .take(8)
                  .map((entry) => _TimelineEntry(
                        title:
                            '${_displayStatus(entry.transactionType)} • ${entry.planId}',
                        subtitle:
                            '${_formatAmount(entry.amountCents, entry.currency)} • ${_displayStatus(entry.status)}',
                        trailing: _formatDate(entry.effectiveAt),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            _TimelineSection(
              title: 'Payment Attempts',
              icon: Icons.payments_outlined,
              children: item.paymentAttempts
                  .take(8)
                  .map((entry) => _TimelineEntry(
                        title:
                            '${_displayStatus(entry.attemptType)} • ${entry.planId}',
                        subtitle: [
                          _formatAmount(entry.amountCents, entry.currency),
                          _displayStatus(entry.status),
                          if ((entry.failureCode ?? '').isNotEmpty)
                            entry.failureCode!,
                        ].join(' • '),
                        trailing:
                            _formatDate(entry.completedAt ?? entry.requestedAt),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // ── Actions ──────────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: canOverride ? _overridePlan : null,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: Text(l10n.adminSubscriptionsOverrideAction),
                ),
                OutlinedButton.icon(
                  onPressed: canOverride ? _cancelSubscription : null,
                  icon: Icon(Icons.cancel_outlined,
                      size: 18, color: colorScheme.error),
                  label: Text(
                    l10n.adminSubscriptionsCancelAction,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: canOverride ? _refundSubscription : null,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: Text(l10n.adminSubscriptionsRefundAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Info Row ────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon,
            size: 16, color: colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style:
              theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ─────────────────────────── Plan Chip ───────────────────────────────────────

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.plan});

  final String plan;

  @override
  Widget build(BuildContext context) {
    final normalized = plan.trim().toUpperCase();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final isFree = normalized == 'FREE';
    final isFamily = normalized == 'FAMILY_PLUS';
    final display = isFree
        ? l10n.adminPlanFree
        : isFamily
            ? l10n.familyPlanLabel
            : l10n.planPremium;
    final background = isFree
        ? scheme.secondaryContainer
        : isFamily
            ? scheme.primaryContainer
            : scheme.tertiaryContainer;
    final foreground = isFree
        ? scheme.secondary
        : isFamily
            ? scheme.primary
            : scheme.tertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        display,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (children.isEmpty)
          Text(
            'No records yet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          )
        else
          Column(children: children),
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              trailing,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
