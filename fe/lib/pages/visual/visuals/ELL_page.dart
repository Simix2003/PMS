// ignore_for_file: must_be_immutable, non_constant_identifier_names, file_names

import 'package:flutter/material.dart';
import 'package:ix_monitor/pages/visual/visual_widgets.dart';
import '../../../shared/services/api_service.dart';
import '../escalation_visual.dart';

class EllVisualsPage extends StatefulWidget {
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
  final int ng_1;
  final int ng_2;
  final int in_1;
  final int in_2;
  final int currentFPYYield;
  final int currentRWKYield;
  final List<Map<String, int>> throughputDataEll;
  final List<String> shiftLabels;
  final List<Map<String, int>> hourlyData;
  final List<String> hourLabels;
  final List<List<String>> dataFermi;
  final List<Map<String, dynamic>> mergedShiftData;
  final List<Map<String, dynamic>> FPYLast8h;
  final List<Map<String, dynamic>> RWKLast8h;
  final Map<String, int> counts;
  final List<String> defectLabels;
  final List<int> min1Counts;
  final List<int> min2Counts;
  final List<int> ellCounts;
  final List<Map<String, dynamic>> shiftThroughput;
  final List<Map<String, dynamic>> FPY_yield_shifts;
  final List<Map<String, dynamic>> RWK_yield_shifs;
  final int last_n_shifts;

  const EllVisualsPage({
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
    required this.ng_1,
    required this.ng_2,
    required this.in_1,
    required this.in_2,
    required this.currentFPYYield,
    required this.currentRWKYield,
    required this.throughputDataEll,
    required this.shiftLabels,
    required this.hourlyData,
    required this.hourLabels,
    required this.dataFermi,
    required this.mergedShiftData,
    required this.FPYLast8h,
    required this.RWKLast8h,
    required this.counts,
    required this.defectLabels,
    required this.min1Counts,
    required this.min2Counts,
    required this.ellCounts,
    required this.shiftThroughput,
    required this.FPY_yield_shifts,
    required this.RWK_yield_shifs,
    required this.last_n_shifts,
  });

  @override
  State<EllVisualsPage> createState() => _EllVisualsPageState();
}

class _EllVisualsPageState extends State<EllVisualsPage> {
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
                                            width: 100,
                                          ), // aligns with the AIN 1 / AIN 2 label
                                          Flexible(
                                            child: Center(
                                              child: Text(
                                                'IN Good',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 70),
                                          Flexible(
                                            child: Center(
                                              child: Text(
                                                'OUT NG',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 4),

                                      // First row of cards
                                      Flexible(
                                        child: Row(
                                          children: [
                                            Text(
                                              'ELL',
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
                                                      widget.in_1.toString(),
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

                                            const SizedBox(width: 24),

                                            // 🟢 Second Circle
                                            Container(
                                              width: widget.circleSize,
                                              height: widget.circleSize,
                                              decoration: BoxDecoration(
                                                color: widget.ng_1 == 0
                                                    ? Colors.white
                                                    : getNgColor(widget.ng_1,
                                                        widget.in_1),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: widget.ng_1 == 0
                                                      ? Colors.black
                                                      : Colors.transparent,
                                                  width: 2,
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
                                                      widget.ng_1.toString(),
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
                                      const SizedBox(height: 4),

                                      Row(
                                        children: [
                                          const SizedBox(
                                            width: 100,
                                          ), // aligns with the AIN 1 / AIN 2 label
                                          Flexible(
                                            child: Center(
                                              child: Text(
                                                'IN',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 70),
                                          Flexible(
                                            child: Center(
                                              child: Text(
                                                'Scrap',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Second row of cards
                                      Flexible(
                                        child: Row(
                                          children: [
                                            Text(
                                              'RMI',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 24,
                                                color: Colors.black,
                                              ),
                                            ),
                                            SizedBox(width: 8),

                                            Container(
                                              width: widget.circleSize,
                                              height: widget.circleSize,
                                              decoration: BoxDecoration(
                                                color: getStationColor(
                                                    widget.station_2_status),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            SizedBox(width: 8),
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
                                                      widget.in_2.toString(),
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
                                            const SizedBox(width: 24),
                                            // 🟢 Second Circle
                                            Container(
                                              width: widget.circleSize,
                                              height: widget.circleSize,
                                              decoration: BoxDecoration(
                                                color: widget.ng_2 == 0
                                                    ? Colors.white
                                                    : getNgColor(widget.ng_2,
                                                        widget.in_2),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: widget.ng_2 == 0
                                                      ? Colors.black
                                                      : Colors.transparent,
                                                  width: 2,
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
                                                      widget.ng_2.toString(),
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
                          ThroughputELLBarChart(
                            data: widget.throughputDataEll,
                            labels: widget.shiftLabels,
                            globalTarget: shift_target.toDouble(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Second row with 1 card that fills all remaining space
                    Flexible(
                      child: HourlyELLBarChart(
                        data: widget.hourlyData,
                        hourLabels: widget.hourLabels,
                        target: hourly_shift_target,
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
                                                'FPY media (Shift)',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 4),

                                      // First row of cards
                                      Flexible(
                                        child: Row(
                                          children: [
                                            // Circle
                                            Container(
                                              width: widget.circleSize,
                                              height: widget.circleSize,
                                              decoration: BoxDecoration(
                                                color: widget.currentFPYYield ==
                                                        0
                                                    ? Colors.white
                                                    : getYieldColor(
                                                        widget.currentFPYYield,
                                                        yield_target),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color:
                                                      widget.currentFPYYield ==
                                                              0
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
                                                      '${widget.currentFPYYield.toString()}%',
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

                                      Row(
                                        children: [
                                          Flexible(
                                            child: Center(
                                              child: Text(
                                                'Yield con RMI (Shift)',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
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
                                                color: widget.currentRWKYield ==
                                                        0
                                                    ? Colors.white
                                                    : getYieldColor(
                                                        widget.currentRWKYield,
                                                        yield_target),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color:
                                                      widget.currentRWKYield ==
                                                              0
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
                                                      '${widget.currentRWKYield.toString()}%',
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
                            child: YieldComparisonELLBarChart(
                              data: widget.mergedShiftData,
                              target: yield_target as double,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Second row with 1 card that fills all remaining space
                    YieldELLLineChart(
                      hourlyData_FPY: widget.FPYLast8h,
                      hourlyData_RWK: widget.RWKLast8h,
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

                        Column(
                          children: [
                            // Right side: Escalation button
                            EscalationButton(
                              last_n_shifts: widget.last_n_shifts,
                              onEscalationsUpdated:
                                  refreshEscalationTrafficLight,
                            ),
                          ],
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

        // ────── SECOND HEADER ROW ──────
        Row(
          children: [
            // RIGHT SIDE – Pareto + NG Card
            Flexible(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: HeaderBox(
                      title: 'Pareto Shift',
                      target: '',
                      icon: Icons.bar_chart_rounded,
                      zone: 'ELL',
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
                        child: TopDefectsRMIHorizontalBarChart(
                          defectLabels: widget.defectLabels,
                          min1Counts: widget.min1Counts,
                          min2Counts: widget.min2Counts,
                          ellCounts: widget.ellCounts,
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
                              child: BufferChart(),
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
