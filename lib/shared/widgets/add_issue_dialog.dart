// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

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
