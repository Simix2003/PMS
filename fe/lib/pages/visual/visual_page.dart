// ignore_for_file: library_private_types_in_public_api, non_constant_identifier_names, avoid_print

import 'dart:async';

import 'package:flutter/material.dart';
import '../../shared/models/globals.dart';
import '../../shared/services/api_service.dart';
import '../../shared/services/socket_service.dart';
import 'shimmer_placeHolder.dart';
import 'visuals/AIN_page.dart';
import 'visuals/ELL_page.dart';
import 'visuals/VPF_page.dart';

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

  int last_n_shifts = 3;
  int yield_target = 90;
  int shift_target = 366;
  double hourly_shift_target = 45;

  int availableTime_1 = 0;
  int availableTime_2 = 0;

  int qg2_defects_value = 0;

  List<Map<String, dynamic>> yieldLast8h_1 = [];
  List<Map<String, dynamic>> yieldLast8h_2 = [];
  List<Map<String, dynamic>> shiftThroughput = [];
  List<Map<String, dynamic>> hourlyThroughput = [];
  List<Map<String, dynamic>> station1Shifts = [];
  List<Map<String, dynamic>> station2Shifts = [];
  List<Map<String, dynamic>> mergedShiftData = [];
  List<List<String>> dataFermi = [];

  List<Map<String, int>> throughputData = [];
  List<Map<String, int>> throughputDataEll = [];
  List<String> shiftLabels = [];
  List<Map<String, int>> hourlyData = [];
  List<String> hourLabels = [];

  //final List<String> defectLabels = ['NG Macchie ECA', 'NG Saldatura', 'NG Bad Soldering', 'NG Mancanza l_Ribbon', 'NG Celle Rotte'];
  List<String> defectLabels = [];
  List<String> defectVPFLabels = [];
  //final List<int> ain1Counts = [17, 8, 9, 7, 3];
  List<int> ain1Counts = [];
  List<int> ain1VPFCounts = [];
  //final List<int> ain2Counts = [4, 5, 0, 1, 2];
  List<int> ain2Counts = [];
  List<int> ain2VPFCounts = [];

  Timer? _hourlyRefreshTimer;

  // VPF
  int In_1 = 0;
  int ngOut_1 = 0;
  int reEntered_1 = 0;
  List<Map<String, dynamic>> speedRatioData = [];
  List<Map<String, dynamic>> defectsVPF = [];
  Map<String, Map<String, int>> eqDefects = {};
  List<int> VPFCounts = [];
  List<Map<String, dynamic>> bufferDefectSummary = [];

  int In_2 = 0;
  int ngScrap = 0;
  List<Map<String, dynamic>> FPY_yield_shifts = [];
  List<Map<String, dynamic>> RWK_yield_shifs = [];
  List<Map<String, dynamic>> FPYLast8h = [];
  List<Map<String, dynamic>> RWKLast8h = [];
  List<int> min1Counts = [];
  List<int> min2Counts = [];
  List<int> ellCounts = [];
  int currentFPYYield = 100;
  int currentRWKYield = 100;
  double value_gauge_1 = 0;
  double value_gauge_2 = 0;

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
    if (widget.zone == "AIN") {
      await fetchAinZoneData();
    } else if (widget.zone == "VPF") {
      await fetchVpfZoneData();
    } else if (widget.zone == "ELL") {
      await fetchEllZoneData();
    } else {
      print('Cannote fetch zone data Unknown zone: $widget.zone');
    }
  }

  Future<void> fetchAinZoneData() async {
    try {
      final response = await ApiService.fetchVisualDataForAin();
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

        qg2_defects_value = response['total_defects_qg2'];

        // Parse Top Defects VPF
        final topDefectsVPF =
            List<Map<String, dynamic>>.from(response['top_defects_vpf'] ?? []);

        defectVPFLabels = [];
        ain1VPFCounts = [];
        ain2VPFCounts = [];

        for (final defect in topDefectsVPF) {
          defectVPFLabels.add(defect['label']?.toString() ?? '');
          ain1VPFCounts.add(int.tryParse(defect['ain1'].toString()) ?? 0);
          ain2VPFCounts.add(int.tryParse(defect['ain2'].toString()) ?? 0);
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

  Future<void> fetchVpfZoneData() async {
    try {
      final response = await ApiService.fetchVisualDataForVpf();
      setState(() {
        // ─── Main Station Metrics ───────────────────────
        In_1 = response['station_1_in'] ?? 0;
        ngOut_1 = response['station_1_out_ng'] ?? 0;
        reEntered_1 = response['station_1_re_entered'] ?? 0;
        currentYield_1 = response['station_1_yield'] ?? 100;

        // ─── Yield + Shift ──────────────────────────────
        yieldLast8h_1 = List<Map<String, dynamic>>.from(
            response['station_1_yield_last_8h'] ?? []);
        station1Shifts =
            List<Map<String, dynamic>>.from(response['station_1_shifts'] ?? []);

        // ─── Speed Ratio Chart ──────────────────────────
        speedRatioData =
            List<Map<String, dynamic>>.from(response['speed_ratio'] ?? []);

        // ─── Defects Chart (VPF) ────────────────────────
        defectsVPF =
            List<Map<String, dynamic>>.from(response['defects_vpf'] ?? []);

        // ─── Equipment Defects (EQ) ─────────────────────
        eqDefects = (response['eq_defects'] != null)
            ? Map<String, Map<String, int>>.from(
                response['eq_defects'].map(
                  (k, v) => MapEntry(k, Map<String, int>.from(v as Map)),
                ),
              )
            : {};

        isLoading = false;
      });
    } catch (e) {
      print("❌ Error fetching VPF zone data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchEllZoneData() async {
    try {
      final response = await ApiService.fetchVisualDataForEll();
      setState(() {
        In_1 = response['station_1_in'] ?? 0;
        In_2 = response['station_2_in'] ?? 0;
        ngOut_1 = response['station_1_out_ng'] ?? 0;
        ngScrap = response['station_2_out_ng'] ?? 0;

        currentFPYYield = response['FPY_yield'] ?? 100;
        currentRWKYield = response['RWK_yield'] ?? 100;

        FPYLast8h = List<Map<String, dynamic>>.from(
            response['FPY_yield_last_8h'] ?? []);
        RWKLast8h = List<Map<String, dynamic>>.from(
            response['RWK_yield_last_8h'] ?? []);
        shiftThroughput =
            List<Map<String, dynamic>>.from(response['shift_throughput'] ?? []);
        hourlyThroughput = List<Map<String, dynamic>>.from(
            response['last_8h_throughput'] ?? []);
        FPY_yield_shifts =
            List<Map<String, dynamic>>.from(response['FPY_yield_shifts'] ?? []);
        RWK_yield_shifs =
            List<Map<String, dynamic>>.from(response['RWK_yield_shifts'] ?? []);

        mergedShiftData = List.generate(FPY_yield_shifts.length, (index) {
          return {
            'shift': FPY_yield_shifts[index]['label'],
            'FPY': FPY_yield_shifts[index]['yield'],
            'RWK': RWK_yield_shifs[index]['yield'],
          };
        });

        throughputDataEll = shiftThroughput.map<Map<String, int>>((e) {
          final total = (e['total'] ?? 0) as int;
          final ng = (e['ng'] ?? 0) as int;
          final scrap = (e['scrap'] ?? 0) as int;
          return {'ok': total - ng - scrap, 'ng': ng, 'scrap': scrap};
        }).toList();

        shiftLabels =
            shiftThroughput.map((e) => e['label']?.toString() ?? '').toList();

        hourlyData = hourlyThroughput.map<Map<String, int>>((e) {
          final total = (e['total'] ?? 0) as int;
          final ng = (e['ng'] ?? 0) as int;
          final scrap = (e['scrap'] ?? 0) as int;
          return {'ok': total - ng, 'ng': ng, 'scrap': scrap};
        }).toList();

        hourLabels =
            hourlyThroughput.map((e) => e['hour']?.toString() ?? '').toList();

        // Parse Top Defects QG2
        final topDefectsRaw =
            List<Map<String, dynamic>>.from(response['top_defects'] ?? []);

        defectLabels = [];
        min1Counts = [];
        min2Counts = [];
        ellCounts = [];

        for (final defect in topDefectsRaw) {
          defectLabels.add(defect['label']?.toString() ?? '');
          min1Counts.add(int.tryParse(defect['min1'].toString()) ?? 0);
          min2Counts.add(int.tryParse(defect['min2'].toString()) ?? 0);
          ellCounts.add(int.tryParse(defect['ell'].toString()) ?? 0);
        }

        value_gauge_1 =
            double.tryParse(response['value_gauge_1'].toString()) ?? 0;
        value_gauge_2 =
            double.tryParse(response['value_gauge_2'].toString()) ?? 0;

        // ─── Speed Ratio Chart ──────────────────────────
        speedRatioData =
            List<Map<String, dynamic>>.from(response['speed_ratio'] ?? []);

        isLoading = false;
      });
    } catch (e) {
      print("❌ Error fetching zone data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _initializeWebSocket() async {
    if (widget.zone == "AIN") {
      _initializeAinWebSocket();
    } else if (widget.zone == "VPF") {
      _initializeVpfWebSocket();
    } else if (widget.zone == "ELL") {
      _initializeEllWebSocket();
    } else {
      print('Cannot initialize websocket Unknown zone: $widget.zone');
    }
  }

  void _initializeAinWebSocket() {
    if (_isWebSocketConnected) return;

    _webSocketService.connectToVisual(
      line: 'Linea2',
      zone: widget.zone,
      onMessage: (data) {
        if (!mounted) return;

        setState(() {
          // ─── Main station metrics ─────────────────────
          bussingIn_1 = data['station_1_in'] ?? 0;
          bussingIn_2 = data['station_2_in'] ?? 0;
          ng_bussingOut_1 = data['station_1_out_ng'] ?? 0;
          ng_bussingOut_2 = data['station_2_out_ng'] ?? 0;
          currentYield_1 = data['station_1_yield'] ?? 100;
          currentYield_2 = data['station_2_yield'] ?? 100;

          // ─── Yield + Throughput 8h & shift ────────────
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

          // ─── Fermi Data ───────────────────────────────
          final fermiRaw =
              List<Map<String, dynamic>>.from(data['fermi_data'] ?? []);
          dataFermi = [];

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

          // ─── QG2 Defects ──────────────────────────────
          final topDefectsQG2 =
              List<Map<String, dynamic>>.from(data['top_defects_qg2'] ?? []);
          defectLabels = [];
          ain1Counts = [];
          ain2Counts = [];

          for (final defect in topDefectsQG2) {
            defectLabels.add(defect['label']?.toString() ?? '');
            ain1Counts.add(int.tryParse(defect['ain1'].toString()) ?? 0);
            ain2Counts.add(int.tryParse(defect['ain2'].toString()) ?? 0);
          }

          qg2_defects_value = data['total_defects_qg2'] ?? 0;

          // ─── VPF Defects ───────────────────────────────
          final topDefectsVPF =
              List<Map<String, dynamic>>.from(data['top_defects_vpf'] ?? []);
          defectVPFLabels = [];
          ain1VPFCounts = [];
          ain2VPFCounts = [];

          for (final defect in topDefectsVPF) {
            defectVPFLabels.add(defect['label']?.toString() ?? '');
            ain1VPFCounts.add(int.tryParse(defect['ain1'].toString()) ?? 0);
            ain2VPFCounts.add(int.tryParse(defect['ain2'].toString()) ?? 0);
          }
        });
      },
      onDone: () => print("🛑 Visual WebSocket closed"),
      onError: (err) => print("❌ WebSocket error: $err"),
    );

    _isWebSocketConnected = true;
  }

  void _initializeVpfWebSocket() {
    if (_isWebSocketConnected) return;

    _webSocketService.connectToVisual(
      line: 'Linea2',
      zone: widget.zone,
      onMessage: (data) {
        if (!mounted) return;

        setState(() {
          // ─── Main station metrics ─────────────────────
          In_1 = data['station_1_in'] ?? 0;
          ngOut_1 = data['station_1_out_ng'] ?? 0;
          reEntered_1 = data['station_1_re_entered'] ?? 0;
          currentYield_1 = data['station_1_yield'] ?? 100;

          yieldLast8h_1 = List<Map<String, dynamic>>.from(
              data['station_1_yield_last_8h'] ?? []);
          station1Shifts =
              List<Map<String, dynamic>>.from(data['station_1_shifts'] ?? []);

          // ─── Speed Ratio Chart ──────────────────────────
          speedRatioData =
              List<Map<String, dynamic>>.from(data['speed_ratio'] ?? []);

          // ─── Defects Chart (VPF) ────────────────────────
          defectsVPF =
              List<Map<String, dynamic>>.from(data['defects_vpf'] ?? []);

          // ─── Equipment Defects (EQ) ─────────────────────
          eqDefects = (data['eq_defects'] != null)
              ? Map<String, Map<String, int>>.from(
                  data['eq_defects'].map(
                    (k, v) => MapEntry(k, Map<String, int>.from(v as Map)),
                  ),
                )
              : {};
        });
      },
      onDone: () => print("🛑 Visual WebSocket closed"),
      onError: (err) => print("❌ WebSocket error: $err"),
    );

    _isWebSocketConnected = true;
  }

  void _initializeEllWebSocket() {
    if (_isWebSocketConnected) return;

    _webSocketService.connectToVisual(
      line: 'Linea2',
      zone: widget.zone,
      onMessage: (data) {
        if (!mounted) return;

        setState(() {
          // ─── Station Metrics ───────────────────────────
          In_1 = data['station_1_in'] ?? 0;
          In_2 = data['station_2_in'] ?? 0;
          ngOut_1 = data['station_1_out_ng'] ?? 0;
          ngScrap = data['station_2_out_ng'] ?? 0;

          currentFPYYield = data['FPY_yield'] ?? 100;
          currentRWKYield = data['RWK_yield'] ?? 100;

          // ─── Yield + Throughput ────────────────────────
          FPYLast8h =
              List<Map<String, dynamic>>.from(data['FPY_yield_last_8h'] ?? []);
          RWKLast8h =
              List<Map<String, dynamic>>.from(data['RWK_yield_last_8h'] ?? []);
          shiftThroughput =
              List<Map<String, dynamic>>.from(data['shift_throughput'] ?? []);
          hourlyThroughput =
              List<Map<String, dynamic>>.from(data['last_8h_throughput'] ?? []);
          FPY_yield_shifts =
              List<Map<String, dynamic>>.from(data['FPY_yield_shifts'] ?? []);
          RWK_yield_shifs =
              List<Map<String, dynamic>>.from(data['RWK_yield_shifts'] ?? []);

          mergedShiftData = List.generate(FPY_yield_shifts.length, (index) {
            return {
              'shift': FPY_yield_shifts[index]['label'],
              'FPY': FPY_yield_shifts[index]['yield'],
              'RWK': RWK_yield_shifs[index]['yield'],
            };
          });

          throughputDataEll = shiftThroughput.map<Map<String, int>>((e) {
            final total = (e['total'] ?? 0) as int;
            final ng = (e['ng'] ?? 0) as int;
            final scrap = (e['scrap'] ?? 0) as int;
            return {'ok': total - ng - scrap, 'ng': ng, 'scrap': scrap};
          }).toList();

          shiftLabels =
              shiftThroughput.map((e) => e['label']?.toString() ?? '').toList();

          hourlyData = hourlyThroughput.map<Map<String, int>>((e) {
            final total = (e['total'] ?? 0) as int;
            final ng = (e['ng'] ?? 0) as int;
            final scrap = (e['scrap'] ?? 0) as int;
            return {'ok': total - ng, 'ng': ng, 'scrap': scrap};
          }).toList();

          hourLabels =
              hourlyThroughput.map((e) => e['hour']?.toString() ?? '').toList();

          // ─── Defects Chart ─────────────────────────────
          final topDefectsRaw =
              List<Map<String, dynamic>>.from(data['top_defects'] ?? []);

          defectLabels = [];
          min1Counts = [];
          min2Counts = [];
          ellCounts = [];

          for (final defect in topDefectsRaw) {
            defectLabels.add(defect['label']?.toString() ?? '');
            min1Counts.add(int.tryParse(defect['min1'].toString()) ?? 0);
            min2Counts.add(int.tryParse(defect['min2'].toString()) ?? 0);
            ellCounts.add(int.tryParse(defect['ell'].toString()) ?? 0);
          }

          bufferDefectSummary = List<Map<String, dynamic>>.from(
              data['buffer_defect_summary'] ?? []);

          print('VALUESS: $bufferDefectSummary');

          value_gauge_1 =
              double.tryParse(data['value_gauge_1'].toString()) ?? 0;
          value_gauge_2 =
              double.tryParse(data['value_gauge_2'].toString()) ?? 0;

          // ─── Speed Ratio Chart ──────────────────────────
          speedRatioData =
              List<Map<String, dynamic>>.from(data['speed_ratio'] ?? []);
        });
      },
      onDone: () => print("Visual WebSocket closed"),
      onError: (err) => print("WebSocket error: $err"),
    );

    _isWebSocketConnected = true;
  }

  @override
  void initState() {
    super.initState();
    loadTargets();
    fetchZoneData();
    _initializeWebSocket();
    _startHourlyRefreshScheduler();
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

  Future<void> loadTargets() async {
    final targets = await ApiService.loadVisualTargets();
    if (targets != null) {
      setState(() {
        shift_target = targets['shift_target'] ?? 366;
        yield_target = targets['yield_target'] ?? 90;
        hourly_shift_target =
            (targets['hourly_shift_target'] ?? (shift_target ~/ 8)).toDouble();
      });
    }
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
            : widget.zone == "AIN"
                ? AinVisualsPage(
                    shift_target: shift_target,
                    hourly_shift_target: hourly_shift_target,
                    yield_target: yield_target,
                    circleSize: circleSize,
                    station_1_status: station_1_status,
                    station_2_status: station_2_status,
                    errorColor: errorColor,
                    okColor: okColor,
                    textColor: textColor,
                    warningColor: warningColor,
                    redColor: redColor,
                    ng_bussingOut_1: ng_bussingOut_1,
                    ng_bussingOut_2: ng_bussingOut_2,
                    bussingIn_1: bussingIn_1,
                    bussingIn_2: bussingIn_2,
                    currentYield_1: currentYield_1,
                    currentYield_2: currentYield_2,
                    throughputData: throughputData,
                    shiftLabels: shiftLabels,
                    hourlyData: hourlyData,
                    hourLabels: hourLabels,
                    dataFermi: dataFermi,
                    station1Shifts: station1Shifts,
                    station2Shifts: station2Shifts,
                    mergedShiftData: mergedShiftData,
                    yieldLast8h_1: yieldLast8h_1,
                    yieldLast8h_2: yieldLast8h_2,
                    counts: counts,
                    availableTime_1: availableTime_1,
                    availableTime_2: availableTime_2,
                    defectLabels: defectLabels,
                    defectVPFLabels: defectVPFLabels,
                    ain1Counts: ain1Counts,
                    ain1VPFCounts: ain1VPFCounts,
                    ain2Counts: ain2Counts,
                    ain2VPFCounts: ain2VPFCounts,
                    last_n_shifts: last_n_shifts,
                    qg2_defects_value: qg2_defects_value,
                  )
                : widget.zone == "VPF"
                    ? VpfVisualsPage(
                        shift_target: shift_target,
                        hourly_shift_target: hourly_shift_target,
                        yield_target: yield_target,
                        circleSize: circleSize,
                        station_1_status: station_1_status,
                        errorColor: errorColor,
                        okColor: okColor,
                        textColor: textColor,
                        warningColor: warningColor,
                        redColor: redColor,
                        speedRatioData: speedRatioData,
                        reEntered_1: reEntered_1,
                        station1Shifts: station1Shifts,
                        currentYield_1: currentYield_1,
                        yieldLast8h_1: yieldLast8h_1,
                        counts: counts,
                        last_n_shifts: last_n_shifts,
                        defectsVPF: defectsVPF,
                        In_1: In_1,
                        ngOut_1: ngOut_1,
                        eqDefects: eqDefects,
                      )
                    : widget.zone == "ELL"
                        ? EllVisualsPage(
                            shift_target: shift_target,
                            hourly_shift_target: hourly_shift_target,
                            yield_target: yield_target,
                            circleSize: circleSize,
                            station_1_status: station_1_status,
                            station_2_status: station_2_status,
                            errorColor: errorColor,
                            okColor: okColor,
                            textColor: textColor,
                            warningColor: warningColor,
                            redColor: redColor,
                            ng_1: ngOut_1,
                            ng_2: ngScrap,
                            in_1: In_1,
                            in_2: In_2,
                            currentFPYYield: currentFPYYield,
                            currentRWKYield: currentRWKYield,
                            throughputDataEll: throughputDataEll,
                            shiftLabels: shiftLabels,
                            hourlyData: hourlyData,
                            hourLabels: hourLabels,
                            dataFermi: dataFermi,
                            mergedShiftData: mergedShiftData,
                            FPYLast8h: FPYLast8h,
                            RWKLast8h: RWKLast8h,
                            counts: counts,
                            defectLabels: defectLabels,
                            min1Counts: min1Counts,
                            min2Counts: min2Counts,
                            ellCounts: ellCounts,
                            shiftThroughput: shiftThroughput,
                            FPY_yield_shifts: FPY_yield_shifts,
                            RWK_yield_shifs: RWK_yield_shifs,
                            last_n_shifts: last_n_shifts,
                            bufferDefectSummary: bufferDefectSummary,
                            value_gauge_1: value_gauge_1,
                            value_gauge_2: value_gauge_2,
                            speedRatioData: speedRatioData,
                          )
                        : const Center(
                            child: Text(
                              'ZONA non trovata',
                              style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ),
      ),
    );
  }
}
