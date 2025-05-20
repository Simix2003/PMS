import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';

void showAddIssueWarningDialog(context) {
  AwesomeDialog(
    width: 750,
    context: context,
    dialogType: DialogType.noHeader,
    animType: AnimType.bottomSlide,
    title: 'Attenzione!',
    desc: 'Devi aggiungere almeno un difetto prima di poter andare avanti.',
    btnOkOnPress: () {},
    btnOkColor: Colors.orange,
  ).show();
}

Future<bool> showAddIssueConfirmationDialog(BuildContext context) async {
  bool confirmed = false;

  await AwesomeDialog(
    width: 750,
    context: context,
    dialogType: DialogType.question,
    animType: AnimType.bottomSlide,
    title: 'Conferma invio',
    desc:
        'Vuoi inviare i difetti selezionati?\nPuoi ancora aggiungerne altri prima di inviare.',
    titleTextStyle: const TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.bold,
    ),
    descTextStyle: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.normal,
    ),
    btnCancelOnPress: () {
      confirmed = false;
    },
    btnOkOnPress: () {
      confirmed = true;
    },
    btnCancelText: 'Aggiungi altri',
    btnOkText: 'Invia',
    btnOkColor: Colors.deepOrange,
    btnCancelColor: Colors.blueAccent,
  ).show();

  return confirmed;
}

void showConfirmSendDialog(context) {
  AwesomeDialog(
    width: 750,
    context: context,
    dialogType: DialogType.noHeader,
    animType: AnimType.bottomSlide,
    title: 'Avanti',
    desc: 'Il pezzo verrà inviato e non si potrà tornare indietro.',
    btnOkOnPress: () {},
    btnOkColor: Colors.green,
  ).show();
}

void showConfirmDeleteDialog(context) {
  AwesomeDialog(
    width: 750,
    context: context,
    dialogType: DialogType.noHeader,
    animType: AnimType.bottomSlide,
    title: 'Eliminare?',
    desc: 'Sei sicuro di voler eliminare questo oggetto?',
    btnOkOnPress: () {},
    btnOkColor: Colors.red,
  ).show();
}

void showObjectIssuesDialog({
  required BuildContext context,
  required String objectNumber,
  required List<Map<String, dynamic>> issues,
  required Function(int index, bool resolved) onToggleResolved,
}) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Problemi per $objectNumber'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: issues.asMap().entries.map((entry) {
              int idx = entry.key;
              var issue = entry.value;
              return Card(
                color: issue['resolved'] == true ? Colors.green[50] : null,
                child: ListTile(
                  leading: Icon(
                    issue['resolved'] == true
                        ? Icons.check_circle
                        : Icons.bug_report,
                    color:
                        issue['resolved'] == true ? Colors.green : Colors.red,
                  ),
                  title: Text(issue['type']),
                  subtitle: Text(issue['details'] ?? ''),
                  trailing: Switch(
                    value: issue['resolved'] == true,
                    onChanged: (val) => onToggleResolved(idx, val),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      );
    },
  );
}

class ExportConfirmationDialog extends StatelessWidget {
  final int selectedCount;
  final List<Map<String, String>> activeFilters;
  final VoidCallback onConfirm;

  const ExportConfirmationDialog({
    super.key,
    required this.selectedCount,
    required this.activeFilters,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Conferma Esportazione'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hai selezionato $selectedCount elementi da esportare.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (activeFilters.isNotEmpty) ...[
            const Text(
              'Filtri Attivi:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...activeFilters.map((f) => Text("• ${f['type']}: ${f['value']}")),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white),
          child: const Text('Conferma'),
        ),
      ],
    );
  }
}

Future<void> showNoFiltersDialog(BuildContext context) {
  return AwesomeDialog(
    context: context,
    width: 750,
    dialogType: DialogType.noHeader,
    animType: AnimType.bottomSlide,
    title: 'Nessun filtro selezionato',
    desc: 'Per favore, seleziona almeno un filtro prima di avviare la ricerca.',
    btnOkOnPress: () {},
    btnOkColor: Colors.orange,
  ).show();
}
