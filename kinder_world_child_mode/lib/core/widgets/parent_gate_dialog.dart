import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';

/// Asks a grown-up to solve a small multiplication before child mode opens
/// anything outside the app (YouTube, the browser, another app).
///
/// Child mode usually has no parent session on the device, so a PIN check
/// against the backend is not always possible; a times-table question is the
/// usual "grown-ups only" gate for kids' apps: easy for an adult, hard for a
/// young child to guess.
///
/// Deliberately built from plain Material widgets; the design work can restyle
/// it without changing the behaviour.
Future<bool> showParentGate(BuildContext context, {Random? random}) async {
  final rng = random ?? Random.secure();
  // 6..9 × 6..9: two-digit answers a pre-reader can't just guess.
  final a = 6 + rng.nextInt(4);
  final b = 6 + rng.nextInt(4);
  final passed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => ParentGateDialog(a: a, b: b),
  );
  return passed ?? false;
}

class ParentGateDialog extends StatefulWidget {
  const ParentGateDialog({super.key, required this.a, required this.b});

  final int a;
  final int b;

  @override
  State<ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<ParentGateDialog> {
  final _controller = TextEditingController();
  bool _wrong = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final answer = int.tryParse(_controller.text.trim());
    if (answer == widget.a * widget.b) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _wrong = true;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.parentGateTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.parentGateQuestion(widget.a, widget.b)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('parent_gate_answer'),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(
              labelText: l10n.parentGateAnswerLabel,
              errorText: _wrong ? l10n.parentGateWrongAnswer : null,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          key: const Key('parent_gate_continue'),
          onPressed: _submit,
          child: Text(l10n.parentGateContinue),
        ),
      ],
    );
  }
}
