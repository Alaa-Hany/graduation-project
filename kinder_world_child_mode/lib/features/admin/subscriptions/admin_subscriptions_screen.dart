import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_subscription_models.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';

class AdminSubscriptionsScreen extends ConsumerStatefulWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  ConsumerState<AdminSubscriptionsScreen> createState() =>
      _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState
    extends ConsumerState<AdminSubscriptionsScreen> {
  bool _loading = true;
  String? _error;
  List<AdminSubscriptionRecord> _items = const [];
  Map<String, dynamic> _pagination = const {};
  AdminSubscriptionRecord? _selected;
  String _search = '';
  String _status = '';
  String _plan = '';
  int _page = 1;

  List<DropdownMenuItem<String>> _planItems(AppLocalizations l10n) => [
        DropdownMenuItem(
          value: 'FREE',
          child: Text(l10n.adminPlanFree),
        ),
        DropdownMenuItem(
          value: 'PREMIUM',
          child: Text(l10n.adminPlanPremium),
        ),
        DropdownMenuItem(
          value: 'FAMILY_PLUS',
          child: Text(l10n.adminPlanFamilyPlus),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? selectId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await ref.read(adminManagementRepositoryProvider).fetchSubscriptions(
                search: _search,
                status: _status,
                plan: _plan,
                page: _page,
              );
      AdminSubscriptionRecord? selected = _selected;
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
      if (selected != null) {
        selected = await ref
            .read(adminManagementRepositoryProvider)
            .fetchSubscriptionDetail(selected.id);
      }
      if (!mounted) return;
      setState(() {
        _items = response.items;
        _pagination = response.pagination;
        _selected = selected;
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
            content: Text(
              l10n.adminSubscriptionsCancelConfirm,
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.adminSubscriptionsCancelAction)),
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
              ? (l10n.adminSubscriptionsRefundNotSupported)
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
              Text(l10n.adminSubscriptionsTitle,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(l10n.adminSubscriptionsSubtitle),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 240,
                    child: TextFormField(
                      initialValue: _search,
                      decoration: InputDecoration(
                          labelText: l10n.adminSubscriptionsSearchLabel),
                      onFieldSubmitted: (value) {
                        setState(() {
                          _search = value.trim();
                          _page = 1;
                        });
                        _load();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: InputDecoration(
                          labelText: l10n.adminSubscriptionsStatusFilter),
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
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      initialValue: _plan,
                      decoration: InputDecoration(
                          labelText: l10n.adminSubscriptionsPlanFilter),
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
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retry),
                  ),
                ],
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
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!)))
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.adminPaginationSummary(
                      (_pagination['page'] as int?) ?? _page,
                      (_pagination['total_pages'] as int?) ?? 1,
                      (_pagination['total'] as int?) ?? _items.length,
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed:
                            ((_pagination['has_previous'] as bool?) ?? false)
                                ? () {
                                    setState(() => _page -= 1);
                                    _load();
                                  }
                                : null,
                        child: Text(l10n.adminPaginationPrevious),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: ((_pagination['has_next'] as bool?) ?? false)
                            ? () {
                                setState(() => _page += 1);
                                _load();
                              }
                            : null,
                        child: Text(l10n.adminPaginationNext),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: _items.map((item) {
        final selected = _selected?.id == item.id;
        return Card(
          color: selected
              ? Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.35)
              : null,
          child: ListTile(
            onTap: () => _load(selectId: item.id),
            title: Text(item.email),
            subtitle: Text('${item.plan} أ¢â‚¬آ¢ ${item.status}\n${item.name}'),
            isThreeLine: true,
            trailing: _PlanChip(plan: item.plan),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetail(BuildContext context, AppLocalizations l10n, admin) {
    final item = _selected;
    if (item == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.adminSubscriptionsNoSelection),
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
            Row(children: [
              Expanded(
                  child: Text(item.email,
                      style: Theme.of(context).textTheme.titleLarge)),
              _PlanChip(plan: item.plan),
            ]),
            const SizedBox(height: 12),
            Text(
                '${l10n.adminSubscriptionsUserName}: ${item.name.isEmpty ? 'أ¢â‚¬â€‌' : item.name}'),
            Text('${l10n.adminSubscriptionsStatusLabel}: ${item.status}'),
            Text(
                '${l10n.adminSubscriptionsChildrenMetric}: ${item.childCount}'),
            Text(
                '${l10n.adminSubscriptionsPaymentMethodsMetric}: ${item.paymentMethodCount}'),
            const SizedBox(height: 16),
            Text(l10n.adminSubscriptionsFeaturesTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...item.features.entries
                .take(8)
                .map((entry) => Text('${entry.key}: ${entry.value}')),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: canOverride ? _overridePlan : null,
                  child: Text(l10n.adminSubscriptionsOverrideAction),
                ),
                OutlinedButton(
                  onPressed: canOverride ? _cancelSubscription : null,
                  child: Text(l10n.adminSubscriptionsCancelAction),
                ),
                OutlinedButton(
                  onPressed: canOverride ? _refundSubscription : null,
                  child: Text(l10n.adminSubscriptionsRefundAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.plan});

  final String plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = plan == 'FREE'
        ? scheme.secondaryContainer
        : plan == 'PREMIUM'
            ? scheme.tertiaryContainer
            : scheme.primaryContainer;
    final foreground = plan == 'FREE'
        ? scheme.secondary
        : plan == 'PREMIUM'
            ? scheme.tertiary
            : scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(plan,
          style: TextStyle(color: foreground, fontWeight: FontWeight.w700)),
    );
  }
}
