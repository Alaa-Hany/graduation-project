import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';

double adminResponsiveDialogWidth(
  BuildContext context, {
  double preferredWidth = 560,
}) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final horizontalPadding = screenWidth < 600 ? 32.0 : 96.0;
  final availableWidth = math.max(280.0, screenWidth - horizontalPadding);
  return math.min(preferredWidth, availableWidth);
}

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
    final dialogWidth =
        adminResponsiveDialogWidth(context, preferredWidth: width);
    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 40,
        vertical: 24,
      ),
      title: Text(title),
      content: SizedBox(
        width: dialogWidth,
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
