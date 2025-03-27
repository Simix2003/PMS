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

class AddIssueDialog extends StatefulWidget {
  final void Function(String issue, String details) onSubmit;
  final bool isEditing;
  final String? initialIssue;
  final String? initialDetails;

  const AddIssueDialog({
    super.key,
    required this.onSubmit,
    this.isEditing = false,
    this.initialIssue,
    this.initialDetails,
  });

  @override
  State<AddIssueDialog> createState() => _AddIssueDialogState();
}

class _AddIssueDialogState extends State<AddIssueDialog> {
  final List<String> presetIssues = [
    'Superficie danneggiata',
    'Dimensioni errate',
    'Problemi di assemblaggio',
    'Colore non conforme',
    'Componente mancante',
    'Altro'
  ];

  String? selectedIssue;
  String additionalInfo = '';

  @override
  void initState() {
    super.initState();
    selectedIssue = widget.initialIssue;
    additionalInfo = widget.initialDetails ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isEditing ? 'Modifica Problema' : 'Aggiungi Problema',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400, // <-- Increase this value as you like!
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Seleziona il tipo di problema:'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text("Seleziona un problema"),
                  value: selectedIssue,
                  underline: Container(),
                  items: presetIssues.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    setState(() {
                      selectedIssue = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text('Informazioni aggiuntive:'),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: additionalInfo),
                decoration: InputDecoration(
                  hintText: "Descrivi il problema in dettaglio",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                maxLines: 3,
                onChanged: (value) {
                  additionalInfo = value;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: selectedIssue == null
              ? null
              : () {
                  widget.onSubmit(selectedIssue!, additionalInfo);
                  Navigator.of(context).pop();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            disabledBackgroundColor: Colors.grey,
            foregroundColor: Colors.white,
          ),
          child: Text(
            widget.isEditing ? 'Salva' : 'Aggiungi',
          ),
        ),
      ],
    );
  }
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
