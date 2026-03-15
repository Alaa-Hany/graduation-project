import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_audit_log.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_filter_bar.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';
import 'package:kinder_world/features/admin/shared/admin_state_widgets.dart';
import 'package:kinder_world/features/admin/shared/admin_table_widgets.dart';

class AdminAuditLogsScreen extends ConsumerStatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  ConsumerState<AdminAuditLogsScreen> createState() =>
      _AdminAuditLogsScreenState();
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
      final response =
          await ref.read(adminManagementRepositoryProvider).fetchAuditLogs(
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

  void _applyFilters() {
    setState(() => _page = 1);
    _loadLogs();
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDate({
    required TextEditingController controller,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    final now = DateTime.now();
    DateTime initialDate = now;
    final existing = controller.text.trim();
    if (existing.isNotEmpty) {
      final parsed = DateTime.tryParse(existing);
      if (parsed != null) {
        initialDate = parsed;
      }
    }
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null || !mounted) return;
    setState(() {
      controller.text = _formatDate(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final admin = ref.watch(currentAdminProvider);
    if (!(admin?.hasPermission('admin.audit.view') ?? false)) {
      return const AdminPermissionPlaceholder();
    }
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          AdminPageHeader(
            title: l10n.adminAuditTitle,
            subtitle: l10n.adminAuditSubtitle,
            actions: [
              OutlinedButton.icon(
                onPressed: _loadLogs,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.retry),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Filters ──────────────────────────────────────────────────
          AdminFilterBar(
            trailing: FilledButton.icon(
              onPressed: _applyFilters,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Text(l10n.adminAuditApplyFilters),
            ),
            children: [
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _adminIdController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.adminAuditAdminFilter,
                    isDense: true,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                  ),
                  onSubmitted: (_) => _applyFilters(),
                ),
              ),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _actionController,
                  decoration: InputDecoration(
                    labelText: l10n.adminAuditActionFilter,
                    isDense: true,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.bolt_outlined, size: 18),
                  ),
                  onSubmitted: (_) => _applyFilters(),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _dateFromController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: l10n.adminAuditDateFromFilter,
                    isDense: true,
                    border: const OutlineInputBorder(),
                    prefixIcon:
                        const Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                  onTap: () => _pickDate(
                    controller: _dateFromController,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  ),
                  onSubmitted: (_) => _applyFilters(),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _dateToController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: l10n.adminAuditDateToFilter,
                    isDense: true,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.event_outlined, size: 18),
                  ),
                  onTap: () => _pickDate(
                    controller: _dateToController,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  ),
                  onSubmitted: (_) => _applyFilters(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── States ──────────────────────────────────────────────────
          if (_loading)
            const AdminLoadingState()
          else if (_error != null)
            AdminErrorState(message: _error!, onRetry: _loadLogs)
          else if (_logs.isEmpty)
            AdminEmptyState(message: l10n.adminAuditNoLogs)
          else ...[
            AdminDataTableCard(
              mobileBreakpoint: 860,
              mobileBuilder: (context) => Column(
                children: _logs
                    .map(
                      (log) => Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: cs.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      child: _ActionChip(action: log.action)),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      log.timestamp ?? '—',
                                      textAlign: TextAlign.end,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${log.entityType} #${log.entityId}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                log.admin?['email'] as String? ?? '—',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${log.ipAddress ?? '—'}\n${log.userAgent ?? ''}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              columns: [
                DataColumn(
                  label: Text(l10n.adminAuditActionColumn,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text(l10n.adminAuditEntityColumn,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text(l10n.adminAuditAdminColumn,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text(l10n.adminAuditTimeColumn,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text(l10n.adminAuditNetworkColumn,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
              rows: _logs.map((log) {
                return DataRow(cells: [
                  DataCell(_ActionChip(action: log.action)),
                  DataCell(Text(
                    '${log.entityType} #${log.entityId}',
                    style: theme.textTheme.bodySmall,
                  )),
                  DataCell(Text(
                    log.admin?['email'] as String? ?? '—',
                    style: theme.textTheme.bodySmall,
                  )),
                  DataCell(Text(
                    log.timestamp ?? '—',
                    style: theme.textTheme.bodySmall,
                  )),
                  DataCell(SizedBox(
                    width: 280,
                    child: Text(
                      '${log.ipAddress ?? '—'}\n${log.userAgent ?? ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.7)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
                ]);
              }).toList(),
            ),
            const SizedBox(height: 16),
            AdminPaginationBar(
              summary: l10n.adminPaginationSummary(
                (_pagination['page'] as int?) ?? _page,
                (_pagination['total_pages'] as int?) ?? 1,
                (_pagination['total'] as int?) ?? _logs.length,
              ),
              hasPrevious: (_pagination['has_previous'] as bool?) ?? false,
              hasNext: (_pagination['has_next'] as bool?) ?? false,
              previousLabel: l10n.adminPaginationPrevious,
              nextLabel: l10n.adminPaginationNext,
              onPrevious: () {
                setState(() => _page -= 1);
                _loadLogs();
              },
              onNext: () {
                setState(() => _page += 1);
                _loadLogs();
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── Action Chip ─────────────────────────────────────

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.action});

  final String action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDelete = action.toLowerCase().contains('delete') ||
        action.toLowerCase().contains('remove');
    final isCreate = action.toLowerCase().contains('create') ||
        action.toLowerCase().contains('add');
    final bgColor = isDelete
        ? cs.errorContainer
        : isCreate
            ? cs.primaryContainer
            : cs.surfaceContainerHighest;
    final fgColor = isDelete
        ? cs.error
        : isCreate
            ? cs.primary
            : cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        action,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
