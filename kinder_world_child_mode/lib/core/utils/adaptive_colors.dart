import 'package:flutter/material.dart';

/// Helpers that make hardcoded light-mode colors follow the dark theme so text
/// and cards never become invisible (e.g. white-on-white) in dark mode.
///
/// Use [adaptiveCardSurface] for container/card *backgrounds* that were
/// hardcoded `Colors.white`, and [adaptiveTextPrimary] / [adaptiveTextSecondary]
/// for *text/icon* colors that were hardcoded dark (e.g. `Colors.black87`,
/// `Colors.grey[600]`). White text/icons that sit on a coloured button or
/// gradient should stay `Colors.white` — they are already correct in both modes.

/// White cards/surfaces become bright "islands" on the dark background.
/// Returns a dark surface in dark mode, white (or [light]) in light mode.
Color adaptiveCardSurface(BuildContext context, {Color light = Colors.white}) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.surfaceContainerHigh
      : light;
}

/// Primary text/icon color that was hardcoded dark. Flips to a light color in
/// dark mode so it stays readable on the dark surfaces above.
Color adaptiveTextPrimary(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

/// Muted/secondary text color that was hardcoded (e.g. Colors.grey[600]).
/// Adapts to the theme so it never disappears against a dark surface.
Color adaptiveTextSecondary(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;
