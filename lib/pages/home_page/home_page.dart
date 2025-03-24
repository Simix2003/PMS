// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/object_card.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../issue_selector.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  String objectId = "";
  bool isObjectOK = false;
  bool hasBeenEvaluated = false;
  final Set<String> _issues = {};
  WebSocketChannel? channel;

  String selectedChannel = "M308"; // Default selection
  final List<String> availableChannels = ["M308", "M309", "M326"];

  bool isConnecting = true;

  bool issuesSubmitted = false;

  final GlobalKey<IssueSelectorWidgetState> _issueSelectorKey =
      GlobalKey<IssueSelectorWidgetState>();

  @override
  void initState() {
    super.initState();

    _connectWebSocket();
  }

  void _connectWebSocket() {
    setState(() {
      isConnecting = true;
    });

    // Close existing channel if present
    channel?.sink.close();
    channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.1.132:8000/ws/$selectedChannel'),
    );

    channel!.stream.listen(
      (message) {
        setState(() {
          isConnecting = false;
        });

        final decoded = jsonDecode(message);
        print('🔔 Message on $selectedChannel: $decoded');

        if (decoded['trigger'] == true) {
          setState(() {
            objectId = decoded['objectId'] ?? '';
            hasBeenEvaluated = false;
            issuesSubmitted = decoded['issuesSubmitted'] ?? false;
            _issues.clear();
          });
        } else if (decoded['trigger'] == false) {
          setState(() {
            objectId = "";
            isObjectOK = false;
            hasBeenEvaluated = false;
            issuesSubmitted = false;
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
      },
      onDone: () {
        setState(() {
          isConnecting = false;
        });
      },
      onError: (error) {
        setState(() {
          isConnecting = false;
        });
      },
    );

    // Set a timeout for the connection status
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          isConnecting = false;
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
        issuesSubmitted = false;
        _connectWebSocket();
      });
    }
  }

  Future<void> _submitIssues() async {
    if (_issues.isEmpty) {
      showAddIssueWarningDialog(context);
      return;
    }

    final response = await http.post(
      Uri.parse('http://192.168.1.132:8000/api/set_issues'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'channel_id': selectedChannel,
        'object_id': objectId,
        'issues': _issues.toList(),
      }),
    );

    if (response.statusCode == 200) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Issues sent successfully")),
      );
      setState(() {
        _issues.clear();
      });

      issuesSubmitted = true;
      _issueSelectorKey.currentState?.resetSelection();
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${response.body}")),
      );
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'DIFETTI',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.black87,
            letterSpacing: 1.0,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedChannel,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                ),
                items: availableChannels.map((channel) {
                  return DropdownMenuItem(
                    value: channel,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: channel == selectedChannel
                                ? Colors.blueAccent
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(channel),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _onChannelChange,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (isConnecting)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Connessione a $selectedChannel...",
                        style: TextStyle(
                          color: Colors.blueGrey.shade800,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (objectId.isNotEmpty) ...[
                          ObjectCard(
                            objectId: objectId,
                            isObjectOK: isObjectOK,
                            hasBeenEvaluated: hasBeenEvaluated,
                            selectedChannel: selectedChannel,
                            issuesSubmitted: issuesSubmitted,
                            onIssuesLoaded: (loadedIssues) {
                              setState(() {
                                _issues.clear();
                                _issues.addAll(loadedIssues);
                                issuesSubmitted =
                                    false; // this triggers IssueSelector to appear
                              });

                              // Defer restore after widget is built
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _issueSelectorKey.currentState
                                    ?.restoreSelection(loadedIssues);
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                        ] else ...[
                          Center(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  color: Colors.grey,
                                  size: 32,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Nessun oggetto in produzione',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (hasBeenEvaluated &&
                            !isObjectOK &&
                            !issuesSubmitted) ...[
                          const Text(
                            'Seleziona i problemi rilevati',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          IssueSelectorWidget(
                            key: _issueSelectorKey, // pass key
                            channelId: selectedChannel,
                            onIssueSelected: (issuePath) {
                              setState(() {
                                if (_issues.contains(issuePath)) {
                                  _issues.remove(issuePath);
                                } else {
                                  _issues.add(issuePath);
                                }
                              });
                            },
                          ),
                        ] else if (hasBeenEvaluated &&
                            !isObjectOK &&
                            issuesSubmitted) ...[
                          const SizedBox(height: 40),
                          Center(
                            child: Text(
                              'ANDARE A PREMERE PULSANTE KO FISICO',
                              style: TextStyle(fontSize: 36),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (hasBeenEvaluated && !isObjectOK)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _issues.isNotEmpty ? _submitIssues : null,
                        icon: Icon(
                          Icons.send,
                          size: 26,
                          color: _issues.isNotEmpty
                              ? Colors.white
                              : Colors.grey.shade400,
                        ), // bigger icon
                        label: const Text(
                          'INVIA',
                          style: TextStyle(
                            fontSize: 18, // bigger text
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _issues.isNotEmpty
                              ? Colors.blueAccent
                              : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 20), // more padding
                          elevation: _issues.isNotEmpty ? 6 : 0,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
