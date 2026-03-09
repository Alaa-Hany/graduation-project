import 'package:flutter/material.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';

class AdminFormDialog extends StatelessWidget {
  const AdminFormDialog({
    super.key,
    required this.title,
    required this.child,
    this.width = 560,
    this.onSubmit,
    this.submitLabel,
    this.extraActions = const [],
  });

  final String title;
  final Widget child;
  final double width;
  final VoidCallback? onSubmit;
  final String? submitLabel;
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(child: child),
      ),
      actions: [
        ...extraActions,
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: onSubmit,
          child: Text(submitLabel ?? l10n.save),
        ),
      ],
    );
  }
}
