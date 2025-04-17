import 'package:flutter/material.dart';

import '../shared/services/socket_service.dart';

class WarningsPage extends StatefulWidget {
  const WarningsPage({super.key});

  @override
  State<WarningsPage> createState() => _WarningsPageState();
}

class _WarningsPageState extends State<WarningsPage> {
  final WebSocketService socketService = WebSocketService();
  List<Map<String, dynamic>> warnings = [];

  // LINES
  String selectedLine = "Linea2";
  final List<String> availableLines = ["Linea1", "Linea2", "Linea3"];
  final Map<String, String> lineDisplayNames = {
    'Linea1': 'Linea A',
    'Linea2': 'Linea B',
    'Linea3': 'Linea C',
  };

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
  }

  void _initializeWebSocket() {
    socketService.connectToWarnings(
      selectedLine: selectedLine,
      onMessage: (data) {
        setState(() {
          warnings.insert(0, data); // Newest first
        });
      },
      onError: (err) {
        print("❌ WebSocket error: $err");
      },
      onDone: () {
        print("🔌 WebSocket closed");
      },
    );
  }

  @override
  void dispose() {
    socketService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Warnings – $selectedLine'),
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
                              _initializeWebSocket();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: warnings.isEmpty
          ? const Center(child: Text("No warnings yet."))
          : ListView.builder(
              itemCount: warnings.length,
              itemBuilder: (context, index) {
                final warning = warnings[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 3,
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded,
                        color: Colors.red),
                    title: Text(
                      "${warning['station_display']} (${warning['station_name']})",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("❗ Defect: ${warning['defect']}"),
                        Text("📅 Time: ${warning['timestamp']}"),
                        Text(
                            "🔢 Value: ${warning['value']} / Limit: ${warning['limit']}"),
                        Text("⚙️ Trigger: ${warning['type']}"),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
