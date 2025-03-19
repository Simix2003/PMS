import 'package:flutter/material.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/object_card.dart';
import '../../shared/widgets/issue_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final String objectNumber = 'ObjectNumber';
  bool isObjectOK = false;
  bool hasBeenEvaluated = false;
  final List<Map<String, String>> _issues = [];

  @override
  void initState() {
    super.initState();
  }

  void _evaluateObject(bool isOK) {
    setState(() {
      isObjectOK = isOK;
      hasBeenEvaluated = true;
    });
  }

  void _resetEvaluation() {
    setState(() {
      hasBeenEvaluated = false;
      _issues.clear();
    });
  }

  void _addIssue(String type, String details) {
    if (type.trim().isEmpty) return;
    setState(() {
      _issues.add({'type': type, 'details': details});
    });
  }

  void _removeIssue(int index) {
    if (index < 0 || index >= _issues.length) return;
    setState(() {
      _issues.removeAt(index);
    });
  }

  void _editIssue(int index, String newType, String newDetails) {
    if (index < 0 || index >= _issues.length) return;
    if (newType.trim().isEmpty) return;
    setState(() {
      _issues[index] = {'type': newType, 'details': newDetails};
    });
  }

  void _openEditDialog(int index) {
    if (index < 0 || index >= _issues.length) return;
    final issue = _issues[index];

    showDialog(
      context: context,
      builder: (context) {
        return AddIssueDialog(
          isEditing: true,
          initialIssue: issue['type'] ?? '',
          initialDetails: issue['details'] ?? '',
          onSubmit: (newIssue, newDetails) {
            _editIssue(index, newIssue, newDetails);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Difetti'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Padding(
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
                if (hasBeenEvaluated && !isObjectOK) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Problemi rilevati:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle,
                            color: Colors.blue, size: 48),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AddIssueDialog(
                                onSubmit: (issue, details) {
                                  _addIssue(issue, details);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_issues.isEmpty)
                    const Text(
                      'Nessun problema aggiunto.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ..._issues.asMap().entries.map((entry) {
                    int idx = entry.key;
                    Map<String, String> issue = entry.value;
                    return IssueCard(
                      issueType: issue['type'] ?? 'Sconosciuto',
                      details: issue['details'] ?? '',
                      onDelete: () => _removeIssue(idx),
                      onEdit: () => _openEditDialog(idx),
                    );
                  }).toList(),
                ] else if (hasBeenEvaluated && isObjectOK) ...[
                  const Center(),
                ],
              ],
            ),
          ),
          if (hasBeenEvaluated && !isObjectOK)
            Positioned(
              bottom: 20,
              right: 20,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_issues.isEmpty) {
                    showAddIssueWarningDialog(context);
                  } else {
                    print('Object Number: $objectNumber');
                    print('Issues: $_issues');
                  }
                },
                icon: Icon(
                  Icons.send,
                  color: _issues.isEmpty ? Colors.grey.shade800 : Colors.white,
                ),
                label: const Text('Invia'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  textStyle: const TextStyle(fontSize: 24),
                  backgroundColor: _issues.isEmpty ? Colors.grey : Colors.blue,
                  foregroundColor:
                      _issues.isEmpty ? Colors.grey.shade800 : Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
