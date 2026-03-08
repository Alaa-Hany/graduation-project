import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/providers/support_controller.dart';

class ParentContactUsScreen extends ConsumerStatefulWidget {
  const ParentContactUsScreen({super.key});

  @override
  ConsumerState<ParentContactUsScreen> createState() =>
      _ParentContactUsScreenState();
}

class _ParentContactUsScreenState extends ConsumerState<ParentContactUsScreen> {
  late TextEditingController _subjectController;
  late TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Intro text
            Text(
              l10n.contactUsIntro,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // Subject field
            TextField(
              controller: _subjectController,
              maxLines: 1,
              decoration: InputDecoration(
                labelText: l10n.subjectLabel,
                hintText: l10n.subjectHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.subject),
              ),
            ),
            const SizedBox(height: 16),

            // Message field
            TextField(
              controller: _messageController,
              maxLines: 8,
              minLines: 6,
              decoration: InputDecoration(
                labelText: l10n.messageLabel,
                hintText: l10n.messageHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(top: 12.0),
                  child: Icon(Icons.message),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Error message if exists
            if (supportState.maybeWhen(
              error: (err, _) => true,
              orElse: () => false,
            ))
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  supportState.maybeWhen(
                    error: (err, _) => err.toString(),
                    orElse: () => '',
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),

            // Send button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: supportState.maybeWhen(
                  loading: () => null,
                  orElse: () => () async {
                    // Validation
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    final loc = AppLocalizations.of(context)!;

                    if (_subjectController.text.trim().isEmpty) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(loc.subjectRequiredError),
                        ),
                      );
                      return;
                    }

                    if (_messageController.text.trim().isEmpty) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(loc.messageRequiredError),
                        ),
                      );
                      return;
                    }

                    final success = await ref
                        .read(supportControllerProvider.notifier)
                        .sendMessage(
                          subject: _subjectController.text.trim(),
                          message: _messageController.text.trim(),
                        );

                    if (success && mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(loc.messageSentSuccess),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      navigator.pop();
                    }
                  },
                ),
                child: supportState.maybeWhen(
                  loading: () => SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  orElse: () => Text(l10n.sendMessage),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
