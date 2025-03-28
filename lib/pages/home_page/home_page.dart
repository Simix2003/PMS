// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ix_monitor/pages/object_details/m326_page.dart';
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

enum ConnectionStatus { connecting, online, offline, retrying }

ConnectionStatus connectionStatus = ConnectionStatus.offline;

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  String objectId = "";
  String stringatrice = "";
  bool isObjectOK = false;
  bool hasBeenEvaluated = false;
  final Set<String> _issues = {};
  WebSocketChannel? channel;

  bool cicloIniziato = false;
  bool pezzoOK = false;
  bool pezzoKO = false;

  String plcStatus = "CHECKING"; // or values like "CONNECTED", "DISCONNECTED"

  // STATIONS
  String selectedChannel = "M308"; // Default selection
  final List<String> availableChannels = ["M308", "M309", "M326"];
  final Map<String, String> stationDisplayNames = {
    'M308': 'M308 - QG2 di M306',
    'M309': 'M309 - QG2 di M307',
    'M326': 'M326 - RW1',
  };

  // LINES
  String selectedLine = "Linea1";
  final List<String> availableLines = ["Linea1", "Linea2"];
  final Map<String, String> lineDisplayNames = {
    'Linea1': 'Linea A',
    'Linea2': 'Linea B',
  };

  bool issuesSubmitted = false;

  final GlobalKey<IssueSelectorWidgetState> _issueSelectorKey =
      GlobalKey<IssueSelectorWidgetState>();

  final TextEditingController _objectIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startup();
  }

  Future<void> _startup() async {
    _connectWebSocket();
    _fetchPLCStatus();
  }

  void _fetchPLCStatus() async {
    try {
      final response =
          await http.get(Uri.parse('http://192.168.0.10:8000/api/plc_status'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          plcStatus = data[selectedLine]?[selectedChannel] ?? "UNKNOWN";
        });
      } else {
        setState(() {
          plcStatus = "ERROR";
        });
      }
    } catch (e) {
      setState(() {
        plcStatus = "ERROR";
      });
    }
  }

  void _connectWebSocket() {
    print("🔄 Connecting to WebSocket...");
    setState(() {
      connectionStatus = ConnectionStatus.connecting;
    });

    // Close existing channel if present
    channel?.sink.close();

    channel = WebSocketChannel.connect(
      Uri.parse(
          'ws://192.168.0.10:8000/ws/$selectedLine/$selectedChannel'), // WebSocket URL with dynamic values
    );

    if (channel != null) {
      channel!.stream.listen(
        (message) {
          setState(() {
            connectionStatus = ConnectionStatus.online;
          });

          final decoded = jsonDecode(message);
          print('🔔 Message on $selectedChannel: $decoded');

          // Handling WebSocket message
          if (decoded.containsKey('plc_status')) {
            setState(() {
              plcStatus = decoded['plc_status'];
            });
          }

          // Handling 'trigger' state
          if (decoded['trigger'] == true) {
            setState(() {
              objectId = decoded['objectId'] ?? '';
              stringatrice = decoded['stringatrice'] ?? '';
              hasBeenEvaluated = false;
              issuesSubmitted = decoded['issuesSubmitted'] ?? false;
              cicloIniziato = true;
              _issues.clear();
            });
          } else if (decoded['trigger'] == false) {
            setState(() {
              objectId = "";
              stringatrice = "";
              isObjectOK = false;
              hasBeenEvaluated = false;
              issuesSubmitted = false;
              cicloIniziato = false;
              _issues.clear();
            });
          }

          // Outcome processing
          if (decoded['outcome'] != null) {
            final outcome = decoded['outcome']; // "buona" or "scarto"
            print("Outcome from PLC: $outcome");
            setState(() {
              pezzoOK = (outcome == "buona");
              pezzoKO = (outcome == "scarto");
              isObjectOK = (outcome == "buona");
              hasBeenEvaluated = true;
            });
          }
        },
        onDone: () {},
        onError: (error) {
          connectionStatus = ConnectionStatus.offline;
          _retryWebSocket();
        },
      );
    } else {
      print("🔄 Channel is null");
    }
  }

  void _retryWebSocket() {
    setState(() {
      connectionStatus = ConnectionStatus.retrying;
    });

    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _connectWebSocket();
      }
    });
  }

  void _onChannelChange(String? newChannel) {
    if (newChannel != null && newChannel != selectedChannel) {
      setState(() {
        _fetchPLCStatus();
        // Reset UI data when switching station
        selectedChannel = newChannel;
        objectId = "";
        stringatrice = "";
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

    final confirm = await showAddIssueConfirmationDialog(context);
    if (!confirm) return;

    final response = await http.post(
      Uri.parse('http://192.168.0.10:8000/api/set_issues'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'line_name': selectedLine,
        'channel_id': selectedChannel,
        'object_id': objectId,
        'issues': _issues.toList(),
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Difetti inviati con successo")),
      );
      setState(() {
        _issues.clear();
      });

      issuesSubmitted = true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore: ${response.body}")),
      );
    }
  }

  @override
  void dispose() {
    channel?.sink.close();
    _objectIdController.dispose();
    super.dispose();
  }

  Future<void> _simulateTrigger() async {
    await http.post(
      Uri.parse("http://192.168.0.10:8000/api/simulate_trigger"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "line_name": selectedLine,
        "channel_id": selectedChannel,
      }),
    );
  }

  Future<void> _simulateOutcome(String outcome) async {
    await http.post(
      Uri.parse("http://192.168.0.10:8000/api/simulate_outcome"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "line_name": selectedLine,
        "channel_id": selectedChannel,
        "value": outcome,
      }),
    );
  }

  /*Widget _buildObjectIdSetter() {
    return Container(
      width: 350,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            height: 20,
            child: TextField(
              controller: _objectIdController,
              decoration: const InputDecoration(
                hintText: 'Scrivi ObjectId...',
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.orange),
            onPressed: () {
              _simulateObjectId(); // Call the API
            },
          )
        ],
      ),
    );
  }

  Future<void> _simulateObjectId() async {
    final objectId = _objectIdController.text.trim();
    if (objectId.isEmpty) return;

    final url = Uri.parse("http://192.168.0.10:8000/api/simulate_objectId");
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "channel_id": selectedChannel,
        "objectId": objectId,
      }),
    );

    if (response.statusCode == 200) {
      debugPrint("✅ ObjectId sent successfully!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ObjectId scritto nel PLC!")),
      );
    } else {
      debugPrint("❌ Failed to send ObjectId: ${response.body}");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Errore durante la scrittura dell'ObjectId")),
      );
    }
  }*/

  Widget _buildStatusBadge(String label, Color color, {VoidCallback? onTap}) {
    final badge = Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 10),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );

    // Make it tappable only if onTap is provided
    return onTap != null
        ? GestureDetector(
            onTap: onTap,
            child: badge,
          )
        : badge;
  }

  Color _getPCColor() {
    switch (connectionStatus) {
      case ConnectionStatus.online:
        return Colors.green;
      case ConnectionStatus.connecting:
        return Colors.orange;
      case ConnectionStatus.retrying:
        return Colors.orange;
      case ConnectionStatus.offline:
        return Colors.red;
    }
  }

  Color _getPLCColor() {
    switch (plcStatus) {
      case "CONNECTED":
        return Colors.green;
      case "DISCONNECTED":
        return Colors.red;
      case "ERROR":
      case "UNKNOWN":
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            const Text(
              'DIFETTI',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: Colors.black87,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 12),
            _buildStatusBadge("PC", _getPCColor()),
            _buildStatusBadge("PLC", _getPLCColor()),
            /*_buildStatusBadge(
              "Ciclo Iniziato",
              cicloIniziato ? Colors.blue : Colors.grey,
              onTap: _simulateTrigger,
            ),
            _buildStatusBadge(
              "Pezzo OK",
              pezzoOK ? Colors.green : Colors.grey,
              onTap: () {
                _simulateOutcome("buona");
              },
            ),
            _buildStatusBadge(
              "Pezzo KO",
              pezzoKO ? Colors.red : Colors.grey,
              onTap: () {
                _simulateOutcome("scarto");
              },
            ),
            //const SizedBox(width: 20),
            //_buildObjectIdSetter(),*/
          ],
        ),
        actions: [
          // Dropdown + settings button (keep them as you have)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButtonHideUnderline(
              child: Row(
                children: [
                  // LINE DROPDOWN
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedLine,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Colors.black87),
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 14),
                        items: availableLines.map((line) {
                          return DropdownMenuItem(
                            value: line,
                            child: Text(
                              lineDisplayNames[line] ?? line,
                              style: const TextStyle(fontSize: 16),
                            ),
                          );
                        }).toList(),
                        onChanged: (newLine) {
                          if (newLine != null && newLine != selectedLine) {
                            setState(() {
                              selectedLine = newLine;
                              _fetchPLCStatus();
                              _connectWebSocket(); // reconnect with new line
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  // CHANNEL DROPDOWN (as-is)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedChannel,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Colors.black87),
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 14),
                        items: availableChannels.map((channel) {
                          return DropdownMenuItem(
                            value: channel,
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: channel == selectedChannel
                                        ? Colors.blueAccent
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  stationDisplayNames[channel] ?? channel,
                                  style: const TextStyle(fontSize: 18),
                                ),
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
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: selectedChannel == "M326"
            ? M326HomePage(context)
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (connectionStatus == ConnectionStatus.retrying)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
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
                              "Connessione a ${stationDisplayNames[selectedChannel] ?? selectedChannel}...",
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
                                  stringatrice: stringatrice,
                                  isObjectOK: isObjectOK,
                                  hasBeenEvaluated: hasBeenEvaluated,
                                  selectedLine: selectedLine,
                                  selectedChannel: selectedChannel,
                                  issuesSubmitted: issuesSubmitted,
                                  onIssuesLoaded: (loadedIssues) {
                                    setState(() {
                                      _issues.clear();
                                      _issues.addAll(loadedIssues);
                                      issuesSubmitted =
                                          false; // this triggers IssueSelector to appear
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
                                IssueSelectorWidget(
                                  key: _issueSelectorKey, // pass key
                                  selectedLine: selectedLine,
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
                              onPressed:
                                  _issues.isNotEmpty ? _submitIssues : null,
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
                                    horizontal: 32,
                                    vertical: 20), // more padding
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
