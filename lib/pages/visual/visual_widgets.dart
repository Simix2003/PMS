// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../shared/services/api_service.dart';
import '../../shared/widgets/AI.dart';

class HeaderBox extends StatelessWidget {
  final String title, target;
  final IconData icon;

  const HeaderBox(
      {super.key,
      required this.title,
      required this.target,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          const BoxConstraints(minHeight: 50), // Adjust height as needed
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(33, 95, 154, 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != 'UPTIME/DOWNTIME Shift')
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                  ),
                )
              else
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 32),
                    children: [
                      TextSpan(
                        text: 'UP',
                        style: const TextStyle(
                          color: Color.fromRGBO(229, 217, 57, 1),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(
                        text: 'TIME/',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: 'DOWN',
                        style: const TextStyle(
                          color: Color.fromRGBO(229, 217, 57, 1),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(
                        text: 'TIME Shift',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(width: 8),
              if (target.isNotEmpty)
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 32),
                    children: [
                      const TextSpan(
                        text: '(target: ',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: target,
                        style: const TextStyle(
                          color: Color.fromRGBO(229, 217, 57, 1),
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                        ),
                      ),
                      const TextSpan(
                        text: ')',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Positioned(
            right: 0,
            child: Icon(
              icon,
              color: Colors.white,
              size: 50,
            ),
          ),
        ],
      ),
    );
  }
}

class TrafficLightCircle extends StatelessWidget {
  final Color color;
  final String label;

  const TrafficLightCircle({
    super.key,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class TrafficLightWithBackground extends StatelessWidget {
  const TrafficLightWithBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: 2,
            child: Image.asset(
              'assets/images/traffic_light.png',
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: 20,
            child: TrafficLightCircle(color: Colors.amber.shade700, label: '2'),
          ),
          Positioned(
            top: 75,
            child: TrafficLightCircle(color: Colors.yellow, label: '1'),
          ),
          Positioned(
            top: 130,
            child: TrafficLightCircle(color: Colors.green, label: '5'),
          ),
        ],
      ),
    );
  }
}

class LegendRow extends StatelessWidget {
  final Color color;
  final String role;
  final String time;

  const LegendRow({
    super.key,
    required this.color,
    required this.role,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Colored role cell
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.black),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              role,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (time.isNotEmpty)
          // Time cell
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                time,
                style: const TextStyle(fontSize: 24, color: Colors.black),
              ),
            ),
          ),
      ],
    );
  }
}

class TopDefectsPieChart extends StatelessWidget {
  const TopDefectsPieChart({super.key});

  @override
  Widget build(BuildContext context) {
    final data = _getData(); // so we use it for both chart and legend

    return Expanded(
      child: Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Legend
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: data.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: e['color'] as Color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          e['label'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 12),

              // Pie Chart
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 15,
                    sections: _generateSections(data),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getData() {
    return [
      {'label': 'Mancata Saldatura', 'value': 49.0, 'color': Colors.purple},
      {'label': 'Mancato Carico', 'value': 32.0, 'color': Colors.red},
      {
        'label': 'Driver Bruciato',
        'value': 10.0,
        'color': Colors.amber.shade700
      },
    ];
  }

  List<PieChartSectionData> _generateSections(List<Map<String, dynamic>> data) {
    return data
        .map(
          (e) => PieChartSectionData(
            value: e['value'] as double,
            color: e['color'] as Color,
            title: '${e['value']}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        )
        .toList();
  }
}

List<TableRow> buildCustomRows() {
  final sampleData = [
    ["Mancato Carico", "AIN1", "3", "126"],
    ["Mancata Saldatura", "AIN2", "1", "294"],
    ["Driver Bruciato", "AIN1", "1", "180"]
  ];

  return sampleData.map((row) {
    return TableRow(
      decoration: const BoxDecoration(color: Colors.white),
      children: row.map((cell) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Text(
              cell,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }).toList(),
    );
  }).toList();
}

class ThroughputBarChart extends StatelessWidget {
  final List<Map<String, int>> data;
  final List<String> labels;
  final double globalTarget;

  const ThroughputBarChart({
    super.key,
    required this.data,
    required this.labels,
    this.globalTarget = 360,
  });

  double _calculateSmartMaxY(int maxTotal, bool showTarget) {
    if (!showTarget) {
      // Scale based only on max bar height
      return maxTotal + (maxTotal * 0.1).clamp(20, 100);
    }

    // If target is shown, ensure it's included in maxY
    final base = globalTarget > maxTotal ? globalTarget : maxTotal.toDouble();
    final padding = (base * 0.1).clamp(20, 100);
    return base + padding;
  }

  @override
  Widget build(BuildContext context) {
    final maxTotal =
        data.map((e) => e['ok']! + e['ng']!).reduce((a, b) => a > b ? a : b);
    final bool showTarget = maxTotal >= globalTarget * 0.5;
    final double maxY = _calculateSmartMaxY(maxTotal, showTarget);

    return Expanded(
      flex: 2,
      child: Card(
        color: Colors.white,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Throughput',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Show global target
                  Spacer(),
                  Text(
                    'Target: ${globalTarget.toInt()}',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Stack(
                  children: [
                    BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Colors.transparent,
                            tooltipPadding: EdgeInsets.zero, // ← no padding
                            tooltipMargin: 0, // ← no margin
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final value = rod.toY.toString();
                              return BarTooltipItem(
                                value,
                                const TextStyle(
                                  color: Colors
                                      .black, // You can pick the color to match your bar
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < labels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      labels[index],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: _buildBarGroups(data),
                        extraLinesData: ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: globalTarget,
                              color: Colors.orangeAccent,
                              strokeWidth: 2,
                              dashArray: [6, 3],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 💬 OK count inside green
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final chartWidth = constraints.maxWidth;
                          final chartHeight = constraints.maxHeight;
                          final barCount = data.length;
                          final groupSpace = chartWidth / (barCount * 2);

                          return Stack(
                            children: List.generate(barCount, (index) {
                              final ok = data[index]['ok']!;
                              final barCenterX = (2 * index + 1) * groupSpace;
                              final okHeight = chartHeight * (ok / maxY);
                              final topOffset = chartHeight - okHeight - 40;

                              return Positioned(
                                left: barCenterX - 12,
                                top: topOffset,
                                child: Text(
                                  '$ok',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(List<Map<String, int>> data) {
    return List.generate(data.length, (index) {
      final ok = data[index]['ok']!;
      final ng = data[index]['ng']!;
      final total = ok + ng;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            color: Colors.transparent,
            fromY: 0,
            toY: total.toDouble(),
            width: 64,
            rodStackItems: [
              if (ok > 0) BarChartRodStackItem(0, ok.toDouble(), Colors.green),
              if (ng > 0)
                BarChartRodStackItem(
                    ok.toDouble(), (ok + ng).toDouble(), Colors.red),
            ],
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ],
        showingTooltipIndicators: [0, 1],
      );
    });
  }
}

class HourlyBarChart extends StatelessWidget {
  final List<Map<String, int>> data;
  final List<String> hourLabels;

  const HourlyBarChart({
    super.key,
    required this.data,
    required this.hourLabels,
  });

  double _calculateMaxY() {
    final totals = data.map((e) => e['ok']! + e['ng']!).toList();
    final maxData =
        totals.isNotEmpty ? totals.reduce((a, b) => a > b ? a : b) : 0;
    return maxData.toDouble() + 30; // Add some padding
  }

  List<BarChartGroupData> _buildBarGroups(double maxY) {
    return List.generate(data.length, (index) {
      final ok = data[index]['ok']!;
      final ng = data[index]['ng']!;
      final total = ok + ng;

      return BarChartGroupData(
        x: index,
        showingTooltipIndicators: [0, 1],
        barRods: [
          BarChartRodData(
            color: Colors.transparent,
            fromY: 0,
            toY: total.toDouble(),
            width: 28,
            rodStackItems: [
              if (ok > 0) BarChartRodStackItem(0, ok.toDouble(), Colors.green),
              if (ng > 0)
                BarChartRodStackItem(
                    ok.toDouble(), total.toDouble(), Colors.red),
            ],
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxY = _calculateMaxY();
    final double targetLine = 45;

    return Card(
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Throughput Cumulativo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Target: $targetLine',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Stack(
                children: [
                  BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => Colors.transparent,
                          tooltipPadding: EdgeInsets.zero, // ← no padding
                          tooltipMargin: 0, // ← no margin
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final value = rod.toY.toString();
                            return BarTooltipItem(
                              value,
                              const TextStyle(
                                color: Colors
                                    .black, // You can pick the color to match your bar
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i >= 0 && i < hourLabels.length) {
                                return Text(
                                  hourLabels[i],
                                  style: const TextStyle(fontSize: 16),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: _buildBarGroups(maxY),
                      extraLinesData: ExtraLinesData(horizontalLines: [
                        HorizontalLine(
                          y: targetLine,
                          color: Colors.orangeAccent,
                          strokeWidth: 2,
                          dashArray: [8, 4],
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDashed;

  const LegendItem({
    super.key,
    required this.color,
    required this.label,
    this.isDashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isDashed
            ? Container(
                width: 20,
                height: 4,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                        color: color, width: 2, style: BorderStyle.solid),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (_, __) => Row(
                    children: List.generate(4, (_) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 2),
                          color: color,
                          height: 2,
                        ),
                      );
                    }),
                  ),
                ),
              )
            : Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

// ───── Shift Order Helper ─────
List<Map<String, dynamic>> reorderShifts(
    List<Map<String, dynamic>> data, String currentShift) {
  final order = {
    'S1': ['S2', 'S3', 'S1'],
    'S2': ['S3', 'S1', 'S2'],
    'S3': ['S1', 'S2', 'S3'],
  }[currentShift];

  if (order == null) return data;

  return order
      .map((s) => data.firstWhere((d) => d['shift'] == s, orElse: () => {}))
      .where((d) => d.isNotEmpty)
      .toList();
}

// ───── Main Chart ─────
class YieldComparisonBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final double target;

  const YieldComparisonBarChart({
    super.key,
    required this.data,
    this.target = 90,
  });

  String _getCurrentShift() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 14) return 'S1';
    if (hour >= 14 && hour < 22) return 'S2';
    return 'S3';
  }

  @override
  Widget build(BuildContext context) {
    final currentShift = _getCurrentShift();
    final orderedData = reorderShifts(data, currentShift);

    return Card(
      color: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            const Text(
              'Yield per Turno',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: Stack(
                children: [
                  // 🔹 Chart
                  BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 100,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => Colors.transparent,
                          tooltipPadding: EdgeInsets.zero, // ← no padding
                          tooltipMargin: 0, // ← no margin
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final value = rod.toY.toString();
                            return BarTooltipItem(
                              '$value%',
                              const TextStyle(
                                color: Colors
                                    .black, // You can pick the color to match your bar
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              int i = value.toInt();
                              return Text(orderedData[i]['shift']);
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(orderedData.length, (index) {
                        final item = orderedData[index];
                        return BarChartGroupData(
                          showingTooltipIndicators: [0, 1],
                          x: index,
                          barRods: [
                            BarChartRodData(
                              fromY: 0,
                              toY: item['bussing1'].toDouble(),
                              width: 40,
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            BarChartRodData(
                              fromY: 0,
                              toY: item['bussing2'].toDouble(),
                              width: 40,
                              color: Colors.lightBlue.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                          barsSpace: 6,
                        );
                      }),
                      extraLinesData: ExtraLinesData(horizontalLines: [
                        HorizontalLine(
                          y: target,
                          color: Colors.orange,
                          strokeWidth: 2,
                          dashArray: [8, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            labelResolver: (line) => '${target.toInt()}%',
                            alignment: Alignment.topRight,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              children: [
                LegendItem(color: Colors.blue, label: 'Bussing 1'),
                LegendItem(
                    color: Colors.lightBlue.shade300, label: 'Bussing 2'),
                LegendItem(
                    color: Colors.orange, label: 'Target', isDashed: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class YieldLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> hourlyData1;
  final List<Map<String, dynamic>> hourlyData2;
  final double target;

  const YieldLineChart({
    super.key,
    required this.hourlyData1,
    required this.hourlyData2,
    this.target = 90,
  });

  @override
  Widget build(BuildContext context) {
    final length = hourlyData1.length; // assume same length for both

    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              const Text(
                'Yield Oraria Cumulata',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 110,
                    lineTouchData: LineTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 &&
                                index < hourlyData1.length &&
                                value == index.toDouble()) {
                              return SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  hourlyData1[index]['hour'],
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: const Border(
                        left: BorderSide(),
                        bottom: BorderSide(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: false,
                        spots: List.generate(
                          hourlyData1.length,
                          (i) => FlSpot(i.toDouble(),
                              (hourlyData1[i]['yield'] ?? 0).toDouble()),
                        ),
                        color: Colors.blue,
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                      ),
                      LineChartBarData(
                        isCurved: false,
                        spots: List.generate(
                          hourlyData2.length,
                          (i) => FlSpot(i.toDouble(),
                              (hourlyData2[i]['yield'] ?? 0).toDouble()),
                        ),
                        color: Colors.lightBlue.shade300,
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                      ),
                      LineChartBarData(
                        spots: List.generate(
                          length,
                          (i) => FlSpot(i.toDouble(), target),
                        ),
                        color: Colors.orange,
                        isStrokeCapRound: true,
                        barWidth: 2,
                        isCurved: false,
                        dashArray: [6, 4],
                        dotData: FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 20,
                children: [
                  LegendItem(color: Colors.blue, label: 'Stazione 1'),
                  LegendItem(
                      color: Colors.lightBlue.shade300, label: 'Stazione 2'),
                  LegendItem(
                      color: Colors.orange, label: 'Target', isDashed: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TopDefectsHorizontalBarChart extends StatelessWidget {
  final List<String> defectLabels = [
    'NG Macchie ECA',
    'NG Saldatura',
    'NG Bad Soldering',
    'NG Mancanza l_Ribbon',
    'NG Celle Rotte',
  ];

  final List<int> ain1Counts = [17, 8, 9, 7, 3];
  final List<int> ain2Counts = [4, 5, 0, 1, 2];

  TopDefectsHorizontalBarChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 10,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: 1.4,
          child: Stack(
            children: [
              RotatedBox(
                quarterTurns: 1, // Rotate chart 90° clockwise
                child: BarChart(
                  BarChartData(
                    maxY: 20,
                    alignment: BarChartAlignment.center,
                    barGroups: List.generate(defectLabels.length, (index) {
                      final ain1 = ain1Counts[index].toDouble();
                      final ain2 = ain2Counts[index].toDouble();
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: ain1,
                            width: 12,
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          BarChartRodData(
                            toY: ain2,
                            width: 12,
                            color: Colors.lightBlue.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                        barsSpace: 6,
                      );
                    }),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 80,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < defectLabels.length) {
                              return RotatedBox(
                                quarterTurns: -1,
                                child: Text(
                                  defectLabels[i],
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),

              // ✅ Value labels
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final barHeight =
                          constraints.maxHeight / defectLabels.length;
                      return Column(
                        children: List.generate(defectLabels.length, (index) {
                          final ain1 = ain1Counts[index];
                          final ain2 = ain2Counts[index];
                          return SizedBox(
                            height: barHeight,
                            child: Row(
                              children: [
                                const Spacer(),
                                Text(
                                  '$ain1',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$ain2',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.lightBlue.shade300,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 20,
                children: [
                  LegendItem(color: Colors.blue, label: 'Bussing 1'),
                  LegendItem(
                      color: Colors.lightBlue.shade300, label: 'Bussing 2'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VPFDefectsHorizontalBarChart extends StatelessWidget {
  final List<String> defectLabels = [
    'NG Macchie ECA',
    'NG Saldatura',
    'NG Bad Soldering',
  ];

  final List<int> ain1Counts = [17, 8, 9];
  final List<int> ain2Counts = [4, 5, 0];

  VPFDefectsHorizontalBarChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 10,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            children: [
              RotatedBox(
                quarterTurns: 1, // Rotate chart 90° clockwise
                child: BarChart(
                  BarChartData(
                    maxY: 20,
                    alignment: BarChartAlignment.center,
                    barGroups: List.generate(defectLabels.length, (index) {
                      final ain1 = ain1Counts[index].toDouble();
                      final ain2 = ain2Counts[index].toDouble();
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: ain1,
                            width: 12,
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          BarChartRodData(
                            toY: ain2,
                            width: 12,
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                        barsSpace: 6,
                      );
                    }),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 80,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < defectLabels.length) {
                              return RotatedBox(
                                quarterTurns: -1,
                                child: Text(
                                  defectLabels[i],
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),

              // ✅ Value labels
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final barHeight =
                          constraints.maxHeight / defectLabels.length;
                      return Column(
                        children: List.generate(defectLabels.length, (index) {
                          final ain1 = ain1Counts[index];
                          final ain2 = ain2Counts[index];
                          return SizedBox(
                            height: barHeight,
                            child: Row(
                              children: [
                                const Spacer(),
                                Text(
                                  '$ain1',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$ain2',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 20,
                children: const [
                  LegendItem(color: Colors.purple, label: 'M308'),
                  LegendItem(color: Colors.grey, label: 'M309'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EscalationButton extends StatelessWidget {
  const EscalationButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.withOpacity(0.85),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 10,
      ),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => const EscalationDialog(),
        );
      },
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
      label: const Text(
        'Escalation',
        style: TextStyle(
            fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}

class EscalationDialog extends StatefulWidget {
  const EscalationDialog({super.key});

  @override
  State<EscalationDialog> createState() => _EscalationDialogState();
}

class _EscalationDialogState extends State<EscalationDialog> {
  String selectedStatus = 'Shift Manager';
  final TextEditingController reasonController = TextEditingController();
  int? selectedEscalationIndex;

  final List<Map<String, String>> mockEscalations = [
    {'title': '🟡 MIN01 - Piccolo Problema', 'status': 'Shift Manager'},
    {'title': '🔴 MIN02 - Blocco Bussing', 'status': 'Head of Production'},
  ];

  bool showClosed = false;

  void saveEscalation() async {
    if (selectedEscalationIndex != null) {
      // Edita status esistente
      setState(() {
        mockEscalations[selectedEscalationIndex!]['status'] = selectedStatus;
      });
      Navigator.pop(context);
    } else {
      final text = reasonController.text.trim();

      // Controllo testo vuoto
      if (text.isEmpty) return;

      // Check duplicato
      final exists = mockEscalations.any((e) => e['title']!.contains(text));
      String chosenText = text;

      if (!exists) {
        // Chiama l'AI
        final result = await ApiService.checkDefectSimilarity(text);

        if (result != null && result['suggested_defect'] != null) {
          final suggestion = result['suggested_defect']!;
          final confidence = result['confidence'];

          final useSuggestion = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => IAConfirmationDialog(
              original: text,
              suggestion: suggestion,
              confidence: confidence,
            ),
          );

          if (useSuggestion == true) {
            chosenText = suggestion;
          }
        }
      }

      setState(() {
        mockEscalations.add({
          'title': '🟠 NEW - $chosenText',
          'status': selectedStatus,
        });
        reasonController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      child: SizedBox(
        width: 1000,
        height: 700,
        child: Row(
          children: [
            Container(
              width: 220,
              color: Colors.grey[100],
              child: Column(
                children: [
                  // Scrollable escalation list
                  Expanded(
                    child: ListView.builder(
                      itemCount: mockEscalations.length + 1,
                      itemBuilder: (context, index) {
                        final isNewItem = index == mockEscalations.length;
                        final isSelected = isNewItem
                            ? selectedEscalationIndex == null
                            : selectedEscalationIndex == index;

                        final cardColor =
                            isSelected ? Colors.blue.shade50 : Colors.white;
                        final borderColor =
                            isSelected ? Colors.blue : Colors.grey.shade300;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 6.0),
                          child: Card(
                            color: cardColor,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: borderColor, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  if (isNewItem) {
                                    selectedEscalationIndex = null;
                                    reasonController.clear();
                                    selectedStatus = 'Shift Manager';
                                  } else {
                                    selectedEscalationIndex = index;
                                    selectedStatus =
                                        mockEscalations[index]['status']!;
                                    reasonController.clear();
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12.0, horizontal: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isNewItem
                                          ? Icons.add_circle_outline
                                          : Icons.bolt,
                                      color: isSelected
                                          ? Colors.blue
                                          : Colors.black54,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isNewItem
                                            ? 'Nuova Escalation'
                                            : mockEscalations[index]['title']!,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom "View Closed" button
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.history, color: Colors.white),
                      label: const Text(
                        'Visualizza Chiuse',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        setState(() {
                          showClosed = true;
                          selectedEscalationIndex = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Right Panel
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: showClosed
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Escalation Chiuse',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView(
                              children: mockEscalations
                                  .where((e) => e['status'] == 'Closed')
                                  .map((e) => Card(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: ListTile(
                                          leading: const Icon(
                                              Icons.check_circle,
                                              color: Colors.green),
                                          title: Text(e['title']!),
                                          subtitle: const Text("Stato: Closed"),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Torna'),
                              onPressed: () {
                                setState(() {
                                  showClosed = false;
                                });
                              },
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedEscalationIndex != null
                                ? 'Modifica Escalation'
                                : 'Crea Nuova Escalation',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),
                          if (selectedEscalationIndex == null)
                            TextField(
                              controller: reasonController,
                              decoration: const InputDecoration(
                                labelText: 'Motivo del blocco',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Stato Escalation',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Shift Manager',
                                  child: Text('Shift Manager')),
                              DropdownMenuItem(
                                  value: 'Head of Production',
                                  child: Text('Head of Production')),
                              DropdownMenuItem(
                                  value: 'Closed', child: Text('Closed')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => selectedStatus = val);
                              }
                            },
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                child: const Text('Annulla'),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: saveEscalation,
                                child: const Text('Salva'),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
