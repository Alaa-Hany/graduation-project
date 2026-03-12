import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/support_ticket_record.dart';
import 'package:kinder_world/core/providers/support_controller.dart';

class ParentContactUsScreen extends ConsumerStatefulWidget {
  const ParentContactUsScreen({super.key});

  @override
  ConsumerState<ParentContactUsScreen> createState() =>
      _ParentContactUsScreenState();
}

class _ParentContactUsScreenState extends ConsumerState<ParentContactUsScreen> {
  late final TextEditingController _subjectController;
  late final TextEditingController _messageController;
  final Map<int, TextEditingController> _replyControllers = {};
  String _selectedCategory = 'general_inquiry';

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController();
    _messageController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supportControllerProvider.notifier).loadTickets();
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supportState = ref.watch(supportControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.parentContactUs),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(supportControllerProvider.notifier).loadTickets(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.contactUsIntro,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _buildContactForm(context, l10n, supportState),
            const SizedBox(height: 24),
            _buildHistorySection(context, l10n, supportState),
          ],
        ),
      ),
    );
  }

  Widget _buildContactForm(
    BuildContext context,
    AppLocalizations l10n,
    SupportState supportState,
  ) {
    final controller = ref.read(supportControllerProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sendMessageTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: l10n.supportCategoryLabel,
                border: const OutlineInputBorder(),
              ),
              items: _categoryOptions(l10n)
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value ?? 'general_inquiry';
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _subjectController,
              maxLines: 1,
              decoration: InputDecoration(
                labelText: l10n.subjectLabel,
                hintText: l10n.subjectHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.subject),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              maxLines: 7,
              minLines: 5,
              decoration: InputDecoration(
                labelText: l10n.messageLabel,
                hintText: l10n.messageHint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Icon(Icons.message_outlined),
                ),
              ),
            ),
            if (supportState.errorMessage != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: supportState.errorMessage!),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: supportState.isSubmitting
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        if (_subjectController.text.trim().isEmpty) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(l10n.subjectRequiredError)),
                          );
                          return;
                        }
                        if (_messageController.text.trim().isEmpty) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(l10n.messageRequiredError)),
                          );
                          return;
                        }

                        final success = await controller.sendMessage(
                          subject: _subjectController.text.trim(),
                          message: _messageController.text.trim(),
                          category: _selectedCategory,
                        );
                        if (!mounted || !success) return;

                        _subjectController.clear();
                        _messageController.clear();
                        setState(() {
                          _selectedCategory = 'general_inquiry';
                        });
                        messenger.showSnackBar(
                          SnackBar(content: Text(l10n.messageSentSuccess)),
                        );
                      },
                child: supportState.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.sendMessage),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(
    BuildContext context,
    AppLocalizations l10n,
    SupportState supportState,
  ) {
    if (supportState.isLoadingHistory) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.supportTicketHistoryTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.supportTicketHistorySubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (supportState.tickets.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.supportTicketNoHistory),
            ),
          )
        else
          ...supportState.tickets.map(
            (ticket) => _buildTicketCard(context, l10n, supportState, ticket),
          ),
      ],
    );
  }

  Widget _buildTicketCard(
    BuildContext context,
    AppLocalizations l10n,
    SupportState supportState,
    SupportTicketRecord ticket,
  ) {
    final notifier = ref.read(supportControllerProvider.notifier);
    final detailedTicket = supportState.ticketDetailFor(ticket.id) ?? ticket;
    final replyController =
        _replyControllers.putIfAbsent(ticket.id, TextEditingController.new);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          if (expanded) {
            notifier.loadTicketDetail(ticket.id);
          }
        },
        title: Text(
          ticket.subject,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Text(
          '${_categoryLabel(ticket.category, l10n)} • ${_statusLabel(ticket.status, l10n)}',
        ),
        trailing: _SupportChip(
          label: _statusLabel(ticket.status, l10n),
          colorScheme: _statusColor(ticket.status, Theme.of(context).colorScheme),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SupportChip(
                  label: _categoryLabel(ticket.category, l10n),
                  colorScheme:
                      _categoryColor(Theme.of(context).colorScheme),
                ),
                if (ticket.updatedAt != null)
                  _SupportChip(
                    label: _formatDate(ticket.updatedAt!),
                    colorScheme:
                        _neutralColor(Theme.of(context).colorScheme),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...detailedTicket.thread.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
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
                      entry.authorType == 'admin'
                          ? l10n.supportAgentLabel
                          : l10n.youLabel,
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
          if (!ticket.isClosed) ...[
            const SizedBox(height: 8),
            TextField(
              controller: replyController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.supportReplyLabel,
                hintText: l10n.supportReplyHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                onPressed: supportState.isSubmitting &&
                        supportState.activeTicketId == ticket.id
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        if (replyController.text.trim().isEmpty) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(l10n.messageRequiredError)),
                          );
                          return;
                        }
                        final success = await notifier.replyToTicket(
                          ticketId: ticket.id,
                          message: replyController.text.trim(),
                        );
                        if (!mounted || !success) return;
                        replyController.clear();
                        messenger.showSnackBar(
                          SnackBar(content: Text(l10n.supportReplySentSuccess)),
                        );
                      },
                icon: const Icon(Icons.reply_rounded),
                label: Text(l10n.supportReplyAction),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<MapEntry<String, String>> _categoryOptions(AppLocalizations l10n) {
    return [
      MapEntry('general_inquiry', l10n.supportCategoryGeneralInquiry),
      MapEntry('login_issue', l10n.supportCategoryLoginIssue),
      MapEntry('billing_issue', l10n.supportCategoryBillingIssue),
      MapEntry('child_content_issue', l10n.supportCategoryChildContentIssue),
      MapEntry('technical_issue', l10n.supportCategoryTechnicalIssue),
    ];
  }

  String _categoryLabel(String category, AppLocalizations l10n) {
    switch (category) {
      case 'login_issue':
        return l10n.supportCategoryLoginIssue;
      case 'billing_issue':
        return l10n.supportCategoryBillingIssue;
      case 'child_content_issue':
        return l10n.supportCategoryChildContentIssue;
      case 'technical_issue':
        return l10n.supportCategoryTechnicalIssue;
      default:
        return l10n.supportCategoryGeneralInquiry;
    }
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'in_progress':
        return l10n.supportStatusInProgress;
      case 'resolved':
        return l10n.supportStatusResolved;
      case 'closed':
        return l10n.supportStatusClosed;
      default:
        return l10n.supportStatusOpen;
    }
  }

  _ChipColors _statusColor(String status, ColorScheme scheme) {
    switch (status) {
      case 'in_progress':
        return _ChipColors(scheme.tertiaryContainer, scheme.tertiary);
      case 'resolved':
        return _ChipColors(scheme.secondaryContainer, scheme.secondary);
      case 'closed':
        return _ChipColors(scheme.primaryContainer, scheme.primary);
      default:
        return _ChipColors(scheme.errorContainer, scheme.error);
    }
  }

  _ChipColors _categoryColor(ColorScheme scheme) {
    return _ChipColors(scheme.surfaceContainerHighest, scheme.onSurfaceVariant);
  }

  _ChipColors _neutralColor(ColorScheme scheme) {
    return _ChipColors(scheme.surfaceContainerLow, scheme.onSurfaceVariant);
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    return DateFormat('MMM d, h:mm a').format(date);
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

class _SupportChip extends StatelessWidget {
  const _SupportChip({
    required this.label,
    required this.colorScheme,
  });

  final String label;
  final _ChipColors colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChipColors {
  const _ChipColors(this.background, this.foreground);

  final Color background;
  final Color foreground;
}
