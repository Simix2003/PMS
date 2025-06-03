import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'visual_widgets.dart';

/// ╔══════════════════════════════════════════════════════════════════╗
/// ║  VISUAL MANAGEMENT  –  LINE-OVERVIEW SINGLE-PAGE DASHBOARD       ║
/// ╚══════════════════════════════════════════════════════════════════╝
class VisualPage extends StatelessWidget {
  const VisualPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ────── FIRST HEADER ROW ──────
              Row(
                children: const [
                  Expanded(
                    flex: 3,
                    child: HeaderBox(
                      title: 'Produzione Shift',
                      target: '360',
                      icon: Icons.propane_outlined,
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

              // ────── PLACEHOLDERS FOR FIRST ROW ──────
              Row(
                children: [
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
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            // Row titles
                                            // Row titles (aligned with the two card columns)
                                            Row(
                                              children: [
                                                const SizedBox(
                                                  width: 70,
                                                ), // aligns with the AIN 1 / AIN 2 label
                                                Expanded(
                                                  child: Center(
                                                    child: Text(
                                                      'IN Good Shift',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Center(
                                                    child: Text(
                                                      'OUT NG Shift',
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
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: Card(
                                                      color: Colors.green,
                                                      child: Center(
                                                        child: Text(
                                                          '176',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 32,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Card(
                                                      color: Colors.amber,
                                                      child: Center(
                                                        child: Text(
                                                          '19',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 32,
                                                            color: Colors.white,
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
                                                  Expanded(
                                                    child: Card(
                                                      color: Colors.red,
                                                      child: Center(
                                                        child: Text(
                                                          '42',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 32,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Card(
                                                      color: Colors.red,
                                                      child: Center(
                                                        child: Text(
                                                          '4',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 32,
                                                            color: Colors.white,
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
                                  child: Card(
                                    child: Center(child: Text('Throughput')),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Second row with 1 card that fills all remaining space
                          Expanded(
                            child: Card(
                              child: Center(child: Text('Throughput cumulato')),
                            ),
                          ),
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
                                                        fontSize: 24,
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
                                                  Expanded(
                                                    child: Card(
                                                      color: Colors.amber,
                                                      child: Center(
                                                        child: Text(
                                                          '89%',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 32,
                                                            color: Colors.white,
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
                                                  Expanded(
                                                    child: Card(
                                                      color: Colors.green,
                                                      child: Center(
                                                        child: Text(
                                                          '90%',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 32,
                                                            color: Colors.white,
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
                                  child: Card(
                                    child: Center(child: Text('Yield')),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Second row with 1 card that fills all remaining space
                          Expanded(
                            child: Card(
                              child:
                                  Center(child: Text('Yield Oraria Cumulata')),
                            ),
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
                          // Traffic light
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const TrafficLightWithBackground(),
                            ],
                          ),
                          Spacer(),

                          // Legend
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LegendRow(
                                  color: Colors.red,
                                  role: 'Head of production',
                                  time: '> 4h'),
                              SizedBox(height: 8),
                              LegendRow(
                                  color: Colors.amber,
                                  role: 'Shift Manager',
                                  time: '2h < x < 4h'),
                              SizedBox(height: 8),
                              LegendRow(
                                  color: Colors.green,
                                  role: 'Area Head',
                                  time: '< 2h'),
                            ],
                          ),
                          SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ────── SECOND HEADER ROW ──────
              Row(
                children: const [
                  Expanded(
                    flex: 3,
                    child: HeaderBox(
                      title: 'UPTIME/DOWNTIME Shift',
                      target: '',
                      icon: Icons.timelapse_outlined,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: HeaderBox(
                      title: 'Pareto Shift',
                      target: '',
                      icon: Icons.bar_chart_rounded,
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
                            flex: 1,
                            child: Column(
                              children: [
                                Expanded(
                                  child: Card(
                                    color: Colors.green.shade100,
                                    child:
                                        Center(child: Text("Available Time")),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Card(
                                    color: Colors.red.shade100,
                                    child: Center(
                                        child:
                                            Text("Top 5 Difetti QG2 - Shift")),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // RIGHT COLUMN (1 full-height card)
                          Expanded(
                            flex: 1,
                            child: Card(
                              color: Colors.blue.shade100,
                              child: Center(child: Text("Uptime % Chart")),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // LEFT COLUMN (1 card)
                          Expanded(
                            flex: 3,
                            child: Expanded(
                              child: Card(
                                color: Colors.green.shade100,
                                child: Center(
                                    child: Text("Top 5 Difetti QG2 - Shift")),
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // RIGHT COLUMN (1 full-height card)
                          Expanded(
                            flex: 2,
                            child: Card(
                              color: Colors.blue.shade100,
                              child: Center(
                                  child: Text(
                                      "Difetti Visti alla VPF - WiP - Shift")),
                            ),
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
