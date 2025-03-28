// ignore_for_file: deprecated_member_use, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../../shared/widgets/station_card.dart';

class DataViewPage extends StatefulWidget {
  const DataViewPage({super.key});

  @override
  _DataViewPageState createState() => _DataViewPageState();
}

class _DataViewPageState extends State<DataViewPage> {
  late final WebSocketChannel _summaryChannel;
  late Future<Map<String, dynamic>> _dataFuture;

  // select yesterday as date
  final DateTime _selectedDate = DateTime.now();
  DateTimeRange? _selectedRange;

  int selectedTurno = 1;

  String selectedLine = "Linea1";
  final List<String> availableLines = ["Linea1", "Linea2"];
  final Map<String, String> lineDisplayNames = {
    'Linea1': 'Linea A',
    'Linea2': 'Linea B',
  };

  final Map<String, String> stationDisplayNames = {
    'M308': 'M308 - QG2 di M306',
    'M309': 'M309 - QG2 di M307',
    'M326': 'M326 - RW1',
  };

  @override
  void initState() {
    super.initState();
    _initializeWebSocket(); // Initialize WebSocket connection
    _dataFuture = fetchData(); // Fetch initial data
  }

  @override
  void dispose() {
    _summaryChannel.sink
        .close(status.goingAway); // Close WebSocket when page is disposed
    super.dispose();
  }

  // Initialize the WebSocket channel for the selected line
  void _initializeWebSocket() {
    _summaryChannel = WebSocketChannel.connect(
      Uri.parse(
          'ws://192.168.0.10:8000/ws/summary/$selectedLine'), // WebSocket URL includes selected line
    );

    _summaryChannel.stream.listen((event) {
      print("🔁 Dashboard refresh event received");
      if (mounted) {
        setState(() {
          _dataFuture = fetchData(); // Refresh data on WebSocket event
        });
      }
    });
  }

  // Handle line change (update WebSocket connection and fetch new data)
  void _onLineChange(String? newLine) {
    if (newLine != null && newLine != selectedLine) {
      setState(() {
        selectedLine = newLine; // Update selected line
        _initializeWebSocket(); // Reinitialize WebSocket for the new line
        _dataFuture = fetchData(); // Fetch data for the new line
      });
    }
  }

  Future<Map<String, dynamic>> fetchData() async {
    String url;
    final date = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Update the URL to include the selected turno
    url =
        'http://192.168.0.10:8000/api/productions_summary?date=$date&line_name=$selectedLine&turno=$selectedTurno';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final jsonMap = json.decode(response.body);
      // Add the new fields to each station's data
      for (var station in jsonMap['stations'].values) {
        // If last object, esito, and last cycle time exist, include them
        station['last_object'] = station['last_object'] ?? 'No Data';
        station['last_esito'] = station['last_esito'] ?? 'No Data';
        station['last_cycle_time'] = station['last_cycle_time'] ?? 'No Data';
        station['last_in_time'] = station['last_in_time'] ?? 'No Data';
        station['last_out_time'] = station['last_out_time'] ?? 'No Data';
      }
      return Map<String, dynamic>.from(jsonMap);
    } else {
      throw Exception('Errore durante il caricamento dei dati');
    }
  }

  String _getDateTitle() {
    if (_selectedRange != null) {
      final from =
          DateFormat('d MMMM y', 'it_IT').format(_selectedRange!.start);
      final to = DateFormat('d MMMM y', 'it_IT').format(_selectedRange!.end);
      return '$from → $to';
    } else {
      return 'Oggi, ${DateFormat('d MMMM y', 'it_IT').format(_selectedDate)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Analisi Dati',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                const Text("Linea: ",
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: selectedLine,
                  icon: const Icon(Icons.arrow_drop_down),
                  items: availableLines.map((line) {
                    return DropdownMenuItem(
                      value: line,
                      child: Text(lineDisplayNames[line] ?? line),
                    );
                  }).toList(),
                  onChanged: (newLine) {
                    if (newLine != null && newLine != selectedLine) {
                      setState(() {
                        selectedLine = newLine;
                        _onLineChange(selectedLine);
                        _dataFuture = fetchData(); // Refresh data for new line
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          } else {
            final data = snapshot.data!;
            final stations = ['M308', 'M309', 'M326'];

            final maxY = stations.map((station) {
                  final counts =
                      data['stations'][station] as Map<String, dynamic>;
                  return (counts['good_count'] as int) +
                      (counts['bad_count'] as int);
                }).reduce((a, b) => a > b ? a : b) +
                20;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📅 Header Card with Chart and Date Range Picker
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _getDateTitle(),
                                style: const TextStyle(
                                    fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: [
                                  // Smooth Rounded Turno Selector using ToggleButtons
                                  ToggleButtons(
                                    isSelected: [1, 2, 3]
                                        .map((turno) => selectedTurno == turno)
                                        .toList(),
                                    onPressed: (index) {
                                      setState(() {
                                        selectedTurno =
                                            index + 1; // Set selected turno
                                        _dataFuture =
                                            fetchData(); // Refresh data based on selected turno
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(
                                        12), // Smooth rounded edges
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text("Turno 1\n06:00 - 14:00",
                                            textAlign: TextAlign.center),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text("Turno 2\n14:00 - 22:00",
                                            textAlign: TextAlign.center),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text("Turno 3\n22:00 - 06:00",
                                            textAlign: TextAlign.center),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 220,
                            child: BarChart(
                              BarChartData(
                                maxY: maxY.toDouble(),
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    tooltipBorder:
                                        BorderSide(color: Colors.grey.shade300),
                                    getTooltipItem:
                                        (group, groupIndex, rod, rodIndex) {
                                      return BarTooltipItem(
                                        rod.toY.toInt().toString(),
                                        TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                barGroups:
                                    stations.asMap().entries.map((entry) {
                                  final station = entry.value;
                                  final idx = entry.key;
                                  final counts = data['stations'][station]
                                      as Map<String, dynamic>;
                                  return BarChartGroupData(
                                    x: idx,
                                    barRods: [
                                      BarChartRodData(
                                        toY: (counts['good_count'] as int)
                                            .toDouble(),
                                        color: Colors.green,
                                        width: 20,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      BarChartRodData(
                                        toY: (counts['bad_count'] as int)
                                            .toDouble(),
                                        color: Colors.red,
                                        width: 20,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                    showingTooltipIndicators: [0, 1],
                                    barsSpace: 25,
                                  );
                                }).toList(),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize:
                                          48, // 👈 Increase this for 2 lines (default is ~32)
                                      getTitlesWidget:
                                          (double value, TitleMeta meta) {
                                        final stationCode =
                                            stations[value.toInt()];
                                        final label =
                                            stationDisplayNames[stationCode] ??
                                                stationCode;

                                        return SizedBox(
                                          width: 100,
                                          child: Text(
                                            label,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          value.toInt().toString(),
                                          style: const TextStyle(fontSize: 12),
                                          textAlign: TextAlign.center,
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  horizontalInterval: 10,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: Colors.grey.withOpacity(0.3),
                                      strokeWidth: 1,
                                      dashArray: [4, 4],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ...stations.map((station) {
                    final stationData =
                        data['stations'][station] as Map<String, dynamic>;
                    final visualName = stationDisplayNames[station] ?? station;
                    return StationCard(
                        station: visualName, stationData: stationData);
                  }).toList(),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
