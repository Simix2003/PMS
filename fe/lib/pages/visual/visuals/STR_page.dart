// ignore_for_file: must_be_immutable, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:gauge_indicator/gauge_indicator.dart';
import 'package:ix_monitor/pages/visual/visual_widgets.dart';
import '../../../shared/services/api_service.dart';
import '../escalation_visual.dart';

class StrVisualsPage extends StatefulWidget {
  final int shift_target;
  final double hourly_shift_target;
  final int yield_target;
  final double circleSize;
  final int station_1_status;
  final int station_2_status;
  final Color errorColor;
  final Color okColor;
  final Color textColor;
  final Color warningColor;
  final Color redColor;
  final int ng_bussingOut_1;
  final int ng_bussingOut_2;
  final int bussingIn_1;
  final int bussingIn_2;
  final int currentYield_1;
  final int currentYield_2;
  final List<Map<String, int>> throughputData;
  final List<String> shiftLabels;
  final List<Map<String, int>> hourlyData;
  final List<String> hourLabels;
  final List<Map<String, dynamic>> station1Shifts;
  final List<Map<String, dynamic>> station2Shifts;
  final List<Map<String, dynamic>> mergedShiftData;
  final List<List<String>> dataFermi;
  final List<Map<String, dynamic>> yieldLast8h_1;
  final List<Map<String, dynamic>> yieldLast8h_2;
  final Map<String, int> counts;
  final int availableTime_1;
  final int availableTime_2;
  final List<String> defectLabels;
  final List<String> defectVPFLabels;
  final List<int> ain1Counts;
  final List<int> ain1VPFCounts;
  final List<int> ain2Counts;
  final List<int> ain2VPFCounts;
  final int qg2_defects_value;
  final int last_n_shifts;

  const StrVisualsPage({
    super.key,
    required this.shift_target,
    required this.hourly_shift_target,
    required this.yield_target,
    required this.circleSize,
    required this.station_1_status,
    required this.station_2_status,
    required this.errorColor,
    required this.okColor,
    required this.textColor,
    required this.warningColor,
    required this.redColor,
    required this.ng_bussingOut_1,
    required this.ng_bussingOut_2,
    required this.bussingIn_1,
    required this.bussingIn_2,
    required this.currentYield_1,
    required this.currentYield_2,
    required this.throughputData,
    required this.shiftLabels,
    required this.hourlyData,
    required this.hourLabels,
    required this.station1Shifts,
    required this.station2Shifts,
    required this.mergedShiftData,
    required this.dataFermi,
    required this.yieldLast8h_1,
    required this.yieldLast8h_2,
    required this.counts,
    required this.availableTime_1,
    required this.availableTime_2,
    required this.defectLabels,
    required this.defectVPFLabels,
    required this.ain1Counts,
    required this.ain1VPFCounts,
    required this.ain2Counts,
    required this.ain2VPFCounts,
    required this.qg2_defects_value,
    required this.last_n_shifts,
  });

  @override
  State<StrVisualsPage> createState() => _StrVisualsPageState();
}

class _StrVisualsPageState extends State<StrVisualsPage> {
  late int shift_target;
  late double hourly_shift_target;
  late int yield_target;

  @override
  void initState() {
    super.initState();
    shift_target = widget.shift_target;
    yield_target = widget.yield_target;
    hourly_shift_target = widget.hourly_shift_target;
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
    } else if (value >= target - 5) {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ────── FIRST HEADER ROW ──────
        Row(
          children: [
            Flexible(
              flex: 4,
              child: // Shift target (moduli)
                  GestureDetector(
                onTap: () {
                  showTargetEditDialog(
                    title: 'Target Produzione Shift',
                    currentValue: shift_target,
                    onValueSaved: (newVal) async {
                      setState(() {
                        shift_target = newVal;
                        hourly_shift_target = (newVal ~/ 8).toDouble();
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
                                            width: 125,
                                          ), // aligns with the AIN 1 / AIN 2 label
                                          Flexible(
                                            child: Center(
                                              child: Text(
                                                'STR G',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 40),
                                          Flexible(
                                            child: Center(
                                              child: Text(
                                                'STR NG',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 40),
                                          Flexible(
                                            child: Center(
                                              child: Text(
                                                'CELL SCRAP',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
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
                                              'STR01',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 24,
                                                color: Colors.black,
                                              ),
                                            ),

                                            // 🔴 First Circle
                                            const SizedBox(width: 8),
                                            Container(
                                              width: widget.circleSize,
                                              height: widget.circleSize,
                                              decoration: BoxDecoration(
                                                color: getStationColor(
                                                    widget.station_1_status),
                                                shape: BoxShape.circle,
                                              ),
                                            ),

                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Card(
                                                color: Colors.white,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: widget.textColor,
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Center(
                                                    child: Text(
                                                      widget.bussingIn_1
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 32,
                                                        color: widget.textColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Card(
                                                color: Colors.white,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: widget.textColor,
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Center(
                                                    child: Text(
                                                      widget.bussingIn_1
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 32,
                                                        color: widget.textColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            Flexible(
                                              child: Card(
                                                color: Colors.white,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: widget.textColor,
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Center(
                                                    child: Text(
                                                      widget.ng_bussingOut_1
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 32,
                                                        color: widget.textColor,
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
                                            const SizedBox(width: 8),
                                            Container(
                                              width: widget.circleSize,
                                              height: widget.circleSize,
                                              decoration: BoxDecoration(
                                                color: getStationColor(
                                                    widget.station_1_status),
                                                shape: BoxShape.circle,
                                              ),
                                            ),

                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Card(
                                                color: Colors.white,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: widget.textColor,
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Center(
                                                    child: Text(
                                                      widget.bussingIn_1
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 32,
                                                        color: widget.textColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Card(
                                                color: Colors.white,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: widget.textColor,
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Center(
                                                    child: Text(
                                                      widget.bussingIn_1
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 32,
                                                        color: widget.textColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            Flexible(
                                              child: Card(
                                                color: Colors.white,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: widget.textColor,
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Center(
                                                    child: Text(
                                                      widget.ng_bussingOut_1
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 32,
                                                        color: widget.textColor,
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
                                              'STR03',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 24,
                                                color: Colors.black,
                                              ),
                                            ),

                                            // 🔴 First Circle
                                            const SizedBox(width: 8),
                                            Container(
                                              width: widget.circleSize,
                                              height: widget.circleSize,
                                              decoration: BoxDecoration(
                                                color: getStationColor(
                                                    widget.station_1_status),
                                                shape: BoxShape.circle,
                                              ),
                                            ),

                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Card(
                                                color: Colors.white,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: widget.textColor,
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Center(
                                                    child: Text(
                                                      widget.bussingIn_1
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 32,
                                                        color: widget.textColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Card(
                                                color: Colors.white,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: widget.textColor,
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Center(
                                                    child: Text(
                                                      widget.bussingIn_1
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 32,
                                                        color: widget.textColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            Flexible(
                                              child: Card(
                                                color: Colors.white,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: widget.textColor,
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Center(
                                                    child: Text(
                                                      widget.ng_bussingOut_1
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 32,
                                                        color: widget.textColor,
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
                                              'STR04',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 24,
                                                color: Colors.black,
                                              ),
                                            ),

                                            // 🔴 First Circle
                                            const SizedBox(width: 8),
                                            Container(
                                              width: widget.circleSize,
                                              height: widget.circleSize,
                                              decoration: BoxDecoration(
                                                color: getStationColor(
                                                    widget.station_1_status),
                                                shape: BoxShape.circle,
                                              ),
                                            ),

                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Card(
                                                color: Colors.white,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: widget.textColor,
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Center(
                                                    child: Text(
                                                      widget.bussingIn_1
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 32,
                                                        color: widget.textColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Card(
                                                color: Colors.white,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: widget.textColor,
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Center(
                                                    child: Text(
                                                      widget.bussingIn_1
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 32,
                                                        color: widget.textColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            Flexible(
                                              child: Card(
                                                color: Colors.white,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: widget.textColor,
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Center(
                                                    child: Text(
                                                      widget.ng_bussingOut_1
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 32,
                                                        color: widget.textColor,
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
                                              'STR05',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 24,
                                                color: Colors.black,
                                              ),
                                            ),

                                            // 🔴 First Circle
                                            const SizedBox(width: 8),
                                            Container(
                                              width: widget.circleSize,
                                              height: widget.circleSize,
                                              decoration: BoxDecoration(
                                                color: getStationColor(
                                                    widget.station_1_status),
                                                shape: BoxShape.circle,
                                              ),
                                            ),

                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Card(
                                                color: Colors.white,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: widget.textColor,
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Center(
                                                    child: Text(
                                                      widget.bussingIn_1
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 32,
                                                        color: widget.textColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Card(
                                                color: Colors.white,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: widget.textColor,
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Center(
                                                    child: Text(
                                                      widget.bussingIn_1
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 32,
                                                        color: widget.textColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            Flexible(
                                              child: Card(
                                                color: Colors.white,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: widget.textColor,
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Center(
                                                    child: Text(
                                                      widget.ng_bussingOut_1
                                                          .toString(),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 32,
                                                        color: widget.textColor,
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
                            data: widget.throughputData,
                            labels: widget.shiftLabels,
                            globalTarget: shift_target.toDouble(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Second row with 1 card that fills all remaining space
                    /*Flexible(
                      child: HourlyBarChart(
                        data: widget.hourlyData,
                        hourLabels: widget.hourLabels,
                        target: hourly_shift_target,
                      ),
                    ),*/
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
                                                  fontWeight: FontWeight.bold,
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
                                              width: widget.circleSize,
                                              height: widget.circleSize,
                                              decoration: BoxDecoration(
                                                color: widget.currentYield_1 ==
                                                        0
                                                    ? Colors.white
                                                    : getYieldColor(
                                                        widget.currentYield_1,
                                                        yield_target),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color:
                                                      widget.currentYield_1 == 0
                                                          ? Colors.black
                                                          : Colors.transparent,
                                                  width: 2,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(
                                              width: 8,
                                            ),

                                            Flexible(
                                              child: Card(
                                                color: Colors.white,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: widget.textColor,
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Center(
                                                    child: Text(
                                                      '${widget.currentYield_1.toString()}%',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 32,
                                                        color: widget.textColor,
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
                                              width: widget.circleSize,
                                              height: widget.circleSize,
                                              decoration: BoxDecoration(
                                                color: widget.currentYield_2 ==
                                                        0
                                                    ? Colors.white
                                                    : getYieldColor(
                                                        widget.currentYield_2,
                                                        yield_target),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color:
                                                      widget.currentYield_2 == 0
                                                          ? Colors.black
                                                          : Colors.transparent,
                                                  width: 2,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(
                                              width: 8,
                                            ),
                                            Flexible(
                                              child: Card(
                                                color: Colors.white,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: widget.textColor,
                                                      width: 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Center(
                                                    child: Text(
                                                      '${widget.currentYield_2.toString()}%',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 32,
                                                        color: widget.textColor,
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
                              data: widget.mergedShiftData,
                              target: yield_target as double,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Second row with 1 card that fills all remaining space
                    Yield2LineChart(
                      hourlyData1: widget.yieldLast8h_1,
                      hourlyData2: widget.yieldLast8h_2,
                      target: yield_target as double,
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
                            (widget.last_n_shifts > 0)
                                ? Text(
                                    'Ultimi ${widget.last_n_shifts} Shift',
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
                          last_n_shifts: widget.last_n_shifts,
                          onEscalationsUpdated: refreshEscalationTrafficLight,
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
                            color: widget.okColor, role: 'Chiusi', time: ''),
                      ],
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 48),
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
                  Flexible(
                    child: HeaderBox(
                      title: 'Pareto Shift',
                      target: '',
                      icon: Icons.bar_chart_rounded,
                      qg2_defects_value: widget.qg2_defects_value.toString(),
                      zone: 'AIN',
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
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                                                duration: const Duration(
                                                    milliseconds: 800),
                                                curve: Curves.easeInOut,
                                                value: widget.availableTime_1
                                                    .toDouble(),
                                                radius: 100,
                                                axis: GaugeAxis(
                                                  min: 0,
                                                  max: 100,
                                                  degrees: 180,
                                                  style: const GaugeAxisStyle(
                                                    thickness: 16,
                                                    background:
                                                        Color(0xFFDDDDDD),
                                                    segmentSpacing: 0,
                                                  ),
                                                  progressBar:
                                                      GaugeRoundedProgressBar(
                                                    color: () {
                                                      if (widget
                                                              .availableTime_1 <=
                                                          50) {
                                                        return widget
                                                            .errorColor;
                                                      }
                                                      if (widget
                                                              .availableTime_1 <=
                                                          75) {
                                                        return widget
                                                            .warningColor;
                                                      }
                                                      return widget.okColor;
                                                    }(),
                                                  ),
                                                ),
                                                builder:
                                                    (context, child, value) {
                                                  return Center(
                                                    child: Text(
                                                      '${value.toInt()}%',
                                                      style: const TextStyle(
                                                        fontSize: 32,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: 6),
                                              const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text('0%',
                                                      style: TextStyle(
                                                          fontSize: 14)),
                                                  Text('100%',
                                                      style: TextStyle(
                                                          fontSize: 14)),
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
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                                                duration: const Duration(
                                                    milliseconds: 800),
                                                curve: Curves.easeInOut,
                                                value: widget.availableTime_2
                                                    .toDouble(),
                                                radius: 100,
                                                axis: GaugeAxis(
                                                  min: 0,
                                                  max: 100,
                                                  degrees: 180,
                                                  style: const GaugeAxisStyle(
                                                    thickness: 16,
                                                    background:
                                                        Color(0xFFDDDDDD),
                                                    segmentSpacing: 0,
                                                  ),
                                                  progressBar:
                                                      GaugeRoundedProgressBar(
                                                    color: () {
                                                      if (widget
                                                              .availableTime_2 <=
                                                          50) {
                                                        return widget
                                                            .errorColor;
                                                      }
                                                      if (widget
                                                              .availableTime_2 <=
                                                          75) {
                                                        return widget
                                                            .warningColor;
                                                      }
                                                      return widget.okColor;
                                                    }(),
                                                  ),
                                                ),
                                                builder:
                                                    (context, child, value) {
                                                  return Center(
                                                    child: Text(
                                                      '${value.toInt()}%',
                                                      style: const TextStyle(
                                                        fontSize: 32,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: 6),
                                              const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text('0%',
                                                      style: TextStyle(
                                                          fontSize: 14)),
                                                  Text('100%',
                                                      style: TextStyle(
                                                          fontSize: 14)),
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border:
                                      Border.all(color: Colors.black, width: 1),
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
                                        decoration:
                                            BoxDecoration(color: Colors.white),
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
                                            child: Text("Fermo Cumulato (min)",
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                      ...buildCustomRows(widget.dataFermi),
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
                          defectLabels: widget.defectLabels,
                          ain1Counts: widget.ain1Counts,
                          ain2Counts: widget.ain2Counts,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // RIGHT COLUMN (1 full-height card)
                      Flexible(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: VPFDefectsHorizontalBarChart(
                                defectLabels: widget.defectVPFLabels,
                                ain1Counts: widget.ain1VPFCounts,
                                ain2Counts: widget.ain2VPFCounts,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text(
                                'Sviluppato da 3SUN Process Eng, \nCapgemini, empowered by Bottero',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
