import 'package:flutter/material.dart';

class AdminDataTableCard extends StatelessWidget {
  const AdminDataTableCard({
    super.key,
    required this.columns,
    required this.rows,
    this.mobileBuilder,
    this.mobileBreakpoint = 820,
    this.minTableWidth = 880,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final WidgetBuilder? mobileBuilder;
  final double mobileBreakpoint;
  final double minTableWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final useMobile =
            mobileBuilder != null && constraints.maxWidth < mobileBreakpoint;
        if (useMobile) {
          return mobileBuilder!(context);
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minTableWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  colorScheme.surfaceContainerLow,
                ),
                headingTextStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                dataRowMinHeight: 48,
                dataRowMaxHeight: 64,
                dividerThickness: 0.5,
                columnSpacing: 24,
                horizontalMargin: 20,
                columns: columns,
                rows: rows,
              ),
            ),
          ),
        );
      },
    );
  }
}

class AdminPaginationBar extends StatelessWidget {
  const AdminPaginationBar({
    super.key,
    required this.summary,
    required this.hasPrevious,
    required this.hasNext,
    required this.previousLabel,
    required this.nextLabel,
    required this.onPrevious,
    required this.onNext,
  });

  final String summary;
  final bool hasPrevious;
  final bool hasNext;
  final String previousLabel;
  final String nextLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final stacked = constraints.maxWidth < 430;
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: hasPrevious ? onPrevious : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 18),
              label: Text(previousLabel),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            FilledButton.icon(
              onPressed: hasNext ? onNext : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 18),
              label: Text(nextLabel),
              iconAlignment: IconAlignment.end,
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.table_rows_outlined,
                          size: 16,
                          color: colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            summary,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (stacked)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: hasPrevious ? onPrevious : null,
                              icon: const Icon(Icons.chevron_left_rounded, size: 18),
                              label: Text(previousLabel),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: hasNext ? onNext : null,
                              icon: const Icon(Icons.chevron_right_rounded, size: 18),
                              label: Text(nextLabel),
                              iconAlignment: IconAlignment.end,
                            ),
                          ),
                        ],
                      )
                    else
                      actions,
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      Icons.table_rows_outlined,
                      size: 16,
                      color: colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        summary,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    actions,
                  ],
                ),
        );
      },
    );
  }
}
