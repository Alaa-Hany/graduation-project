import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/models/admin_cms_models.dart';
import 'package:kinder_world/core/utils/color_compat.dart';

class AdminControlCenterAction {
  const AdminControlCenterAction({
    required this.icon,
    required this.label,
    required this.route,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String route;
  final Color accent;
}

class AdminControlCenterPanel extends StatelessWidget {
  const AdminControlCenterPanel({
    super.key,
    required this.title,
    required this.actions,
    required this.categoriesLabel,
    required this.contentsLabel,
    required this.quizzesLabel,
    this.axes = const [],
    this.onAxisTap,
  });

  final String title;
  final List<AdminControlCenterAction> actions;
  final List<AdminCmsAxisSummary> axes;
  final String categoriesLabel;
  final String contentsLabel;
  final String quizzesLabel;
  final ValueChanged<AdminCmsAxisSummary>? onAxisTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (actions.isEmpty && axes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: actions
                    .map(
                      (action) => InkWell(
                        onTap: () => context.go(action.route),
                        borderRadius: BorderRadius.circular(14),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colorScheme.outlineVariant
                                  .withValuesCompat(alpha: 0.7),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: action.accent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  action.icon,
                                  size: 18,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                action.label,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (axes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: axes
                    .map(
                      (axis) => _AxisContextCard(
                        axis: axis,
                        categoriesLabel: categoriesLabel,
                        contentsLabel: contentsLabel,
                        quizzesLabel: quizzesLabel,
                        onTap:
                            onAxisTap == null ? null : () => onAxisTap!(axis),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AxisContextCard extends StatelessWidget {
  const _AxisContextCard({
    required this.axis,
    required this.categoriesLabel,
    required this.contentsLabel,
    required this.quizzesLabel,
    this.onTap,
  });

  final AdminCmsAxisSummary axis;
  final String categoriesLabel;
  final String contentsLabel;
  final String quizzesLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValuesCompat(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              axis.titleEn.isNotEmpty ? axis.titleEn : axis.key,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (axis.titleAr.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                axis.titleAr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _AxisLine(label: categoriesLabel, value: axis.categoryCount),
            const SizedBox(height: 6),
            _AxisLine(label: contentsLabel, value: axis.contentCount),
            const SizedBox(height: 6),
            _AxisLine(label: quizzesLabel, value: axis.quizCount),
          ],
        ),
      ),
    );
  }
}

class _AxisLine extends StatelessWidget {
  const _AxisLine({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value.toString(),
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
