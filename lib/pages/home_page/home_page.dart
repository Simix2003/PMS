// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../shared/widgets/add_issue_dialog.dart';

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
      duration: const Duration(milliseconds: 1500),
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
    //_animationController.stop();
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
          showDialog(
            context: context,
            builder: (context) {
              return AddIssueDialog(
                onSubmit: (issue, details) {
                  // Handle submission here
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Problema aggiunto: $issue'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              );
            },
          );
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
}
