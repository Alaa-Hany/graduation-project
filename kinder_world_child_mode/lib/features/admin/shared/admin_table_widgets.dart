import 'package:flutter/material.dart';

class AdminDataTableCard extends StatelessWidget {
  const AdminDataTableCard({
    super.key,
    required this.columns,
    required this.rows,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(columns: columns, rows: rows),
      ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(summary)),
        Row(
          children: [
            OutlinedButton(
              onPressed: hasPrevious ? onPrevious : null,
              child: Text(previousLabel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: hasNext ? onNext : null,
              child: Text(nextLabel),
            ),
          ],
        ),
      ],
    );
  }
}
