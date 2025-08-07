// ignore_for_file: library_private_types_in_public_api, non_constant_identifier_names, avoid_print

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ix_monitor/pages/visual/visuals/STR_page.dart';
import '../../shared/models/globals.dart';
import '../../shared/services/api_service.dart';
import '../../shared/services/socket_service.dart';
import 'shimmer_placeHolder.dart';
import 'visuals/AIN_page.dart';
import 'visuals/ELL_page.dart';
import 'visuals/LMN_page.dart';
import 'visuals/VPF_page.dart';

class VisualPage extends StatefulWidget {
  final String zone;
  const VisualPage({super.key, required this.zone});

  @override
  _VisualPageState createState() => _VisualPageState();
}

class _VisualPageState extends State<VisualPage> {
  final WebSocketService _webSocketService = WebSocketService();
  final WebSocketService _escalationSocket = WebSocketService();
  bool _isWebSocketConnected = false;
  Timer? _escalationPollTimer;
  Color errorColor = Colors.amber.shade700;
  Color redColor = Colors.red;
  Color warningColor = Colors.yellow.shade400;
  Color okColor = Colors.green.shade400;
  Color textColor = Colors.black;
  double circleSize = 32;
  double circleSizeSTR = 24;
  bool isLoading = true;

  int station_1_status = 1;
  int station_2_status = 1;
  int station_3_status = 1;
  int station_4_status = 1;
  int station_5_status = 1;

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
  Map<int, List<Map<String, int>>> hourlyThroughputPerStation = {};

  //final List<String> defectLabels = ['NG Macchie ECA', 'NG Saldatura', 'NG Bad Soldering', 'NG Mancanza l_Ribbon', 'NG Celle Rotte'];
  List<String> defectLabels = [];
  List<String> defectVPFLabels = [];
  //final List<int> ain1Counts = [17, 8, 9, 7, 3];
  List<int> ain1Counts = [];
  List<int> VpfDefectsCounts = [];
  List<int> Counts = [];
  List<int> ain1VPFCounts = [];
  //final List<int> ain2Counts = [4, 5, 0, 1, 2];
  List<int> ain2Counts = [];
  List<int> ain2VPFCounts = [];

  int station_1_in = 0;
  int station_2_in = 0;
  int station_1_out_ng = 0;
  int station_2_out_ng = 0;
  List<int> lmn1Counts = [];
  List<int> lmn2Counts = [];
  List<int> lmn1VPFCounts = [];
  List<int> lmn2VPFCounts = [];

  Timer? _hourlyRefreshTimer;

  List<Map<String, dynamic>> bufferDefects = [];
  final Map<String, String> etaByObjectId = {};
  final Set<String> loadingETAs = {};

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
  int qg2_ng = 0;
  int ng_tot = 0;
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

  //STR
  Map<int, int> zoneInputs = {},
      zoneNG = {},
      zoneYield = {},
      zoneScrap = {},
      zoneAvailability = {};
  List<Map<String, dynamic>> strShifts = [];
  List<Map<String, dynamic>> overallShifts = [];
  List<Map<String, dynamic>> yieldLast8h = [];
  List<Map<String, dynamic>> overallYieldLast8h = [];
  int availableTime = 0;

  final Map<String, int> _stationNameToId = {
    "AIN01": 29,
    "AIN02": 30,
    "STR01": 4,
    "STR02": 5,
    "STR03": 6,
    "STR04": 7,
    "STR05": 8,
    "LMN01": 93,
    "LMN02": 47
  };

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
    } else if (widget.zone == "STR") {
      await fetchStrZoneData();
    } else if (widget.zone == "LMN") {
      await fetchLmnZoneData();
    } else {
      print('Cannote fetch zone data Unknown zone: $widget.zone');
    }
  }

  Future<void> fetchAinZoneData() async {
    try {
      final response =
          await ApiService.fetchVisualDataForAin(forceRefresh: true);

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
      final visualResponse = await ApiService.fetchVisualDataForEll();

      // 👇 Add this: fetch real-time buffer defects
      final bufferResponse = await ApiService.fetchBufferDefectSummary(
        plcIp: '192.168.32.2',
        db: 19603,
        byte: 0,
        length: 21,
        stringLength: 20,
        debug: false,
      );

      print('Buffer response : $bufferResponse');

      setState(() {
        In_1 = visualResponse['station_1_in'] ?? 0;
        In_2 = visualResponse['station_2_in'] ?? 0;
        ngOut_1 = visualResponse['station_1_r0_ng'] ?? 0;
        ngScrap = visualResponse['station_2_out_ng'] ?? 0;
        qg2_ng = visualResponse['station_1_ng_qg2'] ?? 0;

        ng_tot = visualResponse['ng_tot'] ?? 0;

        currentFPYYield = visualResponse['FPY_yield'] ?? 100;
        currentRWKYield = visualResponse['RWK_yield'] ?? 100;

        FPYLast8h = List<Map<String, dynamic>>.from(
            visualResponse['FPY_yield_last_8h'] ?? []);
        RWKLast8h = List<Map<String, dynamic>>.from(
            visualResponse['RWK_yield_last_8h'] ?? []);
        shiftThroughput = List<Map<String, dynamic>>.from(
            visualResponse['shift_throughput'] ?? []);
        hourlyThroughput = List<Map<String, dynamic>>.from(
            visualResponse['last_8h_throughput'] ?? []);
        FPY_yield_shifts = List<Map<String, dynamic>>.from(
            visualResponse['FPY_yield_shifts'] ?? []);
        RWK_yield_shifs = List<Map<String, dynamic>>.from(
            visualResponse['RWK_yield_shifts'] ?? []);

        final shiftCount = math.min(3, FPY_yield_shifts.length);
        mergedShiftData = List.generate(shiftCount, (index) {
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

        final topDefectsRaw = List<Map<String, dynamic>>.from(
            visualResponse['top_defects'] ?? []);

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
            double.tryParse(visualResponse['value_gauge_1'].toString()) ?? 0.0;
        value_gauge_2 =
            double.tryParse(visualResponse['value_gauge_2'].toString()) ?? 0.0;

        _loadBufferData(); // ⬅️ Call your API-based loader on every update

        isLoading = false;
      });
    } catch (e) {
      print("❌ Error fetching zone data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchStrZoneData() async {
    try {
      final response =
          await ApiService.fetchVisualDataForStr(forceRefresh: true);

      setState(() {
        final stations = [1, 2, 3, 4, 5];
        zoneInputs.clear();
        zoneNG.clear();
        zoneYield.clear();
        zoneScrap.clear();
        zoneAvailability.clear(); // <-- NEW: to store availability per station

        // Gather inputs, NG, scrap, yields for all stations
        for (var s in stations) {
          zoneInputs[s] = response['station_${s}_in'] ?? 0;
          zoneNG[s] = response['station_${s}_out_ng'] ?? 0;
          zoneScrap[s] = ((response['station_${s}_scrap'] ?? 0) / 10).round();
          zoneYield[s] = response['station_${s}_yield'] ?? 100;
        }

        // Yield history (last 8h bins + overall)
        yieldLast8h = List<Map<String, dynamic>>.from(
            response['str_yield_last_8h'] ?? []);
        overallYieldLast8h = List<Map<String, dynamic>>.from(
            response['overall_yield_last_8h'] ?? []);

        // Shift yields (STR global + overall)
        strShifts =
            List<Map<String, dynamic>>.from(response['str_yield_shifts'] ?? []);
        overallShifts = List<Map<String, dynamic>>.from(
            response['overall_yield_shifts'] ?? []);

        mergedShiftData = List.generate(strShifts.length, (i) {
          final strYield = strShifts[i]['yield'] ?? 100;
          final overallYield = (i < overallShifts.length)
              ? overallShifts[i]['yield'] ?? 100
              : 100;

          return {
            'shift': strShifts[i]['label'],
            'STR_Yield': strYield, // STR Yield (dark blue bar)
            'Overall_Yield': overallYield, // Overall Yield (light blue bar)
            'good': strShifts[i]['good'] ?? 0,
            'ng': strShifts[i]['ng'] ?? 0,
          };
        });

        // Throughput per shift (total vs NG)
        shiftThroughput =
            List<Map<String, dynamic>>.from(response['shift_throughput'] ?? []);
        throughputData = shiftThroughput.map<Map<String, int>>((e) {
          final total = (e['total'] ?? 0) as int;
          final ng = (e['ng'] ?? 0) as int;
          return {'ok': total - ng, 'ng': ng};
        }).toList();
        shiftLabels =
            shiftThroughput.map((e) => e['label']?.toString() ?? '').toList();

        // Hourly data from 8h yield bins (good vs NG)
        // Per-Station Hourly Throughput ─────────────────────────────────────
        final perStationHourly = Map<String, dynamic>.from(
          response['hourly_throughput_per_station'] ?? {},
        );

        hourlyThroughputPerStation.clear();
        for (int station = 1; station <= 5; station++) {
          final rawList = List<Map<String, dynamic>>.from(
            perStationHourly['$station'] ?? [],
          );

          hourlyThroughputPerStation[station] =
              rawList.map<Map<String, int>>((e) {
            return {
              'ok': (e['ok'] ?? 0) as int,
              'ng': (e['ng'] ?? 0) as int,
            };
          }).toList();
        }

        // Fallback: update hourLabels from station 1 if not already set
        if (hourLabels.isEmpty &&
            hourlyThroughputPerStation[1]?.isNotEmpty == true) {
          hourLabels = List<String>.from(
            perStationHourly['1']!.map((e) => e['hour']?.toString() ?? ''),
          );
        }

        //  Top Defects QG2  ───────────────────────────────────────────────
        final topDefectsRaw =
            List<Map<String, dynamic>>.from(response['top_defects_qg2'] ?? []);

        defectLabels = [];
        Counts = [];
        for (final d in topDefectsRaw) {
          defectLabels.add(d['label']?.toString() ?? '');
          Counts.add(int.tryParse(d['total'].toString()) ?? 0); // ← use TOTAL
        }
        qg2_defects_value = response['total_defects_qg2'] ?? 0;

        //  Top Defects VPF  ───────────────────────────────────────────────
        final topDefectsVPF =
            List<Map<String, dynamic>>.from(response['top_defects_vpf'] ?? []);

        defectVPFLabels = [];
        VpfDefectsCounts = [];
        for (final d in topDefectsVPF) {
          defectVPFLabels.add(d['label']?.toString() ?? '');
          VpfDefectsCounts.add(
              int.tryParse(d['total'].toString()) ?? 0); // ← use TOTAL
        }

        // Fermi data (downtime + per-station availability)
        final fermiRaw =
            List<Map<String, dynamic>>.from(response['fermi_data'] ?? []);
        dataFermi = [];
        availableTime = 0; // keep total if still sent

        for (final entry in fermiRaw) {
          // Case 1: Stop details (has causale + station)
          if (entry.containsKey("causale") && entry.containsKey("station")) {
            dataFermi.add([
              entry['causale']?.toString() ?? '', // Tipo Fermata (Reason)
              entry['station']?.toString() ?? '', // Macchina
              entry['count']?.toString() ?? '0', // Frequenza
              entry['time']?.toString() ?? '0', // Fermo Cumulato (min)
            ]);
          }

          // Case 2: Availability entries (Available_Time_STRxx)
          if (entry.keys.any((k) => k.startsWith("Available_Time_"))) {
            final key = entry.keys.first;
            final stationName = key.replaceFirst("Available_Time_", "");
            final stationId = _stationIdFromName(stationName);
            final avail = int.tryParse(entry[key].toString()) ?? 0;
            zoneAvailability[stationId] = avail;
          }

          // Case 3: Overall availability
          if (entry.containsKey("Available_Time_Total")) {
            availableTime =
                int.tryParse(entry["Available_Time_Total"].toString()) ?? 0;
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

  Future<void> fetchLmnZoneData() async {
    try {
      final response =
          await ApiService.fetchVisualDataForLmn(forceRefresh: true);

      setState(() {
        station_1_in = response['station_1_in'] ?? 0;
        station_2_in = response['station_2_in'] ?? 0;
        station_1_out_ng = response['station_1_out_ng'] ?? 0;
        station_2_out_ng = response['station_2_out_ng'] ?? 0;
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
            'station1': station1Shifts[index]['yield'],
            'station2': station2Shifts[index]['yield'],
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
        lmn1Counts = [];
        lmn2Counts = [];

        for (final defect in topDefectsRaw) {
          defectLabels.add(defect['label']?.toString() ?? '');
          lmn1Counts.add(int.tryParse(defect['lmn1'].toString()) ?? 0);
          lmn2Counts.add(int.tryParse(defect['lmn2'].toString()) ?? 0);
        }

        qg2_defects_value = response['total_defects_qg2'];

        // Parse Top Defects VPF
        final topDefectsVPF =
            List<Map<String, dynamic>>.from(response['top_defects_vpf'] ?? []);

        defectVPFLabels = [];
        lmn1VPFCounts = [];
        lmn2VPFCounts = [];

        for (final defect in topDefectsVPF) {
          defectVPFLabels.add(defect['label']?.toString() ?? '');
          lmn1VPFCounts.add(int.tryParse(defect['lmn1'].toString()) ?? 0);
          lmn2VPFCounts.add(int.tryParse(defect['lmn2'].toString()) ?? 0);
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

// Helper: map station name ("STR01" etc.) to 1–5 index
  int _stationIdFromName(String name) {
    final num = int.tryParse(RegExp(r'\d+$').firstMatch(name)?.group(0) ?? '');
    return (num != null && num >= 1 && num <= 5) ? num : 0;
  }

  Future<void> _fetchEscalations() async {
    final api = ApiService();
    final List<Map<String, dynamic>> newEsc = [];

    for (final entry in _stationNameToId.entries) {
      // Only Escalations
      final escRes =
          await api.getStopsForStation(entry.value, shiftsBack: last_n_shifts);

      for (final esc in escRes?['stops'] ?? []) {
        newEsc.add({
          'id': esc['id'],
          'title': esc['reason'],
          'status': esc['status'],
          'station': entry.key,
          'start_time': DateTime.parse(esc['start_time']),
          'end_time':
              esc['end_time'] != null ? DateTime.parse(esc['end_time']) : null,
        });
      }
    }

    newEsc.sort((a, b) => b['id'].compareTo(a['id']));
    escalations.value = List<Map<String, dynamic>>.from(newEsc);
    print('🛑 Escalations updated: ${escalations.value}');
  }

  void _initializeEscalationWebSocket() {
    _fetchEscalations();
    _escalationSocket.connectToEscalations(
      onDone: _scheduleEscalationReconnect,
      onError: (_) => _scheduleEscalationReconnect(),
    );

    _escalationPollTimer?.cancel();
    _escalationPollTimer = Timer.periodic(
      Duration(seconds: 10),
      (_) async {
        if (!_escalationSocket.isConnected) {
          await _fetchEscalations();
        }
      },
    );
  }

  void _scheduleEscalationReconnect() {
    _fetchEscalations();
    Future.delayed(Duration(seconds: 5), () {
      if (mounted) _initializeEscalationWebSocket();
    });
  }

  Future<void> _initializeWebSocket() async {
    if (widget.zone == "AIN") {
      _initializeAinWebSocket();
    } else if (widget.zone == "VPF") {
      _initializeVpfWebSocket();
    } else if (widget.zone == "ELL") {
      _initializeEllWebSocket();
    } else if (widget.zone == "STR") {
      _initializeStrWebSocket();
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

    int toIntSafe(dynamic value) => value is int
        ? value
        : value is double
            ? value.toInt()
            : int.tryParse(value.toString()) ?? 0;

    double toDoubleSafe(dynamic value) => value is double
        ? value
        : value is int
            ? value.toDouble()
            : double.tryParse(value.toString()) ?? 0.0;

    _webSocketService.connectToVisual(
      line: 'Linea2',
      zone: widget.zone,
      onMessage: (data) {
        if (!mounted) return;

        print('📡 WebSocket message received: $data');

        setState(() {
          // ─── Station Metrics ───────────────────────────
          In_1 = toIntSafe(data['station_1_in']);
          In_2 = toIntSafe(data['station_2_in']);
          ngOut_1 = toIntSafe(data['station_1_r0_ng']);
          ngScrap = toIntSafe(data['station_2_out_ng']);

          ng_tot = toIntSafe(data['ng_tot']);

          currentFPYYield = toDoubleSafe(data['FPY_yield']).round();
          currentRWKYield = toDoubleSafe(data['RWK_yield']).round();

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

          final shiftCount = math.min(3, FPY_yield_shifts.length);
          mergedShiftData = List.generate(shiftCount, (index) {
            return {
              'shift': FPY_yield_shifts[index]['label'],
              'FPY': toDoubleSafe(FPY_yield_shifts[index]['yield']),
              'RWK': toDoubleSafe(RWK_yield_shifs[index]['yield']),
            };
          });

          throughputDataEll = shiftThroughput.map<Map<String, int>>((e) {
            final total = toIntSafe(e['total']);
            final ng = toIntSafe(e['ng']);
            final scrap = toIntSafe(e['scrap']);
            return {'ok': total - ng - scrap, 'ng': ng, 'scrap': scrap};
          }).toList();

          shiftLabels =
              shiftThroughput.map((e) => e['label']?.toString() ?? '').toList();

          hourlyData = hourlyThroughput.map<Map<String, int>>((e) {
            final total = toIntSafe(e['total']);
            final ng = toIntSafe(e['ng']);
            final scrap = toIntSafe(e['scrap']);
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
            min1Counts.add(toIntSafe(defect['min1']));
            min2Counts.add(toIntSafe(defect['min2']));
            ellCounts.add(toIntSafe(defect['ell']));
          }

          _loadBufferData(); // ⬅️ Call your API-based loader on every update

          value_gauge_1 = toDoubleSafe(data['value_gauge_1']);
          value_gauge_2 = toDoubleSafe(data['value_gauge_2']);
        });
      },
      onDone: () => print("Visual WebSocket closed"),
      onError: (err) => print("WebSocket error: $err"),
    );

    _isWebSocketConnected = true;
  }

  void _initializeStrWebSocket() {
    if (_isWebSocketConnected) return;

    _webSocketService.connectToVisual(
      line: 'Linea2',
      zone: widget.zone,
      onMessage: (data) {
        if (!mounted) return;

        setState(() {
          // ─── Main station metrics ─────────────────────────────
          final stations = [1, 2, 3, 4, 5];
          zoneInputs.clear();
          zoneNG.clear();
          zoneYield.clear();
          zoneScrap.clear();
          zoneAvailability.clear();

          for (var s in stations) {
            zoneInputs[s] = data['station_${s}_in'] ?? 0;
            zoneNG[s] = data['station_${s}_out_ng'] ?? 0;
            zoneYield[s] = data['station_${s}_yield'] ?? 100;
            zoneScrap[s] = ((data['station_${s}_scrap'] ?? 0) / 10).round();
          }

          // ─── Yield (Last 8h) ──────────────────────────────────
          yieldLast8h =
              List<Map<String, dynamic>>.from(data['str_yield_last_8h'] ?? []);
          overallYieldLast8h = List<Map<String, dynamic>>.from(
              data['overall_yield_last_8h'] ?? []);

          // ─── Yield per Shift ──────────────────────────────────
          strShifts =
              List<Map<String, dynamic>>.from(data['str_yield_shifts'] ?? []);
          overallShifts = List<Map<String, dynamic>>.from(
              data['overall_yield_shifts'] ?? []);

          mergedShiftData = List.generate(strShifts.length, (i) {
            final strYield = strShifts[i]['yield'] ?? 100;
            final overallYield = (i < overallShifts.length)
                ? overallShifts[i]['yield'] ?? 100
                : 100;
            return {
              'shift': strShifts[i]['label'],
              'STR_Yield': strYield,
              'Overall_Yield': overallYield,
              'good': strShifts[i]['good'] ?? 0,
              'ng': strShifts[i]['ng'] ?? 0,
            };
          });

          // ─── Throughput (Shift & 8h) ─────────────────────────
          shiftThroughput =
              List<Map<String, dynamic>>.from(data['shift_throughput'] ?? []);
          throughputData = shiftThroughput.map<Map<String, int>>((e) {
            final total = (e['total'] ?? 0) as int;
            final ng = (e['ng'] ?? 0) as int;
            return {'ok': total - ng, 'ng': ng};
          }).toList();
          shiftLabels =
              shiftThroughput.map((e) => e['label']?.toString() ?? '').toList();

          // ─── Hourly Throughput per Station ────────────────────────────────
          final rawPerStationHourly = Map<String, dynamic>.from(
            data['hourly_throughput_per_station'] ?? {},
          );

          hourlyThroughputPerStation.clear();
          for (int station = 1; station <= 5; station++) {
            final rawList = List<Map<String, dynamic>>.from(
              rawPerStationHourly['$station'] ?? [],
            );

            hourlyThroughputPerStation[station] =
                rawList.map<Map<String, int>>((e) {
              return {
                'ok': (e['ok'] ?? 0) as int,
                'ng': (e['ng'] ?? 0) as int,
              };
            }).toList();
          }

          // Fallback: update hourLabels from STR01
          if (hourLabels.isEmpty &&
              hourlyThroughputPerStation[1]?.isNotEmpty == true) {
            hourLabels = List<String>.from(
              rawPerStationHourly['1']!.map((e) => e['hour']?.toString() ?? ''),
            );
          }

          // ─── Fermi Data (availability + stops) ────────────────
          final fermiRaw =
              List<Map<String, dynamic>>.from(data['fermi_data'] ?? []);
          dataFermi = [];
          availableTime = 0;

          for (final entry in fermiRaw) {
            if (entry.containsKey("causale") && entry.containsKey("station")) {
              dataFermi.add([
                entry['causale']?.toString() ?? '',
                entry['station']?.toString() ?? '',
                entry['count']?.toString() ?? '0',
                entry['time']?.toString() ?? '0',
              ]);
            }

            if (entry.containsKey('station') &&
                entry.containsKey('available_time')) {
              final stationName = entry['station'].toString();
              final stationId = _stationIdFromName(stationName);
              final avail =
                  int.tryParse(entry['available_time'].toString()) ?? 0;
              zoneAvailability[stationId] = avail;
            }

            if (entry.keys.any((k) => k.startsWith("Available_Time_"))) {
              final key = entry.keys.first;
              final stationName = key.replaceFirst("Available_Time_", "");
              final stationId = _stationIdFromName(stationName);
              final avail = int.tryParse(entry[key].toString()) ?? 0;
              zoneAvailability[stationId] = avail;
            }

            if (entry.containsKey("Available_Time_Total")) {
              availableTime =
                  int.tryParse(entry["Available_Time_Total"].toString()) ?? 0;
            }
          }

          // ─── QG2 Defects ─────────────────────────────────────
          final topDefectsQG2 =
              List<Map<String, dynamic>>.from(data['top_defects_qg2'] ?? []);
          defectLabels = [];
          Counts = [];

          for (final d in topDefectsQG2) {
            defectLabels.add(d['label']?.toString() ?? '');
            final ain1 = int.tryParse(d['ain1'].toString()) ?? 0;
            final ain2 = int.tryParse(d['ain2'].toString()) ?? 0;
            Counts.add(ain1 + ain2);
          }

          qg2_defects_value = data['total_defects_qg2'] ?? 0;

          // ─── VPF Defects ─────────────────────────────────────
          final topDefectsVPF =
              List<Map<String, dynamic>>.from(data['top_defects_vpf'] ?? []);
          defectVPFLabels = [];
          VpfDefectsCounts = [];

          for (final d in topDefectsVPF) {
            defectVPFLabels.add(d['label']?.toString() ?? '');
            final ain1 = int.tryParse(d['ain1'].toString()) ?? 0;
            final ain2 = int.tryParse(d['ain2'].toString()) ?? 0;
            VpfDefectsCounts.add(ain1 + ain2);
          }

          isLoading = false;
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
    loadTargets();
    fetchZoneData();
    _initializeWebSocket();
    _initializeEscalationWebSocket();
    _startHourlyRefreshScheduler();
  }

  Future<void> _loadBufferData() async {
    try {
      final result = await ApiService.fetchBufferDefectSummary(
        plcIp: '192.168.32.2',
        db: 19603,
        byte: 0,
        length: 21,
      );

      final bufferIds = List<String>.from(result['bufferIds'] ?? []);
      final rawDefects =
          List<Map<String, dynamic>>.from(result['bufferDefects'] ?? []);

      // Build full list of 21 slots (0 = plane, 1–20 = buffer)
      final fullDefects = List.generate(21, (i) {
        final id = i < bufferIds.length ? bufferIds[i].trim() : '';
        if (id.isEmpty) {
          return {
            'object_id': '',
            'production_id': 0,
            'rework_count': 0,
            'defects': [],
          };
        }

        // Match defect object by object_id
        final existing = rawDefects.firstWhere(
          (d) => d['object_id'] == id,
          orElse: () => {
            'object_id': id,
            'production_id': 0,
            'rework_count': 0,
            'defects': [],
          },
        );

        return {
          'object_id': id,
          'production_id': existing['production_id'] ?? 0,
          'rework_count': existing['rework_count'] ?? 0,
          'defects': existing['defects'] ?? [],
        };
      });

      final displayList = [
        fullDefects[0], // plane (slot 1) ⬅️ now at the top
        ...fullDefects.sublist(1), // buffer 2 → 21 (already in correct order)
      ];

      setState(() {
        bufferDefectSummary = displayList;
        isLoading = false;
      });

      for (final item in displayList) {
        final objectId = item['object_id']?.toString();
        if (objectId != null &&
            objectId.isNotEmpty &&
            !etaByObjectId.containsKey(objectId)) {
          _fetchETA(objectId);
        }
      }
    } catch (e) {
      print("❌ Error loading buffer data: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchETA(String objectId) async {
    loadingETAs.add(objectId);
    final result = await ApiService.predictReworkETAByObject(objectId);

    if (!mounted) return;

    final etaMin = result['etaInfo']?['eta_min'];
    final noDefects = result['noDefectsFound'] ?? false;

    final etaString = etaMin != null
        ? "${etaMin.round()} min"
        : (noDefects ? "Complete" : "N/A");

    setState(() {
      etaByObjectId[objectId] = etaString;
    });
  }

  void _startHourlyRefreshScheduler() {
    final now = DateTime.now();
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    final initialDelay = nextHour.difference(now);

    print("⏳ Scheduling first refresh in ${initialDelay.inSeconds} seconds");

    Future.delayed(initialDelay, () {
      fetchZoneData();

      // Start regular hourly timer
      _hourlyRefreshTimer = Timer.periodic(Duration(hours: 1), (_) {
        fetchZoneData();
      });
    });
  }

  @override
  void dispose() {
    _hourlyRefreshTimer?.cancel();
    _escalationPollTimer?.cancel();
    _webSocketService.close();
    _escalationSocket.close();
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
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: escalations,
      builder: (_, escList, __) {
        final counts =
            calculateEscalationCounts(escList); // escList is the real list 👍

        return Scaffold(
          backgroundColor: Colors.white,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: isLoading
                ? buildShimmerPlaceholder()
                : SingleChildScrollView(
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
                                onStopsUpdated: () {
                                  fetchZoneData(); // Refresh the entire zone (fermi + metrics)
                                  _fetchEscalations(); // 2️⃣ pull fresh STOP & ESCALATION list
                                },
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
                                        hourly_shift_target:
                                            hourly_shift_target,
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
                                        qg2_ng: qg2_ng,
                                        ng_tot: ng_tot,
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
                                        bufferDefectSummary:
                                            bufferDefectSummary,
                                        value_gauge_1: value_gauge_1,
                                        value_gauge_2: value_gauge_2,
                                        speedRatioData: speedRatioData,
                                      )
                                    : widget.zone == 'STR'
                                        ? StrVisualsPage(
                                            shiftTarget: shift_target,
                                            hourlyShiftTarget:
                                                hourly_shift_target,
                                            yieldTarget: yield_target,
                                            circleSize: circleSizeSTR,

                                            // Status map for all stations
                                            stationStatus: {
                                              1: station_1_status,
                                              2: station_2_status,
                                              3: station_3_status,
                                              4: station_4_status,
                                              5: station_5_status,
                                            },

                                            errorColor: errorColor,
                                            okColor: okColor,
                                            textColor: textColor,
                                            warningColor: warningColor,
                                            redColor: redColor,

                                            // Station production metrics (maps for flexibility)
                                            stationInputs:
                                                zoneInputs, // {1: in, 2: in, 3: in, 4: in, 5: in}
                                            stationNG:
                                                zoneNG, // {1: ng, 2: ng, ...}
                                            stationYield:
                                                zoneYield, // {1: %, 2: %, ...}
                                            stationScrap:
                                                zoneScrap, // {1: scrap, ...} (currently 0)

                                            // Throughput and shifts
                                            throughputData: throughputData,
                                            shiftLabels: shiftLabels,
                                            hourlyThroughputPerStation:
                                                hourlyThroughputPerStation,
                                            hourLabels: hourLabels,

                                            // Yield history (full backend-provided lists)
                                            strYieldShifts:
                                                strShifts, // Global yields per shift
                                            overallYieldShifts:
                                                overallShifts, // Overall (station 2 focus)
                                            strYieldLast8h:
                                                yieldLast8h, // Global yields (8h bins)
                                            overallYieldLast8h:
                                                overallYieldLast8h, // Overall yields (8h bins)

                                            // Preprocessed shift summary for charts
                                            mergedShiftData: mergedShiftData,

                                            // Downtime and availability
                                            dataFermi: dataFermi,
                                            zoneAvailability: zoneAvailability,

                                            // Defects
                                            defectLabels: defectLabels,
                                            defectVPFLabels: defectVPFLabels,
                                            defectsCounts: Counts,
                                            VpfDefectsCounts: VpfDefectsCounts,
                                            qg2DefectsValue: qg2_defects_value,

                                            lastNShifts: last_n_shifts,
                                            counts: counts,
                                            onStopsUpdated: () {
                                              fetchZoneData(); // Refresh the entire zone (fermi + metrics)
                                              _fetchEscalations(); // 2️⃣ pull fresh STOP & ESCALATION list
                                            },
                                          )
                                        : widget.zone == "LMN"
                                            ? LmnVisualsPage(
                                                shift_target: shift_target,
                                                hourly_shift_target:
                                                    hourly_shift_target,
                                                yield_target: yield_target,
                                                circleSize: circleSize,
                                                station_1_status:
                                                    station_1_status,
                                                station_2_status:
                                                    station_2_status,
                                                errorColor: errorColor,
                                                okColor: okColor,
                                                textColor: textColor,
                                                warningColor: warningColor,
                                                redColor: redColor,
                                                station_1_out_ng:
                                                    station_1_out_ng,
                                                station_2_out_ng:
                                                    station_2_out_ng,
                                                station_1_in: station_1_in,
                                                station_2_in: station_2_in,
                                                currentYield_1: currentYield_1,
                                                currentYield_2: currentYield_2,
                                                throughputData: throughputData,
                                                shiftLabels: shiftLabels,
                                                hourlyData: hourlyData,
                                                hourLabels: hourLabels,
                                                dataFermi: dataFermi,
                                                station1Shifts: station1Shifts,
                                                station2Shifts: station2Shifts,
                                                mergedShiftData:
                                                    mergedShiftData,
                                                yieldLast8h_1: yieldLast8h_1,
                                                yieldLast8h_2: yieldLast8h_2,
                                                counts: counts,
                                                availableTime_1:
                                                    availableTime_1,
                                                availableTime_2:
                                                    availableTime_2,
                                                defectLabels: defectLabels,
                                                defectVPFLabels:
                                                    defectVPFLabels,
                                                lmn1Counts: lmn1Counts,
                                                lmn1VPFCounts: lmn1VPFCounts,
                                                lmn2Counts: lmn2Counts,
                                                lmn2VPFCounts: lmn2VPFCounts,
                                                last_n_shifts: last_n_shifts,
                                                qg2_defects_value:
                                                    qg2_defects_value,
                                                onStopsUpdated: () {
                                                  fetchZoneData(); // Refresh the entire zone (fermi + metrics)
                                                  _fetchEscalations(); // 2️⃣ pull fresh STOP & ESCALATION list
                                                },
                                              )
                                            : const Center(
                                                child: Text(
                                                  'ZONA non trovata',
                                                  style: TextStyle(
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                  ),
          ),
        );
      },
    );
  }
}
