// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
//import 'package:fl_chart/fl_chart.dart';
import 'visual_widgets.dart';
import 'package:gauge_indicator/gauge_indicator.dart';

class VisualPage extends StatefulWidget {
  const VisualPage({super.key});

  @override
  _VisualPageState createState() => _VisualPageState();
}

class _VisualPageState extends State<VisualPage> {
  double value = 79;
  Color errorColor = Colors.amber.shade700;
  Color warningColor = Colors.yellow.shade400;
  Color okColor = Colors.green.shade400;
  Color textColor = Colors.black;
  double circleSize = 32;

  final List<Map<String, dynamic>> yieldData = [
    {"shift": "S1", "bussing1": 86, "bussing2": 92},
    {"shift": "S2", "bussing1": 78, "bussing2": 83},
    {"shift": "S3", "bussing1": 91, "bussing2": 89},
  ];

  final hourlyYieldData = [
    {'hour': '08', 'bussing1': 91, 'bussing2': 88},
    {'hour': '09', 'bussing1': 92, 'bussing2': 90},
    {'hour': '10', 'bussing1': 75, 'bussing2': 85},
    {'hour': '11', 'bussing1': 78, 'bussing2': 91},
    {'hour': '12', 'bussing1': 62, 'bussing2': 86},
    {'hour': '13', 'bussing1': 53, 'bussing2': 89},
    {'hour': '14', 'bussing1': 80, 'bussing2': 87},
    {'hour': '15', 'bussing1': 92, 'bussing2': 88},
  ];

  // Function that takes in input the Current value, the target value and the threshold
  // and returns the color of the gauge
  Color getColor(double value, double target, double threshold) {
    if (value > target) {
      return okColor;
    } else if (value < target - threshold) {
      return warningColor;
    } else {
      return errorColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ────── FIRST HEADER ROW ──────
              Row(
                children: const [
                  Expanded(
                    flex: 4,
                    child: HeaderBox(
                      title: 'Produzione Shift',
                      target: '360',
                      icon: Icons.solar_power,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: HeaderBox(
                      title: 'YIELD',
                      target: '90%',
                      icon: Icons.show_chart,
                    ),
                  ),
                  Expanded(
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
                  Expanded(
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
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            // Row titles (aligned with the two card columns)
                                            Row(
                                              children: [
                                                const SizedBox(
                                                  width: 100,
                                                ), // aligns with the AIN 1 / AIN 2 label
                                                Expanded(
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
                                                Expanded(
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
                                            Expanded(
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
                                                    decoration: BoxDecoration(
                                                      color: getColor(
                                                          176, 180, 25),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),

                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Card(
                                                      color: Colors.white,
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          border: Border.all(
                                                            color: textColor,
                                                            width: 1,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 12),
                                                        child: Center(
                                                          child: Text(
                                                            '176',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 32,
                                                              color: textColor,
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
                                                    decoration: BoxDecoration(
                                                      color:
                                                          getColor(19, 10, 5),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),

                                                  const SizedBox(width: 8),

                                                  Expanded(
                                                    child: Card(
                                                      color: Colors.white,
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          border: Border.all(
                                                            color: textColor,
                                                            width: 1,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 12),
                                                        child: Center(
                                                          child: Text(
                                                            '19',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 32,
                                                              color: textColor,
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
                                            Expanded(
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
                                                    decoration: BoxDecoration(
                                                      color: getColor(
                                                          176, 180, 25),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: Card(
                                                      color: Colors.white,
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          border: Border.all(
                                                            color: textColor,
                                                            width: 1,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 12),
                                                        child: Center(
                                                          child: Text(
                                                            '42',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 32,
                                                              color: textColor,
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
                                                    decoration: BoxDecoration(
                                                      color: getColor(4, 10, 5),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Card(
                                                      color: Colors.white,
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          border: Border.all(
                                                            color: textColor,
                                                            width: 1,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 12),
                                                        child: Center(
                                                          child: Text(
                                                            '4',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 32,
                                                              color: textColor,
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
                                ThroughputBarChart(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Second row with 1 card that fills all remaining space
                          Expanded(
                              child: HourlyYieldBarChart(
                            data: [
                              {'ok': 30, 'ng': 10},
                              {'ok': 40, 'ng': 5},
                              {'ok': 50, 'ng': 2},
                              {'ok': 28, 'ng': 6},
                              {'ok': 35, 'ng': 4},
                              {'ok': 38, 'ng': 1},
                              {'ok': 42, 'ng': 3},
                              {'ok': 33, 'ng': 7},
                            ],
                            hourLabels: [
                              '08:00',
                              '09:00',
                              '10:00',
                              '11:00',
                              '12:00',
                              '13:00',
                              '14:00',
                              '15:00',
                            ],
                          )),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
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
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            // Row titles
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Center(
                                                    child: Text(
                                                      'Yield media',
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
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  // Circle
                                                  Container(
                                                    width: circleSize,
                                                    height: circleSize,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          getColor(89, 100, 25),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),

                                                  const SizedBox(
                                                    width: 8,
                                                  ),

                                                  Expanded(
                                                    child: Card(
                                                      color: Colors.white,
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          border: Border.all(
                                                            color: textColor,
                                                            width: 1,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 12),
                                                        child: Center(
                                                          child: Text(
                                                            '89%',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 32,
                                                              color: textColor,
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
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  // Circle
                                                  Container(
                                                    width: circleSize,
                                                    height: circleSize,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          getColor(90, 90, 25),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),

                                                  const SizedBox(
                                                    width: 8,
                                                  ),
                                                  Expanded(
                                                    child: Card(
                                                      color: Colors.white,
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          border: Border.all(
                                                            color: textColor,
                                                            width: 1,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 12),
                                                        child: Center(
                                                          child: Text(
                                                            '90%',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 32,
                                                              color: textColor,
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
                                Expanded(
                                  flex: 3,
                                  child: YieldComparisonBarChart(
                                      data: yieldData, target: 90),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Second row with 1 card that fills all remaining space
                          YieldLineChart(
                            hourlyData: hourlyYieldData,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
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
                                  const TrafficLightWithBackground(),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Ultimi XXX Shift',
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
                              const EscalationButton(),
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
                  const Expanded(
                    flex: 3,
                    child: HeaderBox(
                      title: 'UPTIME/DOWNTIME Shift',
                      target: '',
                      icon: Icons.timer_outlined,
                    ),
                  ),

                  // RIGHT SIDE – Pareto + NG Card
                  Expanded(
                    flex: 3,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 65,
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            color: warningColor,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
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
                        ),
                        const Expanded(
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

              // ────── PLACEHOLDERS FOR SECOND ROW ──────
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 325,
                      margin: const EdgeInsets.only(right: 6, bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // LEFT COLUMN (2 stacked rows)
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                Expanded(
                                  child: Card(
                                    color: Colors.white,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'Available\nTime',
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
                                                      value: value,
                                                      radius: 100,
                                                      axis: GaugeAxis(
                                                        min: 0,
                                                        max: 100,
                                                        degrees: 180,
                                                        style:
                                                            const GaugeAxisStyle(
                                                          thickness: 16,
                                                          background:
                                                              Color(0xFFDDDDDD),
                                                          segmentSpacing: 0,
                                                        ),
                                                        progressBar:
                                                            GaugeRoundedProgressBar(
                                                          color: () {
                                                            if (value <= 50) {
                                                              return errorColor;
                                                            }
                                                            if (value <= 75) {
                                                              return warningColor;
                                                            }
                                                            return okColor;
                                                          }(),
                                                        ),
                                                      ),
                                                      builder: (context, child,
                                                          value) {
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
                                const TopDefectsPieChart(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    height: 275,
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
                                            1: FlexColumnWidth(2),
                                            2: FlexColumnWidth(2),
                                            3: FlexColumnWidth(2),
                                            4: FlexColumnWidth(2),
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
                                                  padding: EdgeInsets.all(8),
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
                                            ...buildCustomRows(),
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
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 325,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          // LEFT COLUMN (1 card)
                          Expanded(
                            flex: 3,
                            child: TopDefectsHorizontalBarChart(),
                          ),

                          const SizedBox(width: 8),

                          // RIGHT COLUMN (1 full-height card)
                          Expanded(
                            flex: 2,
                            child: VPFDefectsHorizontalBarChart(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
