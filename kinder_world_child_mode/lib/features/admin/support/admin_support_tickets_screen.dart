import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_support_ticket.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_confirm_dialog.dart';
import 'package:kinder_world/features/admin/shared/admin_filter_bar.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';
import 'package:kinder_world/features/admin/shared/admin_state_widgets.dart';
import 'package:kinder_world/features/admin/shared/admin_table_widgets.dart';

/// IMPORTANT:
/// All UI text must use AppLocalizations.
/// Hardcoded strings are NOT allowed.

class AdminSupportTicketsScreen extends ConsumerStatefulWidget {
  const AdminSupportTicketsScreen({super.key});

  @override
  ConsumerState<AdminSupportTicketsScreen> createState() =>
      _AdminSupportTicketsScreenState();
}

class _AdminSupportTicketsScreenState
    extends ConsumerState<AdminSupportTicketsScreen> {
  String _status = '';
  int _page = 1;
  bool _loading = true;
  String? _error;
  List<AdminSupportTicket> _tickets = const [];
  Map<String, dynamic> _pagination = const {};
  AdminSupportTicket? _selectedTicket;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets({int? selectTicketId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await ref.read(adminManagementRepositoryProvider).fetchSupportTickets(
                status: _status,
                page: _page,
              );
      AdminSupportTicket? selected = _selectedTicket;
      final targetId = selectTicketId ?? _selectedTicket?.id;
      if (targetId != null) {
        selected = response.items.cast<AdminSupportTicket?>().firstWhere(
              (item) => item?.id == targetId,
              orElse: () => _selectedTicket,
            );
      }
      setState(() {
        _tickets = response.items;
        _pagination = response.pagination;
        _selectedTicket =
            selected ?? (_tickets.isNotEmpty ? _tickets.first : null);
        _loading = false;
      });
      if (_selectedTicket != null) {
        await _loadTicketDetails(_selectedTicket!.id, quiet: true);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadTicketDetails(int ticketId, {bool quiet = false}) async {
    if (!quiet) {
      setState(() => _loading = true);
    }
    try {
      final ticket = await ref
          .read(adminManagementRepositoryProvider)
          .fetchSupportTicketDetail(ticketId);
      if (!mounted) return;
      setState(() {
        _selectedTicket = ticket;
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

  Future<void> _replyToTicket() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.adminSupportReply),
        content: TextField(
          controller: controller,
          minLines: 4,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: l10n.adminSupportReplyHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.sendMessage),
          ),
        ],
      ),
    );
    if (confirmed != true || _selectedTicket == null) return;
    await ref
        .read(adminManagementRepositoryProvider)
        .replySupportTicket(_selectedTicket!.id, controller.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.adminSupportReplySuccess),
      ),
    );
    await _loadTickets(selectTicketId: _selectedTicket!.id);
  }

  Future<void> _assignToMe() async {
    final l10n = AppLocalizations.of(context)!;
    final ticket = _selectedTicket;
    if (ticket == null) return;
    await ref
        .read(adminManagementRepositoryProvider)
        .assignSupportTicket(ticket.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.adminSupportAssignSuccess),
      ),
    );
    await _loadTickets(selectTicketId: ticket.id);
  }

  Future<void> _closeTicket() async {
    final l10n = AppLocalizations.of(context)!;
    final ticket = _selectedTicket;
    if (ticket == null) return;
    final confirmed = await showAdminConfirmDialog(
      context: context,
      title: l10n.adminSupportClose,
      message: l10n.adminSupportCloseConfirm,
      confirmLabel: l10n.adminSupportClose,
    );
    if (!confirmed) return;
    await ref
        .read(adminManagementRepositoryProvider)
        .closeSupportTicket(ticket.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.adminSupportCloseSuccess),
      ),
    );
    await _loadTickets(selectTicketId: ticket.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final admin = ref.watch(currentAdminProvider);
    if (!(admin?.hasPermission('admin.support.view') ?? false)) {
      return const AdminPermissionPlaceholder();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.adminSupportTicketsTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.adminSupportTicketsSubtitle,
              ),
              const SizedBox(height: 20),
              AdminFilterBar(
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: InputDecoration(
                        labelText: l10n.adminSupportStatusFilter,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(l10n.adminSupportStatusAll),
                        ),
                        DropdownMenuItem(
                          value: 'open',
                          child: Text(l10n.adminSupportStatusOpen),
                        ),
                        DropdownMenuItem(
                          value: 'in_progress',
                          child: Text(l10n.adminSupportStatusInProgress),
                        ),
                        DropdownMenuItem(
                          value: 'closed',
                          child: Text(l10n.adminSupportStatusClosed),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _status = value ?? '';
                          _page = 1;
                        });
                        _loadTickets();
                      },
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loadTickets,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_loading)
                const AdminLoadingState()
              else if (_error != null)
                AdminErrorState(message: _error!, onRetry: _loadTickets)
              else if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildTicketsList(context, l10n),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 6,
                      child: _buildDetailsCard(context, l10n),
                    ),
                  ],
                )
              else ...[
                _buildTicketsList(context, l10n),
                const SizedBox(height: 16),
                _buildDetailsCard(context, l10n),
              ],
              const SizedBox(height: 16),
              AdminPaginationBar(
                summary: l10n.adminPaginationSummary(
                  (_pagination['page'] as int?) ?? _page,
                  (_pagination['total_pages'] as int?) ?? 1,
                  (_pagination['total'] as int?) ?? _tickets.length,
                ),
                hasPrevious: (_pagination['has_previous'] as bool?) ?? false,
                hasNext: (_pagination['has_next'] as bool?) ?? false,
                previousLabel: l10n.adminPaginationPrevious,
                nextLabel: l10n.adminPaginationNext,
                onPrevious: () {
                  setState(() => _page -= 1);
                  _loadTickets();
                },
                onNext: () {
                  setState(() => _page += 1);
                  _loadTickets();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTicketsList(BuildContext context, AppLocalizations l10n) {
    if (_tickets.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.adminSupportNoTickets),
        ),
      );
    }

    return Column(
      children: _tickets.map((ticket) {
        final selected = _selectedTicket?.id == ticket.id;
        return Card(
          color: selected
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.35)
              : null,
          child: ListTile(
            onTap: () => _loadTicketDetails(ticket.id),
            title: Text(ticket.subject),
            subtitle: Text(
              '${_statusLabel(ticket.status, l10n)} • ${ticket.requester?['email'] ?? ticket.email ?? '—'}\n${ticket.preview ?? ticket.message}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusChip(
                    status: ticket.status,
                    label: _statusLabel(ticket.status, l10n)),
                const SizedBox(height: 4),
                Text(
                  l10n.adminSupportMessagesCount(ticket.replyCount),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailsCard(BuildContext context, AppLocalizations l10n) {
    final ticket = _selectedTicket;
    if (ticket == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.adminSupportNoTicketSelected,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.subject,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                _StatusChip(
                    status: ticket.status,
                    label: _statusLabel(ticket.status, l10n)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                    '${l10n.adminSupportRequester}: ${ticket.requester?['email'] ?? ticket.email ?? '—'}'),
                Text(
                    '${l10n.adminSupportAssignee}: ${ticket.assignedAdmin?['email'] ?? '—'}'),
                if (ticket.updatedAt != null)
                  Text(
                      '${l10n.adminUsersLastUpdatedMetric}: ${_formatDate(ticket.updatedAt!)}'),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: ticket.status == 'closed' ? null : _replyToTicket,
                  icon: const Icon(Icons.reply_outlined),
                  label: Text(l10n.adminSupportReply),
                ),
                OutlinedButton.icon(
                  onPressed: ticket.status == 'closed' ? null : _assignToMe,
                  icon: const Icon(Icons.person_add_alt_outlined),
                  label: Text(l10n.adminSupportAssignedToMe),
                ),
                OutlinedButton.icon(
                  onPressed: ticket.status == 'closed' ? null : _closeTicket,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(l10n.adminSupportClose),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              l10n.adminSupportThread,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            ...ticket.thread.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: entry.authorType == 'admin'
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _threadAuthor(entry, l10n),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(entry.message),
                      if (entry.createdAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _formatDate(entry.createdAt!),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'open':
        return l10n.adminSupportStatusOpen;
      case 'in_progress':
        return l10n.adminSupportStatusInProgress;
      case 'closed':
        return l10n.adminSupportStatusClosed;
      default:
        return status;
    }
  }

  String _threadAuthor(AdminSupportThreadEntry entry, AppLocalizations l10n) {
    switch (entry.authorType) {
      case 'admin':
        return entry.author?['email']?.toString() ?? l10n.adminSupportAssign;
      case 'user':
        return entry.author?['email']?.toString() ?? l10n.adminSupportRequester;
      default:
        return l10n.adminSupportThread;
    }
  }

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    return DateFormat('MMM d, y • h:mm a').format(parsed);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color background;
    Color foreground;
    switch (status) {
      case 'closed':
        background = scheme.primaryContainer;
        foreground = scheme.primary;
        break;
      case 'in_progress':
        background = scheme.tertiaryContainer;
        foreground = scheme.tertiary;
        break;
      default:
        background = scheme.errorContainer;
        foreground = scheme.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
