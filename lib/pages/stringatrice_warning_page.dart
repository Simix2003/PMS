import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock/wakelock.dart';
import '../shared/services/api_service.dart';
import '../shared/services/socket_service.dart';
import 'settings_page.dart';

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

  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    Wakelock.enable();
    _loadWarningsAndSubscribe();
    _startReconnectChecker(); // 🟢 Start periodic reconnection checker
  }

  void _startReconnectChecker() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!socketService.isConnected) {
        debugPrint("🔁 Attempting to reconnect WebSocket...");
        socketService.close(); // Ensure clean disconnect
        _loadWarningsAndSubscribe(); // Try reconnect
      }
    });
  }

  Future<void> _loadWarningsAndSubscribe() async {
    try {
      final existingWarnings =
          await ApiService.getUnacknowledgedWarnings(selectedLine);
      setState(() {
        warnings = existingWarnings;
      });

      socketService.connectToStringatriceWarnings(
        line: selectedLine,
        onMessage: (packet) {
          setState(() {
            warnings.insert(0, packet);
          });
        },
        onDone: () => debugPrint("⚠️ Warning socket closed"),
        onError: (e) => debugPrint("❌ Warning socket error: $e"),
      );
    } catch (e) {
      debugPrint("❌ Error loading warnings: $e");
    }
  }

  void _onLineChange(String? newLine) {
    if (newLine != null && newLine != selectedLine) {
      setState(() {
        selectedLine = newLine;
        warnings.clear();
      });
      socketService.close();
      _loadWarningsAndSubscribe();
    }
  }

  @override
  void dispose() {
    socketService.close();
    Wakelock.disable();
    _reconnectTimer?.cancel();
    super.dispose();
  }

  String _getTypeInItalian(String type) {
    return type == 'threshold'
        ? 'Superamento NG nel Range di Moduli'
        : 'NG consecutivi';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.settings, color: Colors.black87),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          },
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Allarmi Stringatrici',
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: socketService.isConnected
                  ? 'Connesso al server'
                  : 'Disconnesso. Tentativo di riconnessione...',
              child: Icon(
                socketService.isConnected
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded,
                color: socketService.isConnected ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Text(
                  "Linea:",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButton<String>(
                    value: selectedLine,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF007AFF)),
                    underline: Container(),
                    borderRadius: BorderRadius.circular(16),
                    items: availableLines.map((line) {
                      return DropdownMenuItem(
                        value: line,
                        child: Text(
                          lineDisplayNames[line] ?? line,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: _onLineChange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: warnings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.verified, size: 60, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    "Nessun allarme",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: warnings.length,
              itemBuilder: (context, index) {
                final warning = warnings[index];
                String stationNumber = warning['station_display'] ?? '';

                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(color: Colors.red.shade400, width: 2),
                  ),
                  child: Column(
                    children: [
                      // Header with station number
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "STRINGATRICE $stationNumber",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Warning details
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Problem highlight box
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "PROBLEMA RILEVATO:",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "${warning['defect']}",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Additional information
                            _infoRow(
                              Icons.perm_identity,
                              "Codice: ${warning['station_name']}",
                            ),
                            _infoRow(
                              Icons.access_time,
                              "Data e ora: ${warning['timestamp']}",
                            ),
                            _infoRow(
                              Icons.show_chart,
                              "Valore: ${warning['value']} (limite: ${warning['limit']})",
                            ),
                            _infoRow(
                              Icons.settings,
                              "Tipo: ${_getTypeInItalian(warning['type'] ?? '')}",
                            ),

                            const SizedBox(height: 24),

                            // Acknowledge button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.check_circle,
                                  size: 28,
                                ),
                                label: const Text(
                                  "CONFERMA LETTURA",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: () async {
                                  try {
                                    await ApiService.acknowledgeWarning(
                                        warning['id']);
                                    setState(() {
                                      warnings.removeAt(index);
                                    });
                                  } catch (e) {
                                    debugPrint("❌ Errore conferma: $e");
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
