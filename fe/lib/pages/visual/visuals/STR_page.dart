// ignore_for_file: must_be_immutable, non_constant_identifier_names, file_names

import 'package:flutter/material.dart';
import 'package:gauge_indicator/gauge_indicator.dart';
import 'package:ix_monitor/pages/visual/visual_widgets.dart';
import '../../../shared/services/api_service.dart';
import '../escalation_visual.dart';
import 'dart:async';

import '../stop_visual.dart';

class StrVisualsPage extends StatefulWidget {
  final int shiftTarget;
  final double hourlyShiftTarget;
  final int yieldTarget;
  final double circleSize;

  // Station status (optional: map per station)
  final Map<int, int> stationStatus; // {1: status, 2: status, ...}

  // Colors
  final Color errorColor;
  final Color okColor;
  final Color textColor;
  final Color warningColor;
  final Color redColor;

  // Production data for all 5 stations
  final Map<int, int> stationInputs; // {1: in, 2: in, ...}
  final Map<int, int> stationNG; // {1: ng, 2: ng, ...}
  final Map<int, int> stationYield; // {1: %, 2: %, ...}
  final Map<int, int> stationScrap; // {1: scrap, ...} (currently always 0)

  // Shift and throughput data
  final List<Map<String, int>> throughputData;
  final List<String> shiftLabels;
  final Map<int, List<Map<String, int>>> hourlyThroughputPerStation;
  final List<String> hourLabels;

  // Yield history (backend-native)
  final List<Map<String, dynamic>> strYieldShifts;
  final List<Map<String, dynamic>> overallYieldShifts;
  final List<Map<String, dynamic>> strYieldLast8h;
  final List<Map<String, dynamic>> overallYieldLast8h;

  // Merged shift data for charts
  final List<Map<String, dynamic>> mergedShiftData;

  // Downtime & availability
  final List<List<String>> dataFermi;
  final Map<int, int> zoneAvailability;

  // Defects data
  final List<String> defectLabels;
  final List<String> defectVPFLabels;
  final List<int> defectsCounts;
  final List<int> VpfDefectsCounts;
  final int qg2DefectsValue;

  final int lastNShifts;
  final Map<String, int> counts;
  final VoidCallback? onStopsUpdated;

  const StrVisualsPage({
    super.key,
    required this.shiftTarget,
    required this.hourlyShiftTarget,
    required this.yieldTarget,
    required this.circleSize,
    required this.stationStatus,
    required this.errorColor,
    required this.okColor,
    required this.textColor,
    required this.warningColor,
    required this.redColor,
    required this.stationInputs,
    required this.stationNG,
    required this.stationYield,
    required this.stationScrap,
    required this.throughputData,
    required this.shiftLabels,
    required this.hourlyThroughputPerStation,
    required this.hourLabels,
    required this.strYieldShifts,
    required this.overallYieldShifts,
    required this.strYieldLast8h,
    required this.overallYieldLast8h,
    required this.mergedShiftData,
    required this.dataFermi,
    required this.zoneAvailability,
    required this.defectLabels,
    required this.defectVPFLabels,
    required this.defectsCounts,
    required this.VpfDefectsCounts,
    required this.qg2DefectsValue,
    required this.lastNShifts,
    required this.counts,
    this.onStopsUpdated,
  });

  @override
  State<StrVisualsPage> createState() => _StrVisualsPageState();
}

class _StrVisualsPageState extends State<StrVisualsPage> {
  late int shift_target;
  late double hourly_shift_target;
  late int yield_target;
  Map<String, dynamic>? _runningStop;
  Timer? _stopTimer;

  @override
  void initState() {
    super.initState();
    shift_target = widget.shiftTarget;
    yield_target = widget.yieldTarget;
    hourly_shift_target = widget.hourlyShiftTarget;
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    super.dispose();
  }

  Future<void> showTargetEditDialog({
    required String title,
    required int currentValue,
    required void Function(int newValue) onValueSaved,
  }) async {
    final controller = TextEditingController(text: currentValue.toString());
    int? newValue;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifica $title'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Nuovo valore'),
          onChanged: (value) {
            newValue = int.tryParse(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newValue != null) {
                onValueSaved(newValue!);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Color getYieldColor(int value, int target) {
    if (value >= target) {
      return widget.okColor; // GREEN
    } else if (value >= target - 3) {
      return widget.warningColor; // ORANGE
    } else {
      return widget.errorColor; // RED
    }
  }

  Color getNgColor(int ngCount, int inCount) {
    if (inCount == 0) {
      return widget.redColor; // fallback to red if division by zero
    }

    final percent = (ngCount / inCount) * 100;

    if (percent > 5) {
      return widget.redColor; // RED
    } else if (percent >= 2) {
      return widget.errorColor; // ORANGE
    } else {
      return widget.okColor; // GREEN
    }
  }

  Color getStationColor(int value) {
    if (value == 1) {
      return widget.okColor;
    } else if (value == 2) {
      return widget.warningColor;
    } else if (value == 3) {
      return widget.errorColor;
    } else {
      return Colors.black;
    }
  }

  void refreshEscalationTrafficLight() {
    setState(() {
      // recalculates counts automatically
    });
  }

  void _onStopStarted(Map<String, dynamic> stop) {
    _stopTimer?.cancel();
    setState(() {
      _runningStop = {
        ...stop,
        'status': 'OPEN', // ensure it's marked open
        'start': stop['start'] ?? DateTime.now(), // ensure start time is valid
      };
    });
    _stopTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  void _onStopEnded() {
    _stopTimer?.cancel();
    setState(() {
      _runningStop = null;
    });
    widget.onStopsUpdated?.call();
  }

  Future<void> _stopRunningStop() async {
    if (_runningStop == null) return;

    final id = _runningStop!['id'];
    if (id != null) {
      await ApiService().updateStopStatus(
        stopId: id,
        newStatus: 'CLOSED',
        changedAt: DateTime.now().toIso8601String().split('.').first,
        operatorId: 'TOTEM',
      );
    }

    // Stop the local timer and clear the active stop
    _stopTimer?.cancel();
    setState(() {
      _runningStop = null;
    });

    // Trigger parent refresh so `widget.dataFermi` reloads from MySQL
    if (widget.onStopsUpdated != null) {
      widget
          .onStopsUpdated!(); // fetch latest stop list (including new CLOSED state)
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours.toString().padLeft(2, '0')}:$m:$s';
  }

  Widget buildCompactCard(String text) {
    return SizedBox(
      height: 75,
      width: 100,
      child: Card(
        color: Colors.white,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: widget.textColor, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: widget.textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ────── FIRST HEADER ROW ──────
            Row(
              children: [
                Flexible(
                  flex: 4,
                  child: Row(
                    children: [
                      HeaderBox(
                        title: 'Stringatrici\nLinea B',
                        target: '',
                        Title: true,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            showTargetEditDialog(
                              title: 'Target Produzione Shift',
                              currentValue: shift_target,
                              onValueSaved: (newVal) async {
                                setState(() {
                                  shift_target = newVal;
                                  hourly_shift_target =
                                      (newVal ~/ 8).toDouble();
                                });
                                await ApiService.saveVisualTargets(
                                    shift_target, yield_target);
                              },
                            );
                          },
                          child: HeaderBox(
                            title: 'Produzione Shift',
                            target: '$shift_target moduli',
                            icon: Icons.solar_power,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  flex: 3,
                  child: GestureDetector(
                    onTap: () {
                      showTargetEditDialog(
                        title: 'Target Yield',
                        currentValue: yield_target,
                        onValueSaved: (newVal) async {
                          setState(() => yield_target = newVal);
                          await ApiService.saveVisualTargets(
                              shift_target, yield_target);
                        },
                      );
                    },
                    child: HeaderBox(
                      title: 'YIELD',
                      target: '$yield_target %',
                      icon: Icons.show_chart,
                    ),
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
                                flex: 1,
                                child: Column(
                                  children: [
                                    Flexible(
                                      child: Column(
                                        children: [
                                          // Row titles (aligned with the two card columns)
                                          // First row of cards
                                          Flexible(
                                            child: Row(
                                              children: [
                                                Text(
                                                  'STR01',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 24,
                                                    color: Colors.black,
                                                  ),
                                                ),

                                                // 🔴 First Circle
                                                const SizedBox(width: 6),
                                                Visibility(
                                                  visible:
                                                      false, // 👈 TARTARUGA
                                                  maintainSize:
                                                      true, // keeps its width/height
                                                  maintainAnimation: true,
                                                  maintainState: true,
                                                  child: Container(
                                                    width: widget.circleSize,
                                                    height: widget.circleSize,
                                                    decoration: BoxDecoration(
                                                      color: getStationColor(
                                                          widget.stationStatus[
                                                                  1] ??
                                                              0),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Card(
                                                    color: Colors.white,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              widget.textColor,
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12,
                                                          horizontal: 2),
                                                      child: Center(
                                                        child: Text(
                                                          widget
                                                              .stationInputs[1]
                                                              .toString(),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 24,
                                                            color: widget
                                                                .textColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                // Circle NG STR1
                                                Container(
                                                  width: widget.circleSize,
                                                  height: widget.circleSize,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        (widget.stationNG[1] ??
                                                                    0) ==
                                                                0
                                                            ? Colors.white
                                                            : getNgColor(
                                                                widget.stationNG[
                                                                        1] ??
                                                                    0,
                                                                widget.stationInputs[
                                                                        1] ??
                                                                    0,
                                                              ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: (widget.stationNG[
                                                                      1] ??
                                                                  0) ==
                                                              0
                                                          ? Colors.black
                                                          : Colors.transparent,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Card(
                                                    color: Colors.white,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              widget.textColor,
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12),
                                                      child: Center(
                                                        child: Text(
                                                          widget.stationNG[1]
                                                              .toString(),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 24,
                                                            color: widget
                                                                .textColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),
                                                // Circle Scrap STR1
                                                Container(
                                                  width: widget.circleSize,
                                                  height: widget.circleSize,
                                                  decoration: BoxDecoration(
                                                    color: (widget.stationScrap[
                                                                    1] ??
                                                                0) ==
                                                            0
                                                        ? Colors.white
                                                        : getNgColor(
                                                            widget.stationScrap[
                                                                    1] ??
                                                                0,
                                                            widget.stationInputs[
                                                                    1] ??
                                                                0,
                                                          ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color:
                                                          (widget.stationScrap[
                                                                          1] ??
                                                                      0) ==
                                                                  0
                                                              ? Colors.black
                                                              : Colors
                                                                  .transparent,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),

                                                Flexible(
                                                  child: Card(
                                                    color: Colors.white,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              widget.textColor,
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12),
                                                      child: Center(
                                                        child: Text(
                                                          widget.stationScrap[1]
                                                              .toString(),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 24,
                                                            color: widget
                                                                .textColor,
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
                                                  'STR02',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 24,
                                                    color: Colors.black,
                                                  ),
                                                ),

                                                // 🔴 First Circle
                                                const SizedBox(width: 6),
                                                Visibility(
                                                  visible:
                                                      false, // 👈 TARTARUGA
                                                  maintainSize:
                                                      true, // keeps its width/height
                                                  maintainAnimation: true,
                                                  maintainState: true,
                                                  child: Container(
                                                    width: widget.circleSize,
                                                    height: widget.circleSize,
                                                    decoration: BoxDecoration(
                                                      color: getStationColor(
                                                          widget.stationStatus[
                                                                  2] ??
                                                              0),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Card(
                                                    color: Colors.white,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              widget.textColor,
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12),
                                                      child: Center(
                                                        child: Text(
                                                          widget
                                                              .stationInputs[2]
                                                              .toString(),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 24,
                                                            color: widget
                                                                .textColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                // Circle NG STR2
                                                Container(
                                                  width: widget.circleSize,
                                                  height: widget.circleSize,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        (widget.stationNG[2] ??
                                                                    0) ==
                                                                0
                                                            ? Colors.white
                                                            : getNgColor(
                                                                widget.stationNG[
                                                                        2] ??
                                                                    0,
                                                                widget.stationInputs[
                                                                        2] ??
                                                                    0,
                                                              ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: (widget.stationNG[
                                                                      2] ??
                                                                  0) ==
                                                              0
                                                          ? Colors.black
                                                          : Colors.transparent,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Card(
                                                    color: Colors.white,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              widget.textColor,
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12),
                                                      child: Center(
                                                        child: Text(
                                                          widget.stationNG[2]
                                                              .toString(),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 24,
                                                            color: widget
                                                                .textColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),
                                                // Circle Scrap STR2
                                                Container(
                                                  width: widget.circleSize,
                                                  height: widget.circleSize,
                                                  decoration: BoxDecoration(
                                                    color: (widget.stationScrap[
                                                                    2] ??
                                                                0) ==
                                                            0
                                                        ? Colors.white
                                                        : getNgColor(
                                                            widget.stationScrap[
                                                                    2] ??
                                                                0,
                                                            widget.stationInputs[
                                                                    2] ??
                                                                0,
                                                          ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color:
                                                          (widget.stationScrap[
                                                                          2] ??
                                                                      0) ==
                                                                  0
                                                              ? Colors.black
                                                              : Colors
                                                                  .transparent,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),

                                                Flexible(
                                                  child: Card(
                                                    color: Colors.white,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              widget.textColor,
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12),
                                                      child: Center(
                                                        child: Text(
                                                          widget.stationScrap[2]
                                                              .toString(),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 24,
                                                            color: widget
                                                                .textColor,
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

                                          // Third row of cards
                                          Flexible(
                                            child: Row(
                                              children: [
                                                Text(
                                                  'STR03',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 24,
                                                    color: Colors.black,
                                                  ),
                                                ),

                                                // 🔴 First Circle
                                                const SizedBox(width: 6),
                                                Visibility(
                                                  visible:
                                                      false, // 👈 TARTARUGA
                                                  maintainSize:
                                                      true, // keeps its width/height
                                                  maintainAnimation: true,
                                                  maintainState: true,
                                                  child: Container(
                                                    width: widget.circleSize,
                                                    height: widget.circleSize,
                                                    decoration: BoxDecoration(
                                                      color: getStationColor(
                                                          widget.stationStatus[
                                                                  3] ??
                                                              0),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Card(
                                                    color: Colors.white,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              widget.textColor,
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12),
                                                      child: Center(
                                                        child: Text(
                                                          widget
                                                              .stationInputs[3]
                                                              .toString(),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 24,
                                                            color: widget
                                                                .textColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                // Circle NG STR3
                                                Container(
                                                  width: widget.circleSize,
                                                  height: widget.circleSize,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        (widget.stationNG[3] ??
                                                                    0) ==
                                                                0
                                                            ? Colors.white
                                                            : getNgColor(
                                                                widget.stationNG[
                                                                        3] ??
                                                                    0,
                                                                widget.stationInputs[
                                                                        3] ??
                                                                    0,
                                                              ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: (widget.stationNG[
                                                                      3] ??
                                                                  0) ==
                                                              0
                                                          ? Colors.black
                                                          : Colors.transparent,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Card(
                                                    color: Colors.white,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              widget.textColor,
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12),
                                                      child: Center(
                                                        child: Text(
                                                          widget.stationNG[3]
                                                              .toString(),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 24,
                                                            color: widget
                                                                .textColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),
                                                // Circle Scrap STR3
                                                Container(
                                                  width: widget.circleSize,
                                                  height: widget.circleSize,
                                                  decoration: BoxDecoration(
                                                    color: (widget.stationScrap[
                                                                    3] ??
                                                                0) ==
                                                            0
                                                        ? Colors.white
                                                        : getNgColor(
                                                            widget.stationScrap[
                                                                    3] ??
                                                                0,
                                                            widget.stationInputs[
                                                                    3] ??
                                                                0,
                                                          ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color:
                                                          (widget.stationScrap[
                                                                          3] ??
                                                                      0) ==
                                                                  0
                                                              ? Colors.black
                                                              : Colors
                                                                  .transparent,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),

                                                Flexible(
                                                  child: Card(
                                                    color: Colors.white,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              widget.textColor,
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12),
                                                      child: Center(
                                                        child: Text(
                                                          widget.stationScrap[3]
                                                              .toString(),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 24,
                                                            color: widget
                                                                .textColor,
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

                                          // Fourth row of cards
                                          Flexible(
                                            child: Row(
                                              children: [
                                                Text(
                                                  'STR04',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 24,
                                                    color: Colors.black,
                                                  ),
                                                ),

                                                // 🔴 First Circle
                                                const SizedBox(width: 6),
                                                Visibility(
                                                  visible:
                                                      false, // 👈 TARTARUGA
                                                  maintainSize:
                                                      true, // keeps its width/height
                                                  maintainAnimation: true,
                                                  maintainState: true,
                                                  child: Container(
                                                    width: widget.circleSize,
                                                    height: widget.circleSize,
                                                    decoration: BoxDecoration(
                                                      color: getStationColor(
                                                          widget.stationStatus[
                                                                  4] ??
                                                              0),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Card(
                                                    color: Colors.white,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              widget.textColor,
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12),
                                                      child: Center(
                                                        child: Text(
                                                          widget
                                                              .stationInputs[4]
                                                              .toString(),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 24,
                                                            color: widget
                                                                .textColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                // Circle NG STR4
                                                Container(
                                                  width: widget.circleSize,
                                                  height: widget.circleSize,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        (widget.stationNG[4] ??
                                                                    0) ==
                                                                0
                                                            ? Colors.white
                                                            : getNgColor(
                                                                widget.stationNG[
                                                                        4] ??
                                                                    0,
                                                                widget.stationInputs[
                                                                        4] ??
                                                                    0,
                                                              ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: (widget.stationNG[
                                                                      4] ??
                                                                  0) ==
                                                              0
                                                          ? Colors.black
                                                          : Colors.transparent,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Card(
                                                    color: Colors.white,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              widget.textColor,
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12),
                                                      child: Center(
                                                        child: Text(
                                                          widget.stationNG[4]
                                                              .toString(),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 24,
                                                            color: widget
                                                                .textColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),
                                                // Circle Scrap STR4
                                                Container(
                                                  width: widget.circleSize,
                                                  height: widget.circleSize,
                                                  decoration: BoxDecoration(
                                                    color: (widget.stationScrap[
                                                                    4] ??
                                                                0) ==
                                                            0
                                                        ? Colors.white
                                                        : getNgColor(
                                                            widget.stationScrap[
                                                                    4] ??
                                                                0,
                                                            widget.stationInputs[
                                                                    4] ??
                                                                0,
                                                          ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color:
                                                          (widget.stationScrap[
                                                                          4] ??
                                                                      0) ==
                                                                  0
                                                              ? Colors.black
                                                              : Colors
                                                                  .transparent,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),

                                                Flexible(
                                                  child: Card(
                                                    color: Colors.white,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              widget.textColor,
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12),
                                                      child: Center(
                                                        child: Text(
                                                          widget.stationScrap[4]
                                                              .toString(),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 24,
                                                            color: widget
                                                                .textColor,
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

                                          // Fifth row of cards
                                          Flexible(
                                            child: Row(
                                              children: [
                                                Text(
                                                  'STR05',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 24,
                                                    color: Colors.black,
                                                  ),
                                                ),

                                                // 🔴 First Circle
                                                const SizedBox(width: 6),
                                                Visibility(
                                                  visible:
                                                      false, // 👈 TARTARUGA
                                                  maintainSize:
                                                      true, // keeps its width/height
                                                  maintainAnimation: true,
                                                  maintainState: true,
                                                  child: Container(
                                                    width: widget.circleSize,
                                                    height: widget.circleSize,
                                                    decoration: BoxDecoration(
                                                      color: getStationColor(
                                                          widget.stationStatus[
                                                                  5] ??
                                                              0),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Card(
                                                    color: Colors.white,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              widget.textColor,
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12),
                                                      child: Center(
                                                        child: Text(
                                                          widget
                                                              .stationInputs[5]
                                                              .toString(),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 24,
                                                            color: widget
                                                                .textColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                // Circle NG STR5
                                                Container(
                                                  width: widget.circleSize,
                                                  height: widget.circleSize,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        (widget.stationNG[5] ??
                                                                    0) ==
                                                                0
                                                            ? Colors.white
                                                            : getNgColor(
                                                                widget.stationNG[
                                                                        5] ??
                                                                    0,
                                                                widget.stationInputs[
                                                                        5] ??
                                                                    0,
                                                              ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: (widget.stationNG[
                                                                      5] ??
                                                                  0) ==
                                                              0
                                                          ? Colors.black
                                                          : Colors.transparent,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Card(
                                                    color: Colors.white,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              widget.textColor,
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12),
                                                      child: Center(
                                                        child: Text(
                                                          widget.stationNG[5]
                                                              .toString(),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 24,
                                                            color: widget
                                                                .textColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),
                                                // Circle Scrap STR5
                                                Container(
                                                  width: widget.circleSize,
                                                  height: widget.circleSize,
                                                  decoration: BoxDecoration(
                                                    color: (widget.stationScrap[
                                                                    5] ??
                                                                0) ==
                                                            0
                                                        ? Colors.white
                                                        : getNgColor(
                                                            widget.stationScrap[
                                                                    5] ??
                                                                0,
                                                            widget.stationInputs[
                                                                    5] ??
                                                                0,
                                                          ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color:
                                                          (widget.stationScrap[
                                                                          5] ??
                                                                      0) ==
                                                                  0
                                                              ? Colors.black
                                                              : Colors
                                                                  .transparent,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),

                                                Flexible(
                                                  child: Card(
                                                    color: Colors.white,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              widget.textColor,
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12),
                                                      child: Center(
                                                        child: Text(
                                                          widget.stationScrap[5]
                                                              .toString(),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 24,
                                                            color: widget
                                                                .textColor,
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
                              const SizedBox(width: 6),
                              Flexible(
                                child: Column(
                                  children: List.generate(5, (index) {
                                    final stationIndex = index + 1;
                                    return Expanded(
                                      child: HourlySTRBarChart(
                                        data: widget.hourlyThroughputPerStation[
                                                stationIndex] ??
                                            [],
                                        hourLabels: widget.hourLabels,
                                        target: widget.hourlyShiftTarget,
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
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
                                          /*Row(
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
                                          ),*/

                                          // First Yield
                                          Flexible(
                                            child: Row(
                                              children: [
                                                // Circle
                                                Container(
                                                  width: widget.circleSize,
                                                  height: widget.circleSize,
                                                  decoration: BoxDecoration(
                                                    color: widget.stationYield[
                                                                1] ==
                                                            0
                                                        ? Colors.white
                                                        : getYieldColor(
                                                            widget.stationYield[
                                                                    1] ??
                                                                0,
                                                            yield_target),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color:
                                                          widget.stationYield[
                                                                      1] ==
                                                                  0
                                                              ? Colors.black
                                                              : Colors
                                                                  .transparent,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(
                                                  width: 8,
                                                ),

                                                buildCompactCard(
                                                    '${widget.stationYield[1]}%'),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Second Yield
                                          Flexible(
                                            child: Row(
                                              children: [
                                                // Circle
                                                Container(
                                                  width: widget.circleSize,
                                                  height: widget.circleSize,
                                                  decoration: BoxDecoration(
                                                    color: widget.stationYield[
                                                                2] ==
                                                            0
                                                        ? Colors.white
                                                        : getYieldColor(
                                                            widget.stationYield[
                                                                    2] ??
                                                                0,
                                                            yield_target),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color:
                                                          widget.stationYield[
                                                                      2] ==
                                                                  0
                                                              ? Colors.black
                                                              : Colors
                                                                  .transparent,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(
                                                  width: 8,
                                                ),

                                                buildCompactCard(
                                                    '${widget.stationYield[2]}%'),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Third Yield
                                          Flexible(
                                            child: Row(
                                              children: [
                                                // Circle
                                                Container(
                                                  width: widget.circleSize,
                                                  height: widget.circleSize,
                                                  decoration: BoxDecoration(
                                                    color: widget.stationYield[
                                                                3] ==
                                                            0
                                                        ? Colors.white
                                                        : getYieldColor(
                                                            widget.stationYield[
                                                                    3] ??
                                                                0,
                                                            yield_target),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color:
                                                          widget.stationYield[
                                                                      3] ==
                                                                  0
                                                              ? Colors.black
                                                              : Colors
                                                                  .transparent,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(
                                                  width: 8,
                                                ),

                                                buildCompactCard(
                                                    '${widget.stationYield[3]}%'),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Fourth Yield
                                          Flexible(
                                            child: Row(
                                              children: [
                                                // Circle
                                                Container(
                                                  width: widget.circleSize,
                                                  height: widget.circleSize,
                                                  decoration: BoxDecoration(
                                                    color: widget.stationYield[
                                                                4] ==
                                                            0
                                                        ? Colors.white
                                                        : getYieldColor(
                                                            widget.stationYield[
                                                                    4] ??
                                                                0,
                                                            yield_target),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color:
                                                          widget.stationYield[
                                                                      4] ==
                                                                  0
                                                              ? Colors.black
                                                              : Colors
                                                                  .transparent,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(
                                                  width: 8,
                                                ),

                                                buildCompactCard(
                                                    '${widget.stationYield[4]}%'),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 4),

                                          // Fifth Yield
                                          Flexible(
                                            child: Row(
                                              children: [
                                                // Circle
                                                Container(
                                                  width: widget.circleSize,
                                                  height: widget.circleSize,
                                                  decoration: BoxDecoration(
                                                    color: widget.stationYield[
                                                                5] ==
                                                            0
                                                        ? Colors.white
                                                        : getYieldColor(
                                                            widget.stationYield[
                                                                    5] ??
                                                                0,
                                                            yield_target),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color:
                                                          widget.stationYield[
                                                                      5] ==
                                                                  0
                                                              ? Colors.black
                                                              : Colors
                                                                  .transparent,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(
                                                  width: 8,
                                                ),

                                                buildCompactCard(
                                                    '${widget.stationYield[5]}%'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                  flex: 3,
                                  child: Column(
                                    children: [
                                      Flexible(
                                        child: YieldComparisonSTRBarChart(
                                          data: widget.mergedShiftData,
                                          target: yield_target as double,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Second row with 1 card that fills all remaining space
                                      Yield2LineChart(
                                        hourlyData1: widget.strYieldLast8h,
                                        hourlyData2: widget.overallYieldLast8h,
                                        target: yield_target as double,
                                      ),
                                    ],
                                  ))
                            ],
                          ),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TrafficLightWithBackground(
                                  shiftManagerCount:
                                      widget.counts['shiftManager'] ?? 0,
                                  headOfProductionCount:
                                      widget.counts['headOfProduction'] ?? 0,
                                  closedCount: widget.counts['closed'] ?? 0,
                                ),
                                const SizedBox(height: 8),
                                (widget.lastNShifts > 0)
                                    ? Text(
                                        'Ultimi ${widget.lastNShifts} Shift',
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
                              last_n_shifts: widget.lastNShifts,
                              onEscalationsUpdated:
                                  refreshEscalationTrafficLight,
                            ),
                          ],
                        ),
                        Spacer(),

                        // Legend
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LegendRow(
                                color: widget.errorColor,
                                role: 'Head of production',
                                time: '> 4h'),
                            SizedBox(height: 8),
                            LegendRow(
                                color: widget.warningColor,
                                role: 'Shift Manager',
                                time: '2h << 4h'),
                            SizedBox(height: 8),
                            LegendRow(
                                color: widget.okColor,
                                role: 'Chiusi',
                                time: ''),
                          ],
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            // ────── SECOND HEADER ROW ──────
            Row(
              children: [
                // LEFT SIDE – UPTIME/DOWNTIME
                Flexible(
                  flex: 4,
                  child: HeaderBox(
                    title: 'UPTIME/DOWNTIME Shift',
                    target: '',
                    icon: Icons.timer_outlined,
                  ),
                ),

                // RIGHT SIDE – Pareto + NG Card
                Flexible(
                  flex: 5,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: HeaderBox(
                          title: 'Pareto Shift',
                          target: '',
                          icon: Icons.bar_chart_rounded,
                          qg2_defects_value: widget.qg2DefectsValue.toString(),
                          zone: 'STR',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

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
                                          'Available Time STR01',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // 🚧 Temporary replacement (Work in Progress)
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.construction,
                                                size: 16, color: Colors.orange),
                                            Text(
                                              'Work in Progress',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),

                                        /*
          // ⬇️ Original Gauge kept for later
          Column(
            children: [
              SizedBox(
                width: 100, // radius * 2
                child: Column(
                  children: [
                    AnimatedRadialGauge(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      value: (widget.zoneAvailability[1] ?? 0).toDouble(),
                      radius: 50,
                      axis: GaugeAxis(
                        min: 0,
                        max: 100,
                        degrees: 180,
                        style: const GaugeAxisStyle(
                          thickness: 6,
                          background: Color(0xFFDDDDDD),
                          segmentSpacing: 0,
                        ),
                        progressBar: GaugeRoundedProgressBar(
                          color: () {
                            if ((widget.zoneAvailability[1] ?? 0) <= 50) {
                              return widget.errorColor;
                            }
                            if ((widget.zoneAvailability[1] ?? 0) <= 75) {
                              return widget.warningColor;
                            }
                            return widget.okColor;
                          }(),
                        ),
                      ),
                      builder: (context, child, value) {
                        return Center(
                          child: Text(
                            '${value.toInt()}%',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          */
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // STR02
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
                                          'Available Time STR02',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // 🚧 Temporary replacement (Work in Progress)
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.construction,
                                                size: 16, color: Colors.orange),
                                            Text(
                                              'Work in Progress',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),

                                        /*
          // ⬇️ Original Gauge kept for later
          Column(
            children: [
              SizedBox(
                width: 100, // radius * 2
                child: Column(
                  children: [
                    AnimatedRadialGauge(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      value: (widget.zoneAvailability[2] ?? 0).toDouble(),
                      radius: 50,
                      axis: GaugeAxis(
                        min: 0,
                        max: 100,
                        degrees: 180,
                        style: const GaugeAxisStyle(
                          thickness: 6,
                          background: Color(0xFFDDDDDD),
                          segmentSpacing: 0,
                        ),
                        progressBar: GaugeRoundedProgressBar(
                          color: () {
                            if ((widget.zoneAvailability[2] ?? 0) <= 50) {
                              return widget.errorColor;
                            }
                            if ((widget.zoneAvailability[2] ?? 0) <= 75) {
                              return widget.warningColor;
                            }
                            return widget.okColor;
                          }(),
                        ),
                      ),
                      builder: (context, child, value) {
                        return Center(
                          child: Text(
                            '${value.toInt()}%',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          */
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // STR03
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
                                          'Available Time STR03',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // 🚧 Temporary replacement (Work in Progress)
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.construction,
                                                size: 16, color: Colors.orange),
                                            Text(
                                              'Work in Progress',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),

                                        /*
          // ⬇️ Original Gauge kept for later
          Column(
            children: [
              SizedBox(
                width: 100, // radius * 2
                child: Column(
                  children: [
                    AnimatedRadialGauge(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      value: (widget.zoneAvailability[3] ?? 0).toDouble(),
                      radius: 50,
                      axis: GaugeAxis(
                        min: 0,
                        max: 100,
                        degrees: 180,
                        style: const GaugeAxisStyle(
                          thickness: 6,
                          background: Color(0xFFDDDDDD),
                          segmentSpacing: 0,
                        ),
                        progressBar: GaugeRoundedProgressBar(
                          color: () {
                            if ((widget.zoneAvailability[3] ?? 0) <= 50) {
                              return widget.errorColor;
                            }
                            if ((widget.zoneAvailability[3] ?? 0) <= 75) {
                              return widget.warningColor;
                            }
                            return widget.okColor;
                          }(),
                        ),
                      ),
                      builder: (context, child, value) {
                        return Center(
                          child: Text(
                            '${value.toInt()}%',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          */
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // STR04
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
                                          'Available Time STR04',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // 🚧 Temporary replacement (Work in Progress)
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.construction,
                                                size: 16, color: Colors.orange),
                                            Text(
                                              'Work in Progress',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),

                                        /*
          // ⬇️ Original Gauge kept for later
          Column(
            children: [
              SizedBox(
                width: 100, // radius * 2
                child: Column(
                  children: [
                    AnimatedRadialGauge(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      value: (widget.zoneAvailability[4] ?? 0).toDouble(),
                      radius: 50,
                      axis: GaugeAxis(
                        min: 0,
                        max: 100,
                        degrees: 180,
                        style: const GaugeAxisStyle(
                          thickness: 6,
                          background: Color(0xFFDDDDDD),
                          segmentSpacing: 0,
                        ),
                        progressBar: GaugeRoundedProgressBar(
                          color: () {
                            if ((widget.zoneAvailability[4] ?? 0) <= 50) {
                              return widget.errorColor;
                            }
                            if ((widget.zoneAvailability[4] ?? 0) <= 75) {
                              return widget.warningColor;
                            }
                            return widget.okColor;
                          }(),
                        ),
                      ),
                      builder: (context, child, value) {
                        return Center(
                          child: Text(
                            '${value.toInt()}%',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          */
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // STR05
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
                                          'Available Time STR05',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // 🚧 Temporary replacement (Work in Progress)
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.construction,
                                                size: 16, color: Colors.orange),
                                            Text(
                                              'Work in Progress',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),

                                        /*
          // ⬇️ Original Gauge kept for later
          Column(
            children: [
              SizedBox(
                width: 100, // radius * 2
                child: Column(
                  children: [
                    AnimatedRadialGauge(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      value: (widget.zoneAvailability[5] ?? 0).toDouble(),
                      radius: 50,
                      axis: GaugeAxis(
                        min: 0,
                        max: 100,
                        degrees: 180,
                        style: const GaugeAxisStyle(
                          thickness: 6,
                          background: Color(0xFFDDDDDD),
                          segmentSpacing: 0,
                        ),
                        progressBar: GaugeRoundedProgressBar(
                          color: () {
                            if ((widget.zoneAvailability[5] ?? 0) <= 50) {
                              return widget.errorColor;
                            }
                            if ((widget.zoneAvailability[5] ?? 0) <= 75) {
                              return widget.warningColor;
                            }
                            return widget.okColor;
                          }(),
                        ),
                      ),
                      builder: (context, child, value) {
                        return Center(
                          child: Text(
                            '${value.toInt()}%',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          */
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              /*Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4.0),
                            child: Text(
                              'Sviluppato da 3SUN Process Eng, \nCapgemini, empowered by Bottero',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey.shade700),
                            ),
                          ),*/
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                          color: Colors.black, width: 1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Table(
                                        border: TableBorder.all(
                                            color: Colors.black, width: 0.5),
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
                                                padding: EdgeInsets.all(8),
                                                child: Text("Tipo \nFermata",
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.all(8),
                                                child: Text("Macchina",
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.all(4),
                                                child: Text("Frequenza",
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.all(8),
                                                child: Text(
                                                    "Fermo Cumulato (min)",
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                          if (_runningStop != null)
                                            TableRow(
                                              decoration: BoxDecoration(
                                                color: _runningStop![
                                                            'status'] ==
                                                        'CLOSED'
                                                    ? Colors
                                                        .white // default background for closed
                                                    : const Color(
                                                        0xFFFFF3E0), // highlighted if still open
                                              ),
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(15),
                                                  child: Text(
                                                      _runningStop!['reason'] ??
                                                          '',
                                                      style: const TextStyle(
                                                          fontSize: 24)),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(15),
                                                  child: Text(
                                                      _runningStop![
                                                              'station'] ??
                                                          '',
                                                      style: const TextStyle(
                                                          fontSize: 24)),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(15),
                                                  child: (_runningStop![
                                                              'status'] ==
                                                          'OPEN')
                                                      ? ElevatedButton(
                                                          onPressed:
                                                              _stopRunningStop,
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                            backgroundColor:
                                                                Colors
                                                                    .redAccent,
                                                            foregroundColor:
                                                                Colors.white,
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical:
                                                                        8),
                                                          ),
                                                          child: const Text(
                                                              'Stop'),
                                                        )
                                                      : const SizedBox
                                                          .shrink(), // hide only when closed
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(15),
                                                  child: Text(_formatDuration(
                                                      DateTime.now().difference(
                                                          _runningStop!['start']
                                                              as DateTime))),
                                                ),
                                              ],
                                            ),
                                          ...buildCustomRows(widget.dataFermi),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                StopButton(
                                  lastNShifts: widget.lastNShifts,
                                  onStopsUpdated: _onStopEnded,
                                  onStopStarted: _onStopStarted,
                                  zone: 'STR',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                Flexible(
                  flex: 3,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 400, // Limit overall height
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch, // Stretch charts
                        children: [
                          // Left: QG2 chart
                          Expanded(
                            child: TopDefectsHorizontalBarChartSTR(
                              defectLabels: widget.defectLabels,
                              Counts: widget.defectsCounts,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Right: VPF chart + text stacked
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment
                                  .spaceBetween, // Space chart + text
                              children: [
                                Expanded(
                                  child: VPFDefectsHorizontalBarChartSTR(
                                    defectLabels: widget.defectVPFLabels,
                                    Counts: widget.VpfDefectsCounts,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Sviluppato da 3SUN Process Eng,\nCapgemini, empowered by Bottero',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF616161), // grey700
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          ],
        ),
        Positioned(
          top: 80,
          left: 125,
          child: Row(
            children: [
              SizedBox(
                width: 70, // ✅ Set fixed width per label
                child: Text(
                  'STR G',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(width: 30),
              SizedBox(
                width: 70,
                child: Text(
                  'STR NG',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(
                width: 200, // wider for longer label
                child: Text(
                  'Celle NG (Stringhe EQ)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(width: 190),
              /*SizedBox(
                width: 125, // wider for longer label
                child: Text(
                  'Target Orario: ${widget.hourlyShiftTarget.toString()}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 14,
                  ),
                ),
              ),*/
              SizedBox(width: 125),
              SizedBox(width: 15),
              SizedBox(
                width: 200, // wider for longer label
                child: Text(
                  'Yield Media (Shift)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}
