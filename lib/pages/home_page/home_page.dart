import 'package:flutter/material.dart';
import '../../shared/widgets/object_card.dart';
import '../../shared/widgets/add_issue_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final String objectNumber = 'OBJ-00123';
  bool isObjectOK = false;
  bool hasBeenEvaluated = false;

  void _evaluateObject(bool isOK) {
    setState(() {
      isObjectOK = isOK;
      hasBeenEvaluated = true;
    });
  }

  void _resetEvaluation() {
    setState(() {
      hasBeenEvaluated = false;
    });
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
            ObjectCard(
              objectNumber: objectNumber,
              isObjectOK: isObjectOK,
              hasBeenEvaluated: hasBeenEvaluated,
              onReset: _resetEvaluation,
              onEvaluate: _evaluateObject,
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
}
