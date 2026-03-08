import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_audit_log.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';

class AdminAuditLogsScreen extends ConsumerStatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  ConsumerState<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends ConsumerState<AdminAuditLogsScreen> {
  final _adminIdController = TextEditingController();
  final _actionController = TextEditingController();
  final _dateFromController = TextEditingController();
  final _dateToController = TextEditingController();
  int _page = 1;
  bool _loading = true;
  String? _error;
  List<AdminAuditLog> _logs = const [];
  Map<String, dynamic> _pagination = const {};

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _adminIdController.dispose();
    _actionController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(adminManagementRepositoryProvider).fetchAuditLogs(
            adminId: _adminIdController.text.trim(),
            action: _actionController.text.trim(),
            dateFrom: _dateFromController.text.trim(),
            dateTo: _dateToController.text.trim(),
            page: _page,
          );
      if (!mounted) return;
      setState(() {
        _logs = response.items;
        _pagination = response.pagination;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final admin = ref.watch(currentAdminProvider);
    if (!(admin?.hasPermission('admin.audit.view') ?? false)) {
      return const AdminPermissionPlaceholder();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.adminAuditTitle ?? 'Audit logs',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(l10n?.adminAuditSubtitle ?? 'Review sensitive admin actions and trace system changes.'),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _adminIdController,
                  decoration: InputDecoration(
                    labelText: l10n?.adminAuditAdminFilter ?? 'Admin ID',
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _actionController,
                  decoration: InputDecoration(
                    labelText: l10n?.adminAuditActionFilter ?? 'Action',
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _dateFromController,
                  decoration: InputDecoration(
                    labelText: l10n?.adminAuditDateFromFilter ?? 'Date from',
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _dateToController,
                  decoration: InputDecoration(
                    labelText: l10n?.adminAuditDateToFilter ?? 'Date to',
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  _page = 1;
                  _loadLogs();
                },
                icon: const Icon(Icons.search),
                label: Text(l10n?.adminAuditApplyFilters ?? 'Apply filters'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ))
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!),
              ),
            )
          else
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(l10n?.adminAuditActionColumn ?? 'Action')),
                    DataColumn(label: Text(l10n?.adminAuditEntityColumn ?? 'Entity')),
                    DataColumn(label: Text(l10n?.adminAuditAdminColumn ?? 'Admin')),
                    DataColumn(label: Text(l10n?.adminAuditTimeColumn ?? 'Timestamp')),
                    DataColumn(label: Text(l10n?.adminAuditNetworkColumn ?? 'IP / Agent')),
                  ],
                  rows: _logs
                      .map(
                        (log) => DataRow(
                          cells: [
                            DataCell(Text(log.action)),
                            DataCell(Text('${log.entityType} #${log.entityId}')),
                            DataCell(Text(log.admin?['email'] as String? ?? '—')),
                            DataCell(Text(log.timestamp ?? '—')),
                            DataCell(
                              SizedBox(
                                width: 320,
                                child: Text(
                                  '${log.ipAddress ?? '—'}\n${log.userAgent ?? ''}',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.adminPaginationSummary(
                      (_pagination['page'] as int?) ?? _page,
                      (_pagination['total_pages'] as int?) ?? 1,
                      (_pagination['total'] as int?) ?? _logs.length,
                    ) ??
                    'Page ${(_pagination['page'] as int?) ?? _page}',
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: ((_pagination['has_previous'] as bool?) ?? false)
                        ? () {
                            setState(() => _page -= 1);
                            _loadLogs();
                          }
                        : null,
                    child: Text(l10n?.adminPaginationPrevious ?? 'Previous'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: ((_pagination['has_next'] as bool?) ?? false)
                        ? () {
                            setState(() => _page += 1);
                            _loadLogs();
                          }
                        : null,
                    child: Text(l10n?.adminPaginationNext ?? 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
