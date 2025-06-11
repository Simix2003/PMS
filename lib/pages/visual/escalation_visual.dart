// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';

import '../../shared/services/api_service.dart';
import '../../shared/widgets/AI.dart';

class EscalationButton extends StatelessWidget {
  const EscalationButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.withOpacity(0.85),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 10,
      ),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => const EscalationDialog(),
        );
      },
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
      label: const Text(
        'Escalation',
        style: TextStyle(
            fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}

class EscalationDialog extends StatefulWidget {
  const EscalationDialog({super.key});

  @override
  State<EscalationDialog> createState() => _EscalationDialogState();
}

class _EscalationDialogState extends State<EscalationDialog> {
  String selectedStatus = 'Shift Manager';
  final TextEditingController reasonController = TextEditingController();
  int? selectedEscalationIndex;

  final List<Map<String, String>> mockEscalations = [
    {'title': '🟡 MIN01 - Piccolo Problema', 'status': 'Shift Manager'},
    {'title': '🔴 MIN02 - Blocco Bussing', 'status': 'Head of Production'},
  ];

  bool showClosed = false;

  void saveEscalation() async {
    if (selectedEscalationIndex != null) {
      // Edita status esistente
      setState(() {
        mockEscalations[selectedEscalationIndex!]['status'] = selectedStatus;
      });
      Navigator.pop(context);
    } else {
      final text = reasonController.text.trim();

      // Controllo testo vuoto
      if (text.isEmpty) return;

      // Check duplicato
      final exists = mockEscalations.any((e) => e['title']!.contains(text));
      String chosenText = text;

      if (!exists) {
        // Chiama l'AI
        final result = await ApiService.checkDefectSimilarity(text);

        if (result != null && result['suggested_defect'] != null) {
          final suggestion = result['suggested_defect']!;
          final confidence = result['confidence'];

          final useSuggestion = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => IAConfirmationDialog(
              original: text,
              suggestion: suggestion,
              confidence: confidence,
            ),
          );

          if (useSuggestion == true) {
            chosenText = suggestion;
          }
        }
      }

      setState(() {
        mockEscalations.add({
          'title': '🟠 NEW - $chosenText',
          'status': selectedStatus,
        });
        reasonController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      child: SizedBox(
        width: 1000,
        height: 700,
        child: Row(
          children: [
            Container(
              width: 220,
              color: Colors.grey[100],
              child: Column(
                children: [
                  // Scrollable escalation list
                  Expanded(
                    child: ListView.builder(
                      itemCount: mockEscalations.length + 1,
                      itemBuilder: (context, index) {
                        final isNewItem = index == mockEscalations.length;
                        final isSelected = isNewItem
                            ? selectedEscalationIndex == null
                            : selectedEscalationIndex == index;

                        final cardColor =
                            isSelected ? Colors.blue.shade50 : Colors.white;
                        final borderColor =
                            isSelected ? Colors.blue : Colors.grey.shade300;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 6.0),
                          child: Card(
                            color: cardColor,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: borderColor, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  if (isNewItem) {
                                    selectedEscalationIndex = null;
                                    reasonController.clear();
                                    selectedStatus = 'Shift Manager';
                                  } else {
                                    selectedEscalationIndex = index;
                                    selectedStatus =
                                        mockEscalations[index]['status']!;
                                    reasonController.clear();
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12.0, horizontal: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isNewItem
                                          ? Icons.add_circle_outline
                                          : Icons.bolt,
                                      color: isSelected
                                          ? Colors.blue
                                          : Colors.black54,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isNewItem
                                            ? 'Nuova Escalation'
                                            : mockEscalations[index]['title']!,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom "View Closed" button
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.history, color: Colors.white),
                      label: const Text(
                        'Visualizza Chiuse',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        setState(() {
                          showClosed = true;
                          selectedEscalationIndex = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Right Panel
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: showClosed
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Escalation Chiuse',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView(
                              children: mockEscalations
                                  .where((e) => e['status'] == 'Closed')
                                  .map((e) => Card(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: ListTile(
                                          leading: const Icon(
                                              Icons.check_circle,
                                              color: Colors.green),
                                          title: Text(e['title']!),
                                          subtitle: const Text("Stato: Closed"),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Torna'),
                              onPressed: () {
                                setState(() {
                                  showClosed = false;
                                });
                              },
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedEscalationIndex != null
                                ? 'Modifica Escalation'
                                : 'Crea Nuova Escalation',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),
                          if (selectedEscalationIndex == null)
                            TextField(
                              controller: reasonController,
                              decoration: const InputDecoration(
                                labelText: 'Motivo del blocco',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Stato Escalation',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Shift Manager',
                                  child: Text('Shift Manager')),
                              DropdownMenuItem(
                                  value: 'Head of Production',
                                  child: Text('Head of Production')),
                              DropdownMenuItem(
                                  value: 'Closed', child: Text('Closed')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => selectedStatus = val);
                              }
                            },
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                child: const Text('Annulla'),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: saveEscalation,
                                child: const Text('Salva'),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
