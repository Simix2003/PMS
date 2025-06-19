// ignore_for_file: library_private_types_in_public_api, non_constant_identifier_names, avoid_print

import 'dart:async';

import 'package:flutter/material.dart';
import '../../shared/models/globals.dart';
import '../../shared/services/api_service.dart';
import '../../shared/services/socket_service.dart';
import 'escalation_visual.dart';
import 'shimmer_placeHolder.dart';
import 'visual_widgets.dart';
import 'package:gauge_indicator/gauge_indicator.dart';

class VisualPage extends StatefulWidget {
  final String zone;
  const VisualPage({super.key, required this.zone});

  @override
  _VisualPageState createState() => _VisualPageState();
}

class _VisualPageState extends State<VisualPage> {
  final WebSocketService _webSocketService = WebSocketService();
  bool _isWebSocketConnected = false;
  Color errorColor = Colors.amber.shade700;
  Color redColor = Colors.red;
  Color warningColor = Colors.yellow.shade400;
  Color okColor = Colors.green.shade400;
  Color textColor = Colors.black;
  double circleSize = 32;
  bool isLoading = true;

  int station_1_status = 1;
  int station_2_status = 1;

  int ng_bussingOut_1 = 0;
  int ng_bussingOut_2 = 0;
  int bussingIn_1 = 0;
  int bussingIn_2 = 0;
  int currentYield_1 = 100;
  int currentYield_2 = 100;

  int yield_target_1 = 90;
  int yield_target_2 = 90;
  int last_n_shifts = 3;

  int shift_target = 366;

  int availableTime_1 = 0;
  int availableTime_2 = 0;

  List<Map<String, dynamic>> yieldLast8h_1 = [];
  List<Map<String, dynamic>> yieldLast8h_2 = [];
  List<Map<String, dynamic>> shiftThroughput = [];
  List<Map<String, dynamic>> hourlyThroughput = [];
  List<Map<String, dynamic>> station1Shifts = [];
  List<Map<String, dynamic>> station2Shifts = [];
  List<Map<String, dynamic>> mergedShiftData = [];
  List<List<String>> dataFermi = [];

  List<Map<String, int>> throughputData = [];
  List<String> shiftLabels = [];
  List<Map<String, int>> hourlyData = [];
  List<String> hourLabels = [];

  //final List<String> defectLabels = ['NG Macchie ECA', 'NG Saldatura', 'NG Bad Soldering', 'NG Mancanza l_Ribbon', 'NG Celle Rotte'];
  List<String> defectLabels = [];
  //final List<int> ain1Counts = [17, 8, 9, 7, 3];
  List<int> ain1Counts = [];
  //final List<int> ain2Counts = [4, 5, 0, 1, 2];
  List<int> ain2Counts = [];

  Timer? _hourlyRefreshTimer;

  Color getYieldColor(int value, int target) {
    if (value >= target) {
      return okColor; // GREEN
    } else if (value >= target - 5) {
      return warningColor; // ORANGE
    } else {
      return errorColor; // RED
    }
  }

  Color getNgColor(int ngCount, int inCount) {
    if (inCount == 0) return redColor; // fallback to red if division by zero

    final percent = (ngCount / inCount) * 100;

    if (percent > 5) {
      return redColor; // RED
    } else if (percent >= 2) {
      return errorColor; // ORANGE
    } else {
      return okColor; // GREEN
    }
  }

  Color getStationColor(int value) {
    if (value == 1) {
      return okColor;
    } else if (value == 2) {
      return warningColor;
    } else if (value == 3) {
      return errorColor;
    } else {
      return Colors.black;
    }
  }

  Map<String, int> calculateEscalationCounts(
      List<Map<String, dynamic>> escalations) {
    final shiftManager =
        escalations.where((e) => e['status'] == 'SHIFT_MANAGER').length;
    final headOfProduction =
        escalations.where((e) => e['status'] == 'HEAD_OF_PRODUCTION').length;
    final closed = escalations.where((e) => e['status'] == 'CLOSED').length;

    return {
      'shiftManager': shiftManager,
      'headOfProduction': headOfProduction,
      'closed': closed,
    };
  }

  Future<void> fetchZoneData() async {
    try {
      final response = await ApiService.fetchZoneVisualData(widget.zone);
      setState(() {
        bussingIn_1 = response['station_1_in'] ?? 0;
        bussingIn_2 = response['station_2_in'] ?? 0;
        ng_bussingOut_1 = response['station_1_out_ng'] ?? 0;
        ng_bussingOut_2 = response['station_2_out_ng'] ?? 0;
        currentYield_1 = response['station_1_yield'] ?? 100;
        currentYield_2 = response['station_2_yield'] ?? 100;

        yieldLast8h_1 = List<Map<String, dynamic>>.from(
            response['station_1_yield_last_8h'] ?? []);
        yieldLast8h_2 = List<Map<String, dynamic>>.from(
            response['station_2_yield_last_8h'] ?? []);
        shiftThroughput =
            List<Map<String, dynamic>>.from(response['shift_throughput'] ?? []);
        hourlyThroughput = List<Map<String, dynamic>>.from(
            response['last_8h_throughput'] ?? []);
        station1Shifts = List<Map<String, dynamic>>.from(
            response['station_1_yield_shifts'] ?? []);
        station2Shifts = List<Map<String, dynamic>>.from(
            response['station_2_yield_shifts'] ?? []);

        mergedShiftData = List.generate(station1Shifts.length, (index) {
          return {
            'shift': station1Shifts[index]['label'],
            'bussing1': station1Shifts[index]['yield'],
            'bussing2': station2Shifts[index]['yield'],
          };
        });

        throughputData = shiftThroughput.map<Map<String, int>>((e) {
          final total = (e['total'] ?? 0) as int;
          final ng = (e['ng'] ?? 0) as int;
          return {'ok': total - ng, 'ng': ng};
        }).toList();

        shiftLabels =
            shiftThroughput.map((e) => e['label']?.toString() ?? '').toList();

        hourlyData = hourlyThroughput.map<Map<String, int>>((e) {
          final total = (e['total'] ?? 0) as int;
          final ng = (e['ng'] ?? 0) as int;
          return {'ok': total - ng, 'ng': ng};
        }).toList();

        hourLabels =
            hourlyThroughput.map((e) => e['hour']?.toString() ?? '').toList();

        // Parse Top Defects QG2
        final topDefectsRaw =
            List<Map<String, dynamic>>.from(response['top_defects_qg2'] ?? []);

        defectLabels = [];
        ain1Counts = [];
        ain2Counts = [];

        for (final defect in topDefectsRaw) {
          defectLabels.add(defect['label']?.toString() ?? '');
          ain1Counts.add(int.tryParse(defect['ain1'].toString()) ?? 0);
          ain2Counts.add(int.tryParse(defect['ain2'].toString()) ?? 0);
        }

        // Parse fermi data
        final fermiRaw =
            List<Map<String, dynamic>>.from(response['fermi_data'] ?? []);

        dataFermi = []; // clear previous data

        for (final entry in fermiRaw) {
          if (entry.containsKey("Available_Time_1")) {
            availableTime_1 =
                int.tryParse(entry["Available_Time_1"].toString()) ?? 0;
          } else if (entry.containsKey("Available_Time_2")) {
            availableTime_2 =
                int.tryParse(entry["Available_Time_2"].toString()) ?? 0;
          } else {
            dataFermi.add([
              entry['causale']?.toString() ?? '',
              entry['station']?.toString() ?? '',
              entry['count']?.toString() ?? '0',
              entry['time']?.toString() ?? '0'
            ]);
          }
        }

        isLoading = false;
      });
    } catch (e) {
      print("❌ Error fetching zone data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _initializeWebSocket() {
    if (_isWebSocketConnected) return;
    _webSocketService.connectToVisual(
      line: 'Linea2',
      zone: widget.zone,
      onMessage: (data) {
        if (!mounted) return;

        setState(() {
          bussingIn_1 = data['station_1_in'] ?? 0;
          bussingIn_2 = data['station_2_in'] ?? 0;
          ng_bussingOut_1 = data['station_1_out_ng'] ?? 0;
          ng_bussingOut_2 = data['station_2_out_ng'] ?? 0;
          currentYield_1 = data['station_1_yield'] ?? 100;
          currentYield_2 = data['station_2_yield'] ?? 100;

          yieldLast8h_1 = List<Map<String, dynamic>>.from(
              data['station_1_yield_last_8h'] ?? []);
          yieldLast8h_2 = List<Map<String, dynamic>>.from(
              data['station_2_yield_last_8h'] ?? []);
          shiftThroughput =
              List<Map<String, dynamic>>.from(data['shift_throughput'] ?? []);
          hourlyThroughput =
              List<Map<String, dynamic>>.from(data['last_8h_throughput'] ?? []);
          station1Shifts = List<Map<String, dynamic>>.from(
              data['station_1_yield_shifts'] ?? []);
          station2Shifts = List<Map<String, dynamic>>.from(
              data['station_2_yield_shifts'] ?? []);

          mergedShiftData = List.generate(station1Shifts.length, (index) {
            return {
              'shift': station1Shifts[index]['label'],
              'bussing1': station1Shifts[index]['yield'],
              'bussing2': station2Shifts[index]['yield'],
            };
          });

          throughputData = shiftThroughput.map<Map<String, int>>((e) {
            final total = (e['total'] ?? 0) as int;
            final ng = (e['ng'] ?? 0) as int;
            return {'ok': total - ng, 'ng': ng};
          }).toList();

          shiftLabels =
              shiftThroughput.map((e) => e['label']?.toString() ?? '').toList();

          hourlyData = hourlyThroughput.map<Map<String, int>>((e) {
            final total = (e['total'] ?? 0) as int;
            final ng = (e['ng'] ?? 0) as int;
            return {'ok': total - ng, 'ng': ng};
          }).toList();

          hourLabels =
              hourlyThroughput.map((e) => e['hour']?.toString() ?? '').toList();
          // Parse fermi data also from WebSocket payload
          final fermiRaw =
              List<Map<String, dynamic>>.from(data['fermi_data'] ?? []);

          dataFermi = []; // clear previous data

          for (final entry in fermiRaw) {
            if (entry.containsKey("Available_Time_1")) {
              availableTime_1 =
                  int.tryParse(entry["Available_Time_1"].toString()) ?? 0;
            } else if (entry.containsKey("Available_Time_2")) {
              availableTime_2 =
                  int.tryParse(entry["Available_Time_2"].toString()) ?? 0;
            } else {
              dataFermi.add([
                entry['causale']?.toString() ?? '',
                entry['station']?.toString() ?? '',
                entry['count']?.toString() ?? '0',
                entry['time']?.toString() ?? '0'
              ]);
            }
          }
        });
      },
      onDone: () => print("🛑 Visual WebSocket closed"),
      onError: (err) => print("❌ WebSocket error: $err"),
    );
    _isWebSocketConnected = true;
  }

  @override
  void initState() {
    super.initState();
    fetchZoneData(); // initial REST fetch
    _initializeWebSocket(); // listen to updates after
    _startHourlyRefreshScheduler(); // Will wait for the next Hour change
  }

  void _startHourlyRefreshScheduler() {
    final now = DateTime.now();
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    final initialDelay = nextHour.difference(now);

    print("⏳ Scheduling first refresh in ${initialDelay.inSeconds} seconds");

    Future.delayed(initialDelay, () {
      print("🔁 Hourly refresh triggered");
      fetchZoneData();

      // Start regular hourly timer
      _hourlyRefreshTimer = Timer.periodic(Duration(hours: 1), (_) {
        print("🔁 Hourly refresh triggered (loop)");
        fetchZoneData();
      });
    });
  }

  @override
  void dispose() {
    _hourlyRefreshTimer?.cancel();
    _webSocketService.close();
    super.dispose();
  }

  void _refreshEscalationTrafficLight() {
    setState(() {
      // recalculates counts automatically
    });
  }

  @override
  Widget build(BuildContext context) {
    final counts = calculateEscalationCounts(escalations);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: isLoading
            ? buildShimmerPlaceholder()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ────── FIRST HEADER ROW ──────
                  Row(
                    children: [
                      Flexible(
                        flex: 4,
                        child: HeaderBox(
                          title: 'Produzione Shift',
                          target: '$shift_target moduli',
                          icon: Icons.solar_power,
                        ),
                      ),
                      Flexible(
                        flex: 3,
                        child: HeaderBox(
                          title: 'YIELD',
                          target: '$yield_target_1 %',
                          icon: Icons.show_chart,
                        ),
                      ),
                      Flexible(
                        flex: 2,
                        child: HeaderBox(
                          title: 'ESCALATION',
                          target: '',
                          icon: Icons.account_tree_outlined,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ────── VALUES FIRST ROW ──────
                  Row(
                    children: [
                      Flexible(
                        flex: 4,
                        child: Container(
                          height: 425,
                          margin: const EdgeInsets.only(right: 6, bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              // First row with 2 cards
                              Flexible(
                                child: Row(
                                  children: [
                                    Flexible(
                                      flex: 3,
                                      child: Column(
                                        children: [
                                          Flexible(
                                            child: Column(
                                              children: [
                                                // Row titles (aligned with the two card columns)
                                                Row(
                                                  children: [
                                                    const SizedBox(
                                                      width: 100,
                                                    ), // aligns with the AIN 1 / AIN 2 label
                                                    Flexible(
                                                      child: Center(
                                                        child: Text(
                                                          'Bussing IN',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 18,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 70),
                                                    Flexible(
                                                      child: Center(
                                                        child: Text(
                                                          'NG Bussing OUT',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 18,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                const SizedBox(height: 8),

                                                // First row of cards
                                                Flexible(
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        'AIN 1',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 24,
                                                          color: Colors.black,
                                                        ),
                                                      ),

                                                      // 🔴 First Circle
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        width: circleSize,
                                                        height: circleSize,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: getStationColor(
                                                              station_1_status),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),

                                                      const SizedBox(width: 8),
                                                      Flexible(
                                                        child: Card(
                                                          color: Colors.white,
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              border:
                                                                  Border.all(
                                                                color:
                                                                    textColor,
                                                                width: 1,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                            ),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        12),
                                                            child: Center(
                                                              child: Text(
                                                                bussingIn_1
                                                                    .toString(),
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 32,
                                                                  color:
                                                                      textColor,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                      const SizedBox(width: 24),

                                                      // 🟢 Second Circle
                                                      Container(
                                                        width: circleSize,
                                                        height: circleSize,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: getNgColor(
                                                            ng_bussingOut_1,
                                                            bussingIn_1,
                                                          ),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),

                                                      const SizedBox(width: 8),

                                                      Flexible(
                                                        child: Card(
                                                          color: Colors.white,
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              border:
                                                                  Border.all(
                                                                color:
                                                                    textColor,
                                                                width: 1,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                            ),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        12),
                                                            child: Center(
                                                              child: Text(
                                                                ng_bussingOut_1
                                                                    .toString(),
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 32,
                                                                  color:
                                                                      textColor,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),

                                                // Second row of cards
                                                Flexible(
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        'AIN 2',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 24,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),

                                                      Container(
                                                        width: circleSize,
                                                        height: circleSize,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: getStationColor(
                                                              station_2_status),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Flexible(
                                                        child: Card(
                                                          color: Colors.white,
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              border:
                                                                  Border.all(
                                                                color:
                                                                    textColor,
                                                                width: 1,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                            ),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        12),
                                                            child: Center(
                                                              child: Text(
                                                                bussingIn_2
                                                                    .toString(),
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 32,
                                                                  color:
                                                                      textColor,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 24),
                                                      // 🟢 Second Circle
                                                      Container(
                                                        width: circleSize,
                                                        height: circleSize,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: getNgColor(
                                                            ng_bussingOut_2,
                                                            bussingIn_2,
                                                          ),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Flexible(
                                                        child: Card(
                                                          color: Colors.white,
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              border:
                                                                  Border.all(
                                                                color:
                                                                    textColor,
                                                                width: 1,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                            ),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        12),
                                                            child: Center(
                                                              child: Text(
                                                                ng_bussingOut_2
                                                                    .toString(),
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 32,
                                                                  color:
                                                                      textColor,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ThroughputBarChart(
                                      data: throughputData,
                                      labels: shiftLabels,
                                      globalTarget: shift_target.toDouble(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Second row with 1 card that fills all remaining space
                              Flexible(
                                child: HourlyBarChart(
                                  data: hourlyData,
                                  hourLabels: hourLabels,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Flexible(
                        flex: 3,
                        child: Container(
                          height: 425,
                          margin: const EdgeInsets.only(right: 6, bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              // First row with 2 cards
                              Flexible(
                                child: Row(
                                  children: [
                                    Flexible(
                                      flex: 1,
                                      child: Column(
                                        children: [
                                          Flexible(
                                            child: Column(
                                              children: [
                                                // Row titles
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Center(
                                                        child: Text(
                                                          'Yield media (Shift)',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                const SizedBox(height: 8),

                                                // First row of cards
                                                Flexible(
                                                  child: Row(
                                                    children: [
                                                      // Circle
                                                      Container(
                                                        width: circleSize,
                                                        height: circleSize,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: getYieldColor(
                                                            currentYield_1,
                                                            yield_target_1,
                                                          ),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),

                                                      const SizedBox(
                                                        width: 8,
                                                      ),

                                                      Flexible(
                                                        child: Card(
                                                          color: Colors.white,
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              border:
                                                                  Border.all(
                                                                color:
                                                                    textColor,
                                                                width: 1,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                            ),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        12),
                                                            child: Center(
                                                              child: Text(
                                                                '${currentYield_1.toString()}%',
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 32,
                                                                  color:
                                                                      textColor,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // Second row of cards
                                                Flexible(
                                                  child: Row(
                                                    children: [
                                                      // Circle
                                                      Container(
                                                        width: circleSize,
                                                        height: circleSize,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: getYieldColor(
                                                            currentYield_2,
                                                            yield_target_2,
                                                          ),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),

                                                      const SizedBox(
                                                        width: 8,
                                                      ),
                                                      Flexible(
                                                        child: Card(
                                                          color: Colors.white,
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              border:
                                                                  Border.all(
                                                                color:
                                                                    textColor,
                                                                width: 1,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                            ),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        12),
                                                            child: Center(
                                                              child: Text(
                                                                '${currentYield_2.toString()}%',
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 32,
                                                                  color:
                                                                      textColor,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      flex: 3,
                                      child: YieldComparisonBarChart(
                                        data: mergedShiftData,
                                        target: 90,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Second row with 1 card that fills all remaining space
                              YieldLineChart(
                                hourlyData1: yieldLast8h_1,
                                hourlyData2: yieldLast8h_2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Flexible(
                        flex: 2,
                        child: Container(
                          height: 425,
                          margin: const EdgeInsets.only(bottom: 1),
                          padding: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(1),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Left side: Traffic light + text
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TrafficLightWithBackground(
                                        shiftManagerCount:
                                            counts['shiftManager'] ?? 0,
                                        headOfProductionCount:
                                            counts['headOfProduction'] ?? 0,
                                        closedCount: counts['closed'] ?? 0,
                                      ),
                                      const SizedBox(height: 8),
                                      (last_n_shifts > 0)
                                          ? Text(
                                              'Ultimi $last_n_shifts Shift',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : Text(
                                              'Ultimo Shift',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ],
                                  ),
                                  const SizedBox(
                                    width: 48,
                                  ),

                                  // Right side: Escalation button
                                  EscalationButton(
                                    last_n_shifts: last_n_shifts,
                                    onEscalationsUpdated:
                                        _refreshEscalationTrafficLight,
                                  ),
                                ],
                              ),
                              Spacer(),

                              // Legend
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LegendRow(
                                      color: errorColor,
                                      role: 'Head of production',
                                      time: '> 4h'),
                                  SizedBox(height: 8),
                                  LegendRow(
                                      color: warningColor,
                                      role: 'Shift Manager',
                                      time: '2h << 4h'),
                                  SizedBox(height: 8),
                                  LegendRow(
                                      color: okColor, role: 'Chiusi', time: ''),
                                ],
                              ),
                              SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ────── SECOND HEADER ROW ──────
                  Row(
                    children: [
                      // LEFT SIDE – UPTIME/DOWNTIME
                      Flexible(
                        flex: 3,
                        child: HeaderBox(
                          title: 'UPTIME/DOWNTIME Shift',
                          target: '',
                          icon: Icons.timer_outlined,
                        ),
                      ),

                      // RIGHT SIDE – Pareto + NG Card
                      Flexible(
                        flex: 3,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /*SizedBox(
                              height: 65,
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                color: warningColor,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  child: Text(
                                    '23',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),*/
                            const Flexible(
                              child: HeaderBox(
                                title: 'Pareto Shift',
                                target: '',
                                icon: Icons.bar_chart_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ────── SECOND ROW ──────
                  Row(
                    children: [
                      Flexible(
                        flex: 3,
                        child: Container(
                          height: 400,
                          margin: const EdgeInsets.only(right: 6, bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              // LEFT COLUMN (2 stacked rows)
                              Flexible(
                                flex: 2,
                                child: Column(
                                  children: [
                                    Flexible(
                                      child: Card(
                                        elevation: 10,
                                        color: Colors.white,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Text(
                                                'Available \nTime\nAIN1',
                                                style: TextStyle(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Column(
                                                children: [
                                                  SizedBox(
                                                    width: 200, // radius * 2
                                                    child: Column(
                                                      children: [
                                                        AnimatedRadialGauge(
                                                          duration:
                                                              const Duration(
                                                                  milliseconds:
                                                                      800),
                                                          curve:
                                                              Curves.easeInOut,
                                                          value: availableTime_1
                                                              .toDouble(),
                                                          radius: 100,
                                                          axis: GaugeAxis(
                                                            min: 0,
                                                            max: 100,
                                                            degrees: 180,
                                                            style:
                                                                const GaugeAxisStyle(
                                                              thickness: 16,
                                                              background: Color(
                                                                  0xFFDDDDDD),
                                                              segmentSpacing: 0,
                                                            ),
                                                            progressBar:
                                                                GaugeRoundedProgressBar(
                                                              color: () {
                                                                if (availableTime_1 <=
                                                                    50) {
                                                                  return errorColor;
                                                                }
                                                                if (availableTime_1 <=
                                                                    75) {
                                                                  return warningColor;
                                                                }
                                                                return okColor;
                                                              }(),
                                                            ),
                                                          ),
                                                          builder: (context,
                                                              child, value) {
                                                            return Center(
                                                              child: Text(
                                                                '${value.toInt()}%',
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 32,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                        const SizedBox(
                                                            height: 6),
                                                        const Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text('0%',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        14)),
                                                            Text('100%',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        14)),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    //const TopDefectsPieChart(),
                                    Flexible(
                                      child: Card(
                                        elevation: 10,
                                        color: Colors.white,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Text(
                                                'Available \nTime\nAIN2',
                                                style: TextStyle(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Column(
                                                children: [
                                                  SizedBox(
                                                    width: 200, // radius * 2
                                                    child: Column(
                                                      children: [
                                                        AnimatedRadialGauge(
                                                          duration:
                                                              const Duration(
                                                                  milliseconds:
                                                                      800),
                                                          curve:
                                                              Curves.easeInOut,
                                                          value: availableTime_2
                                                              .toDouble(),
                                                          radius: 100,
                                                          axis: GaugeAxis(
                                                            min: 0,
                                                            max: 100,
                                                            degrees: 180,
                                                            style:
                                                                const GaugeAxisStyle(
                                                              thickness: 16,
                                                              background: Color(
                                                                  0xFFDDDDDD),
                                                              segmentSpacing: 0,
                                                            ),
                                                            progressBar:
                                                                GaugeRoundedProgressBar(
                                                              color: () {
                                                                if (availableTime_2 <=
                                                                    50) {
                                                                  return errorColor;
                                                                }
                                                                if (availableTime_2 <=
                                                                    75) {
                                                                  return warningColor;
                                                                }
                                                                return okColor;
                                                              }(),
                                                            ),
                                                          ),
                                                          builder: (context,
                                                              child, value) {
                                                            return Center(
                                                              child: Text(
                                                                '${value.toInt()}%',
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 32,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                        const SizedBox(
                                                            height: 6),
                                                        const Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text('0%',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        14)),
                                                            Text('100%',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        14)),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(
                                                color: Colors.black, width: 1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Table(
                                              border: TableBorder.all(
                                                  color: Colors.black,
                                                  width: 0.5),
                                              columnWidths: const {
                                                0: FlexColumnWidth(2),
                                                1: FlexColumnWidth(1),
                                                2: FlexColumnWidth(1),
                                                3: FlexColumnWidth(1),
                                              },
                                              children: [
                                                const TableRow(
                                                  decoration: BoxDecoration(
                                                      color: Colors.white),
                                                  children: [
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.all(8),
                                                      child: Text(
                                                          "Tipo \nFermata",
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.all(8),
                                                      child: Text("Macchina",
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.all(4),
                                                      child: Text("Frequenza",
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.all(8),
                                                      child: Text(
                                                          "Fermo Cumulato (min)",
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                  ],
                                                ),
                                                ...buildCustomRows(dataFermi),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Flexible(
                        flex: 3,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: 400, // ← set your maximum height here
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Flexible(
                                  flex: 3,
                                  child: TopDefectsHorizontalBarChart(
                                    defectLabels: defectLabels,
                                    ain1Counts: ain1Counts,
                                    ain2Counts: ain2Counts,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // RIGHT COLUMN (1 full-height card)
                                /*Flexible(
                                  flex: 2,
                                  child: VPFDefectsHorizontalBarChart(),
                                ),*/
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
