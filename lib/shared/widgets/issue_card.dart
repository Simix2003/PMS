import 'package:flutter/material.dart';

class IssueCard extends StatelessWidget {
  final String issueType;
  final String details;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const IssueCard({
    super.key,
    required this.issueType,
    required this.details,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.report_problem, color: Colors.red),
        title: Text(issueType),
        subtitle: Text(
          details.isEmpty ? 'Nessuna descrizione aggiuntiva' : details,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              tooltip: 'Modifica',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Elimina',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
