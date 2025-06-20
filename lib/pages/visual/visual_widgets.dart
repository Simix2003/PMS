// ignore_for_file: deprecated_member_use, use_build_context_synchronously, non_constant_identifier_names, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class HeaderBox extends StatefulWidget {
  final String title, target;
  final IconData icon;
  final String qg2_defects_value;

  const HeaderBox({
    super.key,
    required this.title,
    required this.target,
    required this.icon,
    this.qg2_defects_value = '',
  });

  @override
  _HeaderBoxState createState() => _HeaderBoxState();
}

class _HeaderBoxState extends State<HeaderBox> {
  late Timer _timer;
  late DateTime _currentTime;
  Color textColor = Colors.white;
  Color errorColor = Colors.amber.shade700;
  Color redColor = Colors.red;
  Color warningColor = Colors.yellow.shade400;
  Color okColor = Colors.green.shade400;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('dd/MM/yyyy').format(_currentTime);
    String formattedTime = DateFormat('HH:mm').format(_currentTime);

    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(33, 95, 154, 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // LEFT: Date/Time only for Produzione Shift
          if (widget.title == 'UPTIME/DOWNTIME Shift')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formattedDate,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  formattedTime,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ],
            )
          else if (widget.title == 'Produzione Shift')
            Image.asset(
              'logo.png',
              height: 36,
              fit: BoxFit.contain,
            )
          else if (widget.title == 'Pareto Shift')
            Row(
              children: [
                Text(
                  "Difetti \nTot. QG2",
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                SizedBox(
                  height: 50,
                  width: 75,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    color: warningColor,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(
                      // 👈 Center content both vertically & horizontally
                      child: Text(
                        widget.qg2_defects_value.toString(),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                )
              ],
            )
          else
            const SizedBox(width: 0), // occupy no space if not Produzione Shift

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.title != 'UPTIME/DOWNTIME Shift')
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                  ),
                )
              else ...[
                const SizedBox(width: 12),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 32),
                    children: [
                      const TextSpan(
                        text: 'UP',
                        style: TextStyle(
                            color: Color.fromRGBO(229, 217, 57, 1),
                            fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text: 'TIME/',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text: 'DOWN',
                        style: TextStyle(
                            color: Color.fromRGBO(229, 217, 57, 1),
                            fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text: 'TIME Shift',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(width: 8),
              if (widget.target.isNotEmpty)
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 32),
                    children: [
                      const TextSpan(
                        text: '(target: ',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: widget.target,
                        style: const TextStyle(
                          color: Color.fromRGBO(229, 217, 57, 1),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(
                        text: ')',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // RIGHT: Icon
          Icon(
            widget.icon,
            color: Colors.white,
            size: 50,
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
  final int shiftManagerCount;
  final int headOfProductionCount;
  final int closedCount;

  const TrafficLightWithBackground({
    super.key,
    required this.shiftManagerCount,
    required this.headOfProductionCount,
    required this.closedCount,
  });

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
            child: TrafficLightCircle(
                color: Colors.amber.shade700,
                label: headOfProductionCount.toString()),
          ),
          Positioned(
            top: 75,
            child: TrafficLightCircle(
                color: Colors.yellow, label: shiftManagerCount.toString()),
          ),
          Positioned(
            top: 130,
            child: TrafficLightCircle(
                color: Colors.green, label: closedCount.toString()),
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

List<TableRow> buildCustomRows(List<List<String>> data) {
  return data.map((row) {
    return TableRow(
      decoration: const BoxDecoration(color: Colors.white),
      children: row.map((cell) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Text(
              cell,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.start,
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
                              if (ok <= 0) {
                                return const SizedBox(); // Skip if ok == 0
                              }

                              final barCenterX = (2 * index + 1) * groupSpace;
                              final okHeight = chartHeight * (ok / maxY);
                              final topOffset = chartHeight - okHeight;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 8),
                const Text(
                  'Yield per Turno',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  'Target: $target%',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
                        if (item['bussing1'] == null ||
                            item['bussing2'] == null) {
                          return BarChartGroupData(
                            showingTooltipIndicators: [0, 1],
                            x: index,
                            barRods: [
                              BarChartRodData(
                                fromY: 0,
                                toY: 0,
                                width: 40,
                                color: Colors.blue.shade900,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                fromY: 0,
                                toY: 0,
                                width: 40,
                                color: Colors.lightBlue.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                            barsSpace: 6,
                          );
                        } else {
                          return BarChartGroupData(
                            showingTooltipIndicators: [0, 1],
                            x: index,
                            barRods: [
                              BarChartRodData(
                                fromY: 0,
                                toY: item['bussing1'],
                                width: 40,
                                color: Colors.blue.shade900,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                fromY: 0,
                                toY: item['bussing2'],
                                width: 40,
                                color: Colors.lightBlue.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                            barsSpace: 6,
                          );
                        }
                      }),
                      extraLinesData: ExtraLinesData(horizontalLines: [
                        HorizontalLine(
                          y: target,
                          color: Colors.orange,
                          strokeWidth: 2,
                          dashArray: [8, 4],
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
                LegendItem(color: Colors.blue.shade900, label: 'AIN 1'),
                LegendItem(color: Colors.lightBlue.shade200, label: 'AIN 2'),
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

    final line1 = LineChartBarData(
      isCurved: false,
      show: true,
      spots: List.generate(
        hourlyData1.length,
        (i) => FlSpot(i.toDouble(), (hourlyData1[i]['yield'] ?? 0).toDouble()),
      ),
      color: Colors.blue.shade900,
      barWidth: 2,
      dotData: FlDotData(show: true),
    );

    final line2 = LineChartBarData(
      isCurved: false,
      spots: List.generate(
        hourlyData2.length,
        (i) => FlSpot(i.toDouble(), (hourlyData2[i]['yield'] ?? 0).toDouble()),
      ),
      color: Colors.lightBlue.shade200,
      barWidth: 2,
      dotData: FlDotData(show: false),
    );

    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(width: 8),
                  const Text(
                    'Yield Oraria Cumulata',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    'Target: $target%',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 140,
                    lineTouchData: LineTouchData(
                      enabled: true,
                      handleBuiltInTouches: false,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) =>
                            Colors.transparent, // transparent background
                        tooltipRoundedRadius: 0, // no border radius (optional)
                        tooltipPadding: EdgeInsets.zero,
                        tooltipMargin: 8,
                        getTooltipItems: (spots) {
                          return spots.map((spot) {
                            if (spot.barIndex == 2) {
                              // Skip the target line
                              return null;
                            }

                            Color color;
                            switch (spot.barIndex) {
                              case 0:
                                color = Colors.blue.shade900;
                                break;
                              case 1:
                                color = Colors.lightBlue.shade200;
                                break;
                              default:
                                color = Colors.black;
                            }

                            return LineTooltipItem(
                              '${spot.y.toInt()}%',
                              TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
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
                    showingTooltipIndicators: [
                      ...List.generate(length, (index) {
                        return ShowingTooltipIndicators([
                          LineBarSpot(
                            line1,
                            0,
                            FlSpot(
                              index.toDouble(),
                              (hourlyData1[index]['yield'] ?? 0).toDouble(),
                            ),
                          ),
                          LineBarSpot(
                            line2,
                            1,
                            FlSpot(
                              index.toDouble(),
                              (hourlyData2[index]['yield'] ?? 0).toDouble(),
                            ),
                          ),
                        ]);
                      }),
                    ],
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: false,
                        spots: List.generate(
                          hourlyData1.length,
                          (i) => FlSpot(i.toDouble(),
                              (hourlyData1[i]['yield'] ?? 0).toDouble()),
                        ),
                        color: Colors.blue.shade900,
                        barWidth: 2,
                        dotData: FlDotData(show: true),
                      ),
                      LineChartBarData(
                        isCurved: false,
                        show: true,
                        spots: List.generate(
                          hourlyData2.length,
                          (i) => FlSpot(i.toDouble(),
                              (hourlyData2[i]['yield'] ?? 0).toDouble()),
                        ),
                        color: Colors.lightBlue.shade200,
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
              /*Wrap(
                alignment: WrapAlignment.center,
                spacing: 20,
                children: [
                  LegendItem(color: Colors.blue.shade900, label: 'AIN 1'),
                  LegendItem(color: Colors.lightBlue.shade200, label: 'AIN 2'),
                  LegendItem(
                      color: Colors.orange, label: 'Target', isDashed: true),
                ],
              ),*/
            ],
          ),
        ),
      ),
    );
  }
}

class TopDefectsHorizontalBarChart extends StatelessWidget {
  final List<String> defectLabels;
  final List<int> ain1Counts;
  final List<int> ain2Counts;

  const TopDefectsHorizontalBarChart({
    super.key,
    required this.defectLabels,
    required this.ain1Counts,
    required this.ain2Counts,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 10,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ Title
            const Text(
              "Top 5 Difetti QG2",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // ✅ Legends
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                LegendItem(color: Colors.blue.shade900, label: 'AIN 1'),
                const SizedBox(width: 20),
                LegendItem(color: Colors.lightBlue, label: 'AIN 2'),
              ],
            ),
            const SizedBox(height: 12),

            // ✅ Chart
            Expanded(
              child: Stack(
                children: [
                  RotatedBox(
                    quarterTurns: 1,
                    child: BarChart(
                      BarChartData(
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) =>
                                Colors.transparent, // transparent bg
                            rotateAngle: -90, // rotate tooltip content
                            tooltipPadding: EdgeInsets.zero, // no extra padding
                            tooltipMargin: 8, // close to bar
                            tooltipRoundedRadius: 0, // square box
                            tooltipBorder: BorderSide.none, // no border
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${rod.toY.toInt()}',
                                TextStyle(
                                  color: rod.color, // same as bar color
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              );
                            },
                          ),
                        ),
                        maxY: 20,
                        alignment: BarChartAlignment.spaceBetween,
                        barGroups: List.generate(defectLabels.length, (index) {
                          final ain1 = ain1Counts[index].toDouble();
                          final ain2 = ain2Counts[index].toDouble();
                          return BarChartGroupData(
                            showingTooltipIndicators: [0, 1],
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: ain1,
                                width: 16,
                                color: Colors.blue.shade900,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                toY: ain2,
                                width: 16,
                                color: Colors.lightBlue.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                            barsSpace: 1,
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
                              reservedSize: 100,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VPFDefectsHorizontalBarChart extends StatelessWidget {
  final List<String> defectLabels;
  final List<int> ain1Counts;
  final List<int> ain2Counts;

  const VPFDefectsHorizontalBarChart({
    super.key,
    required this.defectLabels,
    required this.ain1Counts,
    required this.ain2Counts,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 10,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ Title
            const Text(
              "Difetti VPF riconducibili ad AIN",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // ✅ Legends
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                LegendItem(color: Colors.blue.shade900, label: 'AIN 1'),
                const SizedBox(width: 20),
                LegendItem(color: Colors.lightBlue, label: 'AIN 2'),
              ],
            ),
            const SizedBox(height: 12),

            // ✅ Chart
            Expanded(
              child: Stack(
                children: [
                  RotatedBox(
                    quarterTurns: 1,
                    child: BarChart(
                      BarChartData(
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) =>
                                Colors.transparent, // transparent bg
                            rotateAngle: -90, // rotate tooltip content
                            tooltipPadding: EdgeInsets.zero, // no extra padding
                            tooltipMargin: 8, // close to bar
                            tooltipRoundedRadius: 0, // square box
                            tooltipBorder: BorderSide.none, // no border
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${rod.toY.toInt()}',
                                TextStyle(
                                  color: rod.color, // same as bar color
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              );
                            },
                          ),
                        ),
                        maxY: 20,
                        alignment: BarChartAlignment.spaceBetween,
                        barGroups: List.generate(defectLabels.length, (index) {
                          final ain1 = ain1Counts[index].toDouble();
                          final ain2 = ain2Counts[index].toDouble();
                          return BarChartGroupData(
                            showingTooltipIndicators: [0, 1],
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: ain1,
                                width: 16,
                                color: Colors.blue.shade900,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                toY: ain2,
                                width: 16,
                                color: Colors.lightBlue.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                            barsSpace: 1,
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
                              reservedSize: 100,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
