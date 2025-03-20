import 'dart:convert';
import 'package:flutter/material.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/object_card.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../issue_selector.dart';

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
  WebSocketChannel? channel;

  String selectedChannel = "M308"; // Default selection
  final List<String> availableChannels = ["M308", "M309", "M326"];

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    // Close existing channel if present
    channel?.sink.close();
    channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.1.132:8000/ws/$selectedChannel'),
    );

    channel!.stream.listen((message) {
      final decoded = jsonDecode(message);
      print('🔔 Message on $selectedChannel: $decoded');

      if (decoded['trigger'] == true) {
        setState(() {
          objectId = decoded['objectId'] ?? '';
          hasBeenEvaluated = false;
          _issues.clear();
        });
      } else if (decoded['trigger'] == false) {
        setState(() {
          objectId = "";
          isObjectOK = false;
          hasBeenEvaluated = false;
          _issues.clear();
        });
      }

      if (decoded['outcome'] != null) {
        final outcome = decoded['outcome']; // "buona" or "scarto"
        print("Outcome from PLC: $outcome");
        // You can use this to auto-set `isObjectOK = true/false`
        setState(() {
          isObjectOK = (outcome == "buona");
          hasBeenEvaluated = true;
        });
      }
    });
  }

  void _onChannelChange(String? newChannel) {
    if (newChannel != null && newChannel != selectedChannel) {
      setState(() {
        // Reset UI data when switching station
        selectedChannel = newChannel;
        objectId = "";
        isObjectOK = false;
        hasBeenEvaluated = false;
        _issues.clear();
        _connectWebSocket();
      });
    }
  }

  @override
  void dispose() {
    channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Difetti'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          DropdownButton<String>(
            value: selectedChannel,
            underline: Container(),
            items: availableChannels
                .map((channel) => DropdownMenuItem(
                      value: channel,
                      child: Text(channel),
                    ))
                .toList(),
            onChanged: _onChannelChange,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (objectId.isNotEmpty) ...[
                    ObjectCard(
                      objectId: objectId,
                      isObjectOK: isObjectOK,
                      hasBeenEvaluated: hasBeenEvaluated,
                      selectedChannel: selectedChannel,
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    const Center(
                      child: Text(
                        'Nessun oggetto in produzione al momento.',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (hasBeenEvaluated && !isObjectOK) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Seleziona i problemi rilevati:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.arrow_forward),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => IssueSelectorPage(
                                  channelId: selectedChannel,
                                  onIssueSelected: (issuePath) {
                                    setState(() {
                                      _issues.add({"issue": issuePath});
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ]),
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
