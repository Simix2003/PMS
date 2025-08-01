// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_print, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import '../../shared/models/globals.dart';
import '../../shared/services/socket_service.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/object_card.dart';
import '../../shared/services/api_service.dart';
import '../issue_selector.dart';
import '../manuali/manualSelection_page.dart';
import '../picture_page.dart';

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
  final WebSocketService webSocketService = WebSocketService();
  final WebSocketService warningswebSocketService = WebSocketService();
  final ApiService apiService = ApiService();
  List<Map<String, dynamic>> warnings = [];
  final Set<String> shownWarningTimestamps = {};
  final List<Map<String, dynamic>> _warningDialogQueue = [];
  bool _isDialogShowing = false;

  bool cicloIniziato = false;
  bool pezzoOK = false;
  bool pezzoKO = false;

  bool canAdd = true;
  bool canSubmit = false;

  String plcStatus = "CHECKING"; // or values like "CONNECTED", "DISCONNECTED"

  // STATIONS //Should get from MySQL : stations
  String selectedChannel = ""; // Force user to pick a channel
  List<String> availableChannels = [""];
  Map<String, String> stationDisplayNames = {
    '': '🔧 Selezionare Stazione',
  };

  // LINES //Should get from MySQL : production_lines
  String selectedLine = "Linea2";

  List<Map<String, String>> _pictures = [];

  bool issuesSubmitted = false;

  final GlobalKey<IssueSelectorWidgetState> _issueSelectorKey =
      GlobalKey<IssueSelectorWidgetState>();

  final TextEditingController _objectIdController = TextEditingController();
  Set<String> _previouslySelectedIssues = {};

  @override
  void initState() {
    super.initState();
    _listenToVisibilityChange();
    _startup();
  }

  Future<void> _reloadStations() async {
    final response = await apiService.getQGStations(lineName: selectedLine);
    if (response != null && response["stations"] != null) {
      final stations = response["stations"] as List<dynamic>;
      setState(() {
        availableChannels = [""];
        stationDisplayNames = {'': '🔧 Selezionare Stazione'};
        for (var s in stations) {
          final name = s["name"];
          final displayName = s["display_name"];
          availableChannels.add(name);
          stationDisplayNames[name] = displayName;
        }
        if (!availableChannels.contains(selectedChannel)) {
          selectedChannel = "";
        }
      });
    }
  }

  Future<void> _startup() async {
    await _reloadStations();

    if (selectedChannel.isEmpty) return;
    _connectWebSocket();
    _fetchPLCStatus();
  }

  void _fetchPLCStatus() async {
    final status =
        await ApiService.fetchPLCStatus(selectedLine, selectedChannel);
    setState(() {
      plcStatus = status;
    });
  }

  void _connectWebSocket() {
    if (selectedChannel.isEmpty) return; // Prevent running on invalid selection
    setState(() {
      connectionStatus = ConnectionStatus.connecting;
    });

    webSocketService.connect(
      line: selectedLine,
      channel: selectedChannel,
      onMessage: (decoded) async {
        setState(() {
          connectionStatus = ConnectionStatus.online;
        });

        if (decoded.containsKey('plc_status')) {
          setState(() {
            plcStatus = decoded['plc_status'];
          });
        }

        if (decoded['trigger'] == true) {
          final newObjectId = decoded['objectId'] ?? '';
          final newStringatrice = decoded['stringatrice'] ?? '';

          setState(() {
            objectId = newObjectId;
            stringatrice = newStringatrice;
            hasBeenEvaluated = false;
            cicloIniziato = true;
            _issues.clear();
            _pictures.clear();
          });

          if (selectedChannel == "RMI01" && newObjectId.isNotEmpty) {
            try {
              final result = await ApiService.fetchInitialIssuesForObject(
                  selectedLine, selectedChannel, newObjectId, true);
              final previouslySelected = result['issue_paths'] as List<String>;
              final preloadedPictures =
                  result['pictures'] as List<Map<String, String>>;

              _previouslySelectedIssues = previouslySelected.toSet();

              setState(() {
                _issues.addAll(previouslySelected);
                _pictures = preloadedPictures;

                // Only allow submission if current issues differ from previous ones
                canSubmit = selectedChannel == "RMI01" &&
                        !_issues.containsAll(_previouslySelectedIssues) ||
                    !_previouslySelectedIssues.containsAll(_issues);
              });

              setState(() {
                _issues.addAll(previouslySelected);
                _pictures = preloadedPictures;
              });
            } catch (e) {
              print("❌ Error fetching rework issues: $e");
            }
          }
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

        if (decoded['outcome'] != null) {
          final outcome = decoded['outcome'];
          setState(() {
            pezzoOK = (outcome == "buona");
            pezzoKO = (outcome == "scarto");
            isObjectOK = (outcome == "buona");
            hasBeenEvaluated = true;
          });
        }
      },
      onError: (error) {
        setState(() {
          connectionStatus = ConnectionStatus.offline;
        });
        _retryWebSocket();
      },
      onDone: () {
        print("WebSocket closed");
      },
    );
    _loadWarningsAndSubscribe();
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
        selectedChannel = newChannel; // ✅ First update the state
        objectId = "";
        stringatrice = "";
        isObjectOK = false;
        hasBeenEvaluated = false;
        _issues.clear();
        issuesSubmitted = false;
      });

      // ✅ Then call logic that depends on selectedChannel
      _fetchPLCStatus();
      _connectWebSocket();
    }
  }

  Future<void> _submitIssues() async {
    if (_issues.isEmpty) {
      showAddIssueWarningDialog(context);
      return;
    }

    final confirm = await showAddIssueConfirmationDialog(context);
    if (!confirm) return;

    try {
      final success = await ApiService.submitIssues(
        selectedLine: selectedLine,
        selectedChannel: selectedChannel,
        objectId: objectId,
        issues: _issues.map((path) {
          final matching = _pictures.firstWhere(
            (img) => img["defect"] == path,
            orElse: () => {"image": ""},
          );

          return {
            "path": path,
            "image_base64": matching["image"] ?? "",
          };
        }).toList(),
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Difetti inviati con successo")),
        );
        setState(() {
          _issues.clear();
          issuesSubmitted = true;
        });
      }
    } catch (e) {
      final errorText = e.toString();
      final brokenImageMatch =
          RegExp(r'Invalid image for defect path: (.+)$').firstMatch(errorText);
      final isImageError = brokenImageMatch != null;
      final brokenDefect = brokenImageMatch?.group(1)?.trim();

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text("Errore"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "C'è stato un problema durante l'invio dei difetti. fai una foto a questa pagina ti prego e falla vedere al ragazzo che di solito aggiorna i tablet così riesco a capire cosa è successo, ti prego, ti prego, ti prego, '-' ",
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                      isImageError
                          ? Icons.camera_alt_outlined
                          : Icons.report_problem_outlined,
                      color: isImageError ? Colors.orange : Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorText,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (isImageError)
              TextButton.icon(
                icon: const Icon(Icons.replay, color: Colors.blue),
                label: const Text("Ripeti foto"),
                onPressed: () {
                  if (brokenDefect != null) {
                    _pictures
                        .removeWhere((img) => img["defect"] == brokenDefect);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text("Foto rimossa per: $brokenDefect")),
                    );
                  }
                  Navigator.of(context).pop();
                },
              ),
            TextButton(
              child: const Text("Chiudi"),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }

  Future<void> showWarningDialog(
    Map<String, dynamic> packet, {
    required BuildContext dialogContext,
    void Function(String base64Image)? onPictureTaken,
    void Function(String timestamp)? onIgnoreWarning,
  }) async {
    if (!mounted) return;

    final line = packet['line_name'] ?? '-';
    final station = packet['station_display'] ?? '-';
    final defect = packet['defect'] ?? '-';
    final type = packet['type'] ?? '-';
    final typeView =
        type == "threshold" ? "NG in Range di Moduli" : "NG Consecutivi";
    final value = packet['value']?.toString() ?? '-';
    final limit = packet['limit']?.toString() ?? '-';
    final timestamp = packet['timestamp'];

    AwesomeDialog(
      context: dialogContext,
      dialogType: DialogType.warning,
      width: 750,
      animType: AnimType.bottomSlide,
      customHeader: const Icon(
        Icons.warning_rounded,
        color: Colors.amber,
        size: 70,
      ),
      titleTextStyle: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      descTextStyle: const TextStyle(
        fontSize: 18,
        color: Colors.black87,
      ),
      title: '⚠️ Avviso inviato alla Stringatrice',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          const Text(
            "È stato inviato un avviso alla stringatrice per il seguente motivo:",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _buildCenteredInfo("Stazione", station),
          _buildCenteredInfo("Difetto", defect),
          _buildCenteredInfo("Tipo", typeView),
          _buildCenteredInfo("Valore", "$value / $limit", alert: true),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            "Vuoi allegare anche una foto per aiutare l'operatore della stringatrice a identificare meglio il problema?",
            style: TextStyle(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
      btnOkText: '📸 Scatta una foto e invia',
      btnOkColor: Colors.orange,
      btnOkOnPress: () async {
        final res = await Navigator.push(
          dialogContext,
          MaterialPageRoute(
            builder: (dialogContext) => const TakePicturePage(),
          ),
        );

        if (res != null && res is String) {
          final success = await ApiService.suppressWarningWithPhoto(
            line,
            timestamp,
            res,
          );

          if (success && mounted) {
            setState(() {
              warnings.removeWhere((w) => w['timestamp'] == timestamp);
            });

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text("📸 Foto inviata e avviso aggiornato"),
                  ),
                );
              }
            });
          }
        }
      },
      btnCancelText: '🚫 Ignora questo avviso',
      btnCancelColor: Colors.redAccent,
      btnCancelOnPress: () async {
        final success = await ApiService.suppressWarning(line, timestamp);
        if (success && mounted) {
          setState(() {
            warnings.removeWhere((w) => w['timestamp'] == timestamp);
          });

          ScaffoldMessenger.of(dialogContext).showSnackBar(
            const SnackBar(
              content: Text("👁️‍🗨️ Avviso ignorato per questa stazione"),
            ),
          );
        }
      },
    ).show();
  }

  Widget _buildCenteredInfo(String label, String value, {bool alert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: "$label: ",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: alert ? Colors.redAccent : Colors.black87,
                fontSize: 18,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: FontWeight.w100,
                fontSize: 18,
                color: alert ? Colors.redAccent : Colors.black87,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _processNextWarningDialog() async {
    if (!mounted || _isDialogShowing || _warningDialogQueue.isEmpty) return;

    _isDialogShowing = true;
    final nextPacket = _warningDialogQueue.removeAt(0);

    // Use a fresh context by delaying execution to the next event loop
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await showWarningDialog(nextPacket, dialogContext: context);
      _isDialogShowing = false;
      _processNextWarningDialog();
    });
  }

  Future<void> _loadWarningsAndSubscribe() async {
    try {
      final existingWarnings =
          await ApiService.getUnacknowledgedWarnings(selectedLine);

      final relevantWarnings = existingWarnings
          .where((w) =>
              w['source_station'] == selectedChannel &&
              (w['suppress_on_source'] == null ||
                  w['suppress_on_source'] == false))
          .toList();

      setState(() {
        warnings = relevantWarnings;
      });

      for (var warning in relevantWarnings) {
        final timestamp = warning['timestamp'];
        if (!shownWarningTimestamps.contains(timestamp)) {
          shownWarningTimestamps.add(timestamp);
          _warningDialogQueue.add(warning);
        }
      }

      _processNextWarningDialog();

      warningswebSocketService.connectToStringatriceWarnings(
        line: selectedLine,
        onMessage: (packet) async {
          if (packet['source_station'] == selectedChannel) {
            setState(() {
              warnings.insert(0, packet);
            });

            final timestamp = packet['timestamp'];
            if (!shownWarningTimestamps.contains(timestamp)) {
              shownWarningTimestamps.add(timestamp);
              _warningDialogQueue.add(packet);
              _processNextWarningDialog();
            }
          } else {
            debugPrint(
              "⚠️ Ignored warning for station ${packet['source_station']} (this tablet is for $selectedChannel)",
            );
          }
        },
        onDone: () => debugPrint("⚠️ Warning socket closed"),
        onError: (e) => debugPrint("❌ Warning socket error: $e"),
      );
    } catch (e) {
      debugPrint("❌ Error loading warnings: $e");
    }
  }

  @override
  void dispose() {
    webSocketService.close();
    _objectIdController.dispose();
    super.dispose();
  }

  /*Future<void> _simulateTrigger() async {
    await ApiService.simulateTrigger(selectedLine, selectedChannel);
  }

  Future<void> _simulateOutcome(String outcome) async {
    await ApiService.simulateOutcome(selectedLine, selectedChannel, outcome);
  }

  Future<void> _simulateObjectId() async {
    final objectId = _objectIdController.text.trim();
    if (objectId.isEmpty) return;

    final success =
        await ApiService.simulateObjectId(selectedChannel, objectId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? "ObjectId scritto nel PLC!"
            : "Errore durante la scrittura dell'ObjectId"),
      ),
    );
  }

  Widget _buildObjectIdSetter() {
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

    final url = Uri.parse("http://192.168.0.10:8001/api/simulate_objectId");
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

  void _listenToVisibilityChange() {
    html.document.onVisibilityChange.listen((event) {
      if (!html.document.hidden!) {
        print('[🔁] Tab resumed — reconnecting WebSocket...');
        _onChannelChange(selectedChannel);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          tooltip: "Aggiorna",
          icon: const Icon(Icons.refresh, color: Colors.black87),
          onPressed: () {
            _fetchPLCStatus();
            _connectWebSocket(); // reconnect with new line(selectedChannel);
          },
        ),
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
            IconButton(
              tooltip: "Manuale",
              icon: const Icon(Icons.info_outline, color: Colors.blue),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManualSelectionPage(),
                  ),
                );
              },
            ),
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
                        onChanged: (newLine) async {
                          if (newLine != null && newLine != selectedLine) {
                            setState(() {
                              selectedLine = newLine;
                            });
                            await _reloadStations();
                            _fetchPLCStatus();
                            _connectWebSocket(); // reconnect with new line
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (connectionStatus == ConnectionStatus.retrying)
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
                                issuesSubmitted = false;
                              });
                            },
                            reWork: selectedChannel == "RMI01",
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
                            key: _issueSelectorKey,
                            selectedLine: selectedLine,
                            channelId: selectedChannel,
                            onIssueSelected: (issuePath) {
                              setState(() {
                                if (_issues.contains(issuePath)) {
                                  _issues.remove(issuePath);
                                } else {
                                  _issues.add(issuePath);
                                }

                                canSubmit = selectedChannel == "RMI01" &&
                                        (!_issues.containsAll(
                                                _previouslySelectedIssues) ||
                                            !_previouslySelectedIssues
                                                .containsAll(_issues)) ||
                                    selectedChannel != "RMI01";
                              });
                            },
                            onPicturesChanged: (pics) {
                              setState(() {
                                _pictures = pics;
                              });
                            },
                            canAdd: canAdd,
                            isReworkMode: selectedChannel == "RMI01",
                            initiallySelectedIssues: _issues.toList(),
                            initiallyCreatedPictures: _pictures.toList(),
                            objectId: objectId,
                          )
                        ] else if (hasBeenEvaluated &&
                            !isObjectOK &&
                            issuesSubmitted) ...[
                          const SizedBox(height: 40),
                          Center(
                            child: Text(
                              selectedChannel == "RMI01"
                                  ? 'Premere pulsante GOOD / NO GOOD su HMI'
                                  : 'Premere pulsante NO GOOD fisico',
                              style: const TextStyle(fontSize: 36),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (hasBeenEvaluated &&
                      !isObjectOK &&
                      selectedChannel != "RMI01" ||
                  canSubmit)
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
