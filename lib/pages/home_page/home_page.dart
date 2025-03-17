import 'package:flutter/material.dart';
import 'dart:math' as math;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final String objectNumber = 'OBJ-00123';
  late AnimationController _animationController;
  bool isObjectOK = false; // Default state before evaluation
  bool hasBeenEvaluated = false; // To track if the object has been evaluated

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Method to evaluate the object status
  void _evaluateObject(bool isOK) {
    setState(() {
      isObjectOK = isOK;
      hasBeenEvaluated = true;
    });
    // Stop animation when evaluated
    _animationController.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Production Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card for "Pezzo in Produzione" with animated border
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _getBorderColor().withOpacity(0.6),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Card(
                    elevation: 4,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _getBorderColor(),
                        width: 2.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pezzo in Produzione:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            objectNumber,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!hasBeenEvaluated) ...[
                            const Text(
                              'Stato: In valutazione',
                              style: TextStyle(
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _evaluateObject(true),
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text('Pezzo OK'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _evaluateObject(false),
                                  icon: const Icon(Icons.error),
                                  label: const Text('Pezzo Difettoso'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              'Stato: ${isObjectOK ? 'Pezzo OK' : 'Pezzo Difettoso'}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isObjectOK ? Colors.green : Colors.red,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Reset button
                            Center(
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    hasBeenEvaluated = false;
                                    _animationController.repeat();
                                  });
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Ricomincia Valutazione'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            const Text(
              'Aggiungi problemi al pezzo con il pulsante "+" qui sotto.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddIssueDialog(context);
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  // Get border color based on animation and status
  Color _getBorderColor() {
    if (!hasBeenEvaluated) {
      // Yellow pulsing effect before evaluation
      final value = math.sin(_animationController.value * math.pi * 2);
      final intensity = (value + 1) / 2; // Map from [-1, 1] to [0, 1]
      return Color.lerp(
          Colors.yellow.shade400, Colors.yellow.shade700, intensity)!;
    } else {
      // Solid green or red after evaluation
      return isObjectOK ? Colors.green : Colors.red;
    }
  }

  void _showAddIssueDialog(BuildContext context) {
    // List of preset issues
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

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Aggiungi Problema',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
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
                        items: presetIssues
                            .map<DropdownMenuItem<String>>((String value) {
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annulla'),
                ),
                ElevatedButton(
                  onPressed: selectedIssue == null
                      ? null
                      : () {
                          // Here you would normally save the issue
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Problema aggiunto: $selectedIssue'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.of(context).pop();

                          // After adding an issue, mark the object as defective
                          _evaluateObject(false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: const Text('Aggiungi'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
