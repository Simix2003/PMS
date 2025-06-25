// ignore_for_file: must_be_immutable, non_constant_identifier_names, file_names

import 'package:flutter/material.dart';
import 'package:ix_monitor/pages/visual/visual_widgets.dart';
import '../../../shared/services/api_service.dart';
import '../escalation_visual.dart';

class VpfVisualsPage extends StatefulWidget {
  final int shift_target;
  final double hourly_shift_target;
  final int yield_target;
  final double circleSize;
  final int station_1_status;
  final Color errorColor;
  final Color okColor;
  final Color textColor;
  final Color warningColor;
  final Color redColor;
  final int In_1;
  final int ngOut_1;
  final int reEntered_1;
  final int currentYield_1;
  final List<Map<String, dynamic>> speedRatioData;
  final List<Map<String, dynamic>> station1Shifts;
  final List<Map<String, dynamic>> yieldLast8h_1;
  final Map<String, int> counts;
  final List<Map<String, dynamic>> defectsVPF;
  final int last_n_shifts;
  final Map<String, Map<String, int>> eqDefects;

  const VpfVisualsPage({
    super.key,
    required this.shift_target,
    required this.hourly_shift_target,
    required this.yield_target,
    required this.circleSize,
    required this.station_1_status,
    required this.errorColor,
    required this.okColor,
    required this.textColor,
    required this.warningColor,
    required this.redColor,
    required this.In_1,
    required this.ngOut_1,
    required this.reEntered_1,
    required this.currentYield_1,
    required this.speedRatioData,
    required this.station1Shifts,
    required this.counts,
    required this.defectsVPF,
    required this.last_n_shifts,
    required this.yieldLast8h_1,
    required this.eqDefects,
  });

  @override
  State<VpfVisualsPage> createState() => _VpfVisualsPageState();
}

class _VpfVisualsPageState extends State<VpfVisualsPage> {
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
                      flex: 1,
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
                                          ), // aligns with the VPF label
                                          Flexible(
                                            child: Center(
                                              child: Text(
                                                'Moduli Ispezionati',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 70),
                                          Flexible(
                                            child: Center(
                                              child: Text(
                                                'Moduli OUT NG',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // First row of cards
                                      Flexible(
                                        child: Row(
                                          children: [
                                            Text(
                                              'VPF',
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
                                                      widget.In_1.toString(),
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
                                                color: getNgColor(
                                                  widget.ngOut_1,
                                                  widget.In_1,
                                                ),
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
                                                      widget.ngOut_1.toString(),
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
                                      Flexible(
                                        child: Visibility(
                                          visible:
                                              false, // 👈 hide it but keep layout
                                          maintainSize: true,
                                          maintainAnimation: true,
                                          maintainState: true,
                                          maintainSemantics: true,
                                          maintainInteractivity: false,
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      'VPF',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 24,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      width: widget.circleSize,
                                                      height: widget.circleSize,
                                                      decoration: BoxDecoration(
                                                        color: getStationColor(
                                                            widget
                                                                .station_1_status),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Card(
                                                        color: Colors.white,
                                                        child: Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            border: Border.all(
                                                                color: widget
                                                                    .textColor,
                                                                width: 1),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 12),
                                                          child: Center(
                                                            child: Text(
                                                              widget.In_1
                                                                  .toString(),
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 32,
                                                                color: widget
                                                                    .textColor,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 24),
                                                    Container(
                                                      width: widget.circleSize,
                                                      height: widget.circleSize,
                                                      decoration: BoxDecoration(
                                                        color: getNgColor(
                                                            widget.ngOut_1,
                                                            widget.In_1),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Card(
                                                        color: Colors.white,
                                                        child: Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            border: Border.all(
                                                                color: widget
                                                                    .textColor,
                                                                width: 1),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 12),
                                                          child: Center(
                                                            child: Text(
                                                              widget.ngOut_1
                                                                  .toString(),
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 32,
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
                                      ),

                                      // Second row of cards
                                      Flexible(
                                        flex: 2,
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Hidden but layout-preserving VPF + Circle
                                            Visibility(
                                              visible: false,
                                              maintainSize: true,
                                              maintainAnimation: true,
                                              maintainState: true,
                                              maintainSemantics: true,
                                              maintainInteractivity: false,
                                              child: Row(
                                                children: [
                                                  Text(
                                                    'VPF',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 24,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    width: widget.circleSize,
                                                    height: widget.circleSize,
                                                    decoration: BoxDecoration(
                                                      color: getStationColor(
                                                          widget
                                                              .station_1_status),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(
                                                width:
                                                    12), // spacing between columns

                                            // First card (Moduli Rientrati)
                                            Flexible(
                                              flex: 1,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Moduli Rientrati',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 24,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 32),
                                                  Card(
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
                                                          widget.reEntered_1
                                                              .toString(),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 32,
                                                            color: widget
                                                                .textColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(width: 12),

                                            // Hidden trailing circle
                                            Visibility(
                                              visible: false,
                                              maintainSize: true,
                                              maintainAnimation: true,
                                              maintainState: true,
                                              maintainSemantics: true,
                                              maintainInteractivity: false,
                                              child: Row(
                                                children: [
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    width: widget.circleSize,
                                                    height: widget.circleSize,
                                                    decoration: BoxDecoration(
                                                      color: getStationColor(
                                                          widget
                                                              .station_1_status),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(width: 12),

                                            // SpeedBar
                                            Flexible(
                                              flex: 2,
                                              child: Column(
                                                children: [
                                                  Text(
                                                    'Speed Ratio',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 24,
                                                    ),
                                                  ),
                                                  SpeedBar(
                                                    medianSec:
                                                        widget.speedRatioData[0]
                                                            ['medianSec'],
                                                    currentSec:
                                                        widget.speedRatioData[0]
                                                            ['currentSec'],
                                                    textColor: widget.textColor,
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
                              ],
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
                                                color: getYieldColor(
                                                  widget.currentYield_1,
                                                  yield_target,
                                                ),
                                                shape: BoxShape.circle,
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

                                      Flexible(
                                        child: Visibility(
                                          visible: false,
                                          maintainSize: true,
                                          maintainAnimation: true,
                                          maintainState: true,
                                          maintainSemantics: true,
                                          maintainInteractivity: false,
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: widget.circleSize,
                                                      height: widget.circleSize,
                                                      decoration: BoxDecoration(
                                                        color: getYieldColor(
                                                            widget
                                                                .currentYield_1,
                                                            yield_target),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Card(
                                                        color: Colors.white,
                                                        child: Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            border: Border.all(
                                                                color: widget
                                                                    .textColor,
                                                                width: 1),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 12),
                                                          child: Center(
                                                            child: Text(
                                                              '${widget.currentYield_1}%',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 32,
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
                            child: YieldBarChart(
                              data: widget.station1Shifts,
                              target: yield_target as double,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Second row with 1 card that fills all remaining space
                    YieldLineChart(
                      hourlyData1: widget.yieldLast8h_1,
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

        // ────── SECOND HEADER ROW ──────
        Row(
          children: [
            // RIGHT SIDE – Pareto + NG Card
            Flexible(
              flex: 1,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: HeaderBox(
                      title: 'Pareto Shift',
                      target: '',
                      icon: Icons.bar_chart_rounded,
                      zone: 'VPF',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              flex: 3,
              child: DefectMatrixCard(defectStationCountMap: widget.eqDefects),
            ),
            Flexible(
              flex: 4,
              child: SizedBox(
                height: 460,
                child: DefectBarChartCard(defects: widget.defectsVPF),
              ),
            ),
            Flexible(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 410,
                    child: StackedDefectBarCard(defects: widget.defectsVPF),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      'Sviluppato da\n gruppo Process Eng e Capgemini',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color:
                            Color(0xFF616161), // same as Colors.grey.shade700
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        )
      ],
    );
  }
}
