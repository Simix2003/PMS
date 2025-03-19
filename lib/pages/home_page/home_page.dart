import 'package:flutter/material.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/object_card.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String objectId = "";
  bool isObjectOK = false;
  bool hasBeenEvaluated = false;
  final List<Map<String, String>> _issues = [];

  @override
  void initState() {
    super.initState();
    _subscribeToPLC();
  }

  void _subscribeToPLC() async {
    final url = Uri.parse('http://192.168.1.132:8000/subscribe/M308');

    try {
      final response = await http.post(url);
      if (response.statusCode == 200) {
        print('Subscribed successfully: ${response.body}');
      } else {
        print('Subscription failed: ${response.body}');
      }
    } catch (e) {
      print('Error subscribing: $e');
    }
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
                if (objectId.isNotEmpty)
                  ObjectCard(
                    objectId: objectId,
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
                    ],
                  ),
                  const SizedBox(height: 8),
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
                    print('Object Number: $objectId');
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
