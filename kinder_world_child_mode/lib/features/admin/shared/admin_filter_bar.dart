import 'package:flutter/material.dart';

class AdminFilterBar extends StatelessWidget {
  const AdminFilterBar({
    super.key,
    required this.children,
    this.trailing,
  });

  final List<Widget> children;

  /// Optional widget pinned to the end (e.g. a primary action button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_list_rounded,
                          size: 18,
                          color: colorScheme.primary.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...children.map(
                      (child) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: child,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(height: 2),
                      SizedBox(
                        width: double.infinity,
                        child: trailing!,
                      ),
                    ],
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      Icons.filter_list_rounded,
                      size: 18,
                      color: colorScheme.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: children,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 12),
                      trailing!,
                    ],
                  ],
                ),
        );
      },
    );
  }
}
