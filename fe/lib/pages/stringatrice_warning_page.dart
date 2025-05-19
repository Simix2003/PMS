// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
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
    _reconnectTimer?.cancel();
    super.dispose();
  }

  String _getTypeInItalian(String type) {
    return type == 'threshold' ? 'NG, Range di Moduli' : 'NG, Consecutivi';
  }

  void _showImageDialog(BuildContext context, String base64Image) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: Colors.white,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth * 0.9,
              height: constraints.maxHeight * 0.8,
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Center(
                          child: InteractiveViewer(
                            child: Image.memory(
                              base64Decode(base64Image),
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.black),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Foto inviata dal Quality Gate",
                      style: TextStyle(color: Colors.white, fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatTimestamp(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final formattedDate =
          '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
      final formattedTime =
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      return "$formattedDate alle $formattedTime";
    } catch (e) {
      return isoString;
    }
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
                              "Stazione del Quality Gate: ${warning['source_station']}",
                            ),
                            _infoRow(
                              Icons.access_time,
                              "Data e ora: ${_formatTimestamp(warning['timestamp'])}",
                            ),
                            _infoRow(
                              Icons.settings,
                              "Tipo: ${_getTypeInItalian(warning['type'] ?? '')}",
                            ),

                            const SizedBox(height: 24),

                            if (warning['photo'] != null &&
                                warning['photo'].isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Center(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _showImageDialog(context, warning['photo']);
                                  },
                                  icon: const Icon(Icons.image_rounded,
                                      size: 28), // ⬅️ Bigger icon
                                  label: const Text(
                                    "Visualizza Immagine",
                                    style: TextStyle(
                                        fontSize: 18), // ⬅️ Bigger text
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 16), // ⬅️ More space
                                    minimumSize: const Size(200,
                                        60), // ⬅️ Ensures button isn’t tiny
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

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
                                  "Conferma Lettura",
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
    return LayoutBuilder(
      builder: (context, constraints) {
        double baseFontSize = constraints.maxWidth < 350 ? 16 : 20;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: baseFontSize + 10, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: baseFontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
