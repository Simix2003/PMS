// ignore_for_file: deprecated_member_use, use_build_context_synchronously, non_constant_identifier_names, library_private_types_in_public_api, prefer_typing_uninitialized_variables, camel_case_types
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../shared/services/api_service.dart';
import '../home_page/buffer_page.dart';

class HeaderBox extends StatefulWidget {
  final String title, target;
  final IconData? icon;
  final String qg2_defects_value;
  final String zone;
  final bool Title;

  const HeaderBox({
    super.key,
    required this.title,
    required this.target,
    this.icon,
    this.qg2_defects_value = '',
    this.zone = '',
    this.Title = false,
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
      constraints: const BoxConstraints(minHeight: 75),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: widget.Title ? warningColor : Color.fromRGBO(33, 95, 154, 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // LEFT: Date/Time only for Produzione Shift
          if (widget.title == 'UPTIME/DOWNTIME Shift')
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/logo.png',
                height: 36,
                fit: BoxFit.contain,
              ),
            ),
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
            ),
          if (widget.title == 'UPTIME/DOWNTIME Shift')
            const SizedBox(width: 32),
          if (widget.title == 'Dettaglio ReWork')
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/logo.png',
                height: 36,
                fit: BoxFit.contain,
              ),
            ),
          if (widget.title == 'Dettaglio ReWork')
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else if (widget.title == 'Pareto Shift')
            Row(
              children: [
                if (widget.zone == 'AIN')
                  Text(
                    "Difetti \nTot. QG2",
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                if (widget.zone == 'AIN')
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
                  ),
                if (widget.zone == 'ELL')
                  Text(
                    "Difetti \nTot.",
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                if (widget.zone == 'ELL')
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
                  ),
                if (widget.zone == 'STR')
                  Text(
                    "Difetti \nTot.",
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                if (widget.zone == 'STR')
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
                  ),
                if (widget.zone == 'VPF')
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
                  ),
              ],
            )
          else
            const SizedBox(width: 0), // occupy no space if not Produzione Shift

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.Title)
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color.fromRGBO(33, 95, 154, 1),
                  ),
                )
              else if (widget.title != 'UPTIME/DOWNTIME Shift' &&
                  widget.title != "Dettaglio ReWork")
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                  ),
                )
              else if (widget.title == 'UPTIME/DOWNTIME Shift') ...[
                const SizedBox(width: 12),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 32),
                    children: [
                      TextSpan(
                        text: 'UP',
                        style: TextStyle(
                            color: warningColor, fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text: 'TIME/',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'DOWN',
                        style: TextStyle(
                            color: warningColor, fontWeight: FontWeight.bold),
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
              ] else if (widget.title == 'Dettaglio ReWork') ...[
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 32),
                    children: [
                      const TextSpan(
                        text: 'Dettaglio ',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'ReWork',
                        style: TextStyle(
                            color: warningColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
              //const SizedBox(width: 8),
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
                        style: TextStyle(
                          color: warningColor,
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

          if (widget.icon != null)
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
        if (time.isNotEmpty) const SizedBox(width: 8),
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
          padding: const EdgeInsets.all(15),
          child: Center(
            child: Text(
              cell,
              style: const TextStyle(fontSize: 24),
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
      return maxTotal + (maxTotal * 0.1).clamp(20, 100);
    }
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
                    'Produzione',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
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
                            tooltipPadding: EdgeInsets.zero,
                            tooltipMargin: 0,
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final value = rod.toY.toString();
                              return BarTooltipItem(
                                value,
                                const TextStyle(
                                  color: Colors.black,
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
                                return const SizedBox();
                              }

                              final barCenterX = (2 * index + 1) * groupSpace;
                              final okHeight = chartHeight * (ok / maxY);

                              final topOfGreenBar = chartHeight - okHeight;

                              final topOffset = okHeight >= 40
                                  ? topOfGreenBar // inside the green bar
                                  : okHeight >= 20
                                      ? (topOfGreenBar - 16)
                                          .clamp(0.0, chartHeight - 16)
                                      : (topOfGreenBar - 32)
                                          .clamp(0.0, chartHeight - 32);

                              final text = '$ok';
                              final offset = text.length == 1
                                  ? 4
                                  : text.length == 2
                                      ? 8
                                      : 12;

                              return Positioned(
                                left: barCenterX - offset,
                                top: topOffset,
                                child: Text(
                                  text,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                          offset: Offset(0, 0),
                                          blurRadius: 2,
                                          color: Colors.black),
                                    ],
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

class ThroughputELLBarChart extends StatelessWidget {
  final List<Map<String, int>> data;
  final List<String> labels;
  final double globalTarget;

  const ThroughputELLBarChart({
    super.key,
    required this.data,
    required this.labels,
    this.globalTarget = 360,
  });

  double _calculateSmartMaxY(int maxTotal, bool showTarget) {
    if (!showTarget) {
      return maxTotal + (maxTotal * 0.1).clamp(20, 100);
    }
    final base = globalTarget > maxTotal ? globalTarget : maxTotal.toDouble();
    final padding = (base * 0.1).clamp(20, 100);
    return base + padding;
  }

  @override
  Widget build(BuildContext context) {
    final maxTotal = data
        .map((e) => e['ok']! + e['ng']! + e['scrap']!)
        .reduce((a, b) => a > b ? a : b);
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
                  const Spacer(),
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
                            tooltipPadding: EdgeInsets.zero,
                            tooltipMargin: 0,
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final value = rod.toY.toString();
                              return BarTooltipItem(
                                value,
                                const TextStyle(
                                  color: Colors.black,
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
                                return const SizedBox();
                              }

                              final barCenterX = (2 * index + 1) * groupSpace;
                              final okHeight = chartHeight * (ok / maxY);

                              final topOfGreenBar = chartHeight - okHeight;

                              final topOffset = okHeight >= 40
                                  ? topOfGreenBar // inside the green bar
                                  : okHeight >= 20
                                      ? (topOfGreenBar - 16)
                                          .clamp(0.0, chartHeight - 16)
                                      : (topOfGreenBar - 32)
                                          .clamp(0.0, chartHeight - 32);

                              final text = '$ok';
                              final offset = text.length == 1
                                  ? 4
                                  : text.length == 2
                                      ? 8
                                      : 12;

                              return Positioned(
                                left: barCenterX - offset,
                                top: topOffset,
                                child: Text(
                                  text,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                          offset: Offset(0, 0),
                                          blurRadius: 2,
                                          color: Colors.black),
                                    ],
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
              const SizedBox(height: 16),
              Wrap(
                spacing: 20,
                children: [
                  LegendItem(color: Colors.green, label: 'G'),
                  LegendItem(color: Colors.red, label: 'NG'),
                  LegendItem(color: Colors.black, label: 'Scrap'),
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

  List<BarChartGroupData> _buildBarGroups(List<Map<String, int>> data) {
    return List.generate(data.length, (index) {
      final ok = data[index]['ok']!;
      final ng = data[index]['ng']!;
      final scrap = data[index]['scrap']!;
      final total = ok + ng + scrap;

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
              if (scrap > 0)
                BarChartRodStackItem((ok + ng).toDouble(),
                    (ok + ng + scrap).toDouble(), Colors.black),
            ],
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ],
        showingTooltipIndicators: [0, 1],
      );
    });
  }
}

class ThroughputSTRBarChart extends StatelessWidget {
  final List<Map<String, int>> data;
  final List<String> labels;
  final double globalTarget;

  const ThroughputSTRBarChart({
    super.key,
    required this.data,
    required this.labels,
    this.globalTarget = 360,
  });

  double _calculateSmartMaxY(int maxTotal, bool showTarget) {
    if (!showTarget) {
      return maxTotal + (maxTotal * 0.1).clamp(20, 100);
    }
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
                    'Produzione',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
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
                            tooltipPadding: EdgeInsets.zero,
                            tooltipMargin: 0,
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final value = rod.toY.toString();
                              return BarTooltipItem(
                                value,
                                const TextStyle(
                                  color: Colors.black,
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
                                return const SizedBox();
                              }

                              final barCenterX = (2 * index + 1) * groupSpace;
                              final okHeight = chartHeight * (ok / maxY);

                              final topOfGreenBar = chartHeight - okHeight;

                              final topOffset = okHeight >= 40
                                  ? topOfGreenBar // inside the green bar
                                  : okHeight >= 20
                                      ? (topOfGreenBar - 16)
                                          .clamp(0.0, chartHeight - 16)
                                      : (topOfGreenBar - 32)
                                          .clamp(0.0, chartHeight - 32);

                              final text = '$ok';
                              final offset = text.length == 1
                                  ? 4
                                  : text.length == 2
                                      ? 8
                                      : 12;

                              return Positioned(
                                left: barCenterX - offset,
                                top: topOffset,
                                child: Text(
                                  text,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                          offset: Offset(0, 0),
                                          blurRadius: 2,
                                          color: Colors.black),
                                    ],
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
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 20,
                children: [
                  LegendItem(color: Colors.green, label: 'STR G'),
                  LegendItem(color: Colors.red, label: 'STR NG'),
                  //LegendItem(color: Colors.red, label: 'CELL SCRAP'),
                ],
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
  final double target;

  const HourlyBarChart({
    super.key,
    required this.data,
    required this.hourLabels,
    required this.target,
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

  List<Map<String, dynamic>> computeShiftBandsFromLabels(
      List<String> hourLabels) {
    List<Map<String, dynamic>> bands = [];
    int? startIdx;
    String? currentShift;

    String getShift(String hourStr) {
      final hour = int.parse(hourStr.split(':')[0]);
      if (hour >= 6 && hour < 14) return 'S1';
      if (hour >= 14 && hour < 22) return 'S2';
      return 'S3';
    }

    for (int i = 0; i < hourLabels.length; i++) {
      String shift = getShift(hourLabels[i]);
      if (shift != currentShift) {
        if (startIdx != null) {
          bands.add({'start': startIdx, 'end': i - 1, 'shift': currentShift});
        }
        startIdx = i;
        currentShift = shift;
      }
    }

    if (startIdx != null && currentShift != null) {
      bands.add({
        'start': startIdx,
        'end': hourLabels.length - 1,
        'shift': currentShift
      });
    }

    return bands;
  }

  String getCurrentShiftLabel() {
    final now = TimeOfDay.now();
    final hour = now.hour;
    if (hour >= 6 && hour < 14) return 'S1';
    if (hour >= 14 && hour < 22) return 'S2';
    return 'S3';
  }

  @override
  Widget build(BuildContext context) {
    final bands = computeShiftBandsFromLabels(hourLabels);
    final currentShift = getCurrentShiftLabel();

    final maxY = _calculateMaxY();

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
                    'Produzione Cumulativa',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Target: $target',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final barSpacing = constraints.maxWidth / hourLabels.length;

                  return Stack(
                    children: [
                      // SHIFT BACKGROUND BANDS
                      for (var band in bands)
                        Positioned(
                          left: band['start'] * barSpacing,
                          width: (band['end'] - band['start'] + 1) * barSpacing,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: band['shift'] == currentShift
                                  ? Colors.white.withOpacity(0.0)
                                  : Colors.grey.withOpacity(0.18),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                                bottom: Radius.circular(8),
                              ),
                            ),
                            alignment: Alignment.topLeft,
                            padding: const EdgeInsets.only(top: 4, left: 8),
                            child: Text(
                              switch (band['shift']) {
                                'S1' => 'Shift 1',
                                'S2' => 'Shift 2',
                                'S3' => 'Shift 3',
                                _ => '',
                              },
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),

                      // BAR CHART ON TOP
                      BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxY,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (_) => Colors.transparent,
                              tooltipPadding: EdgeInsets.zero,
                              tooltipMargin: 0,
                              fitInsideHorizontally: true,
                              fitInsideVertically: true,
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                final value = rod.toY.toString();
                                return BarTooltipItem(
                                  value,
                                  const TextStyle(
                                    color: Colors.black,
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
                              y: target,
                              color: Colors.orangeAccent,
                              strokeWidth: 2,
                              dashArray: [8, 4],
                            ),
                          ]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HourlyELLBarChart extends StatelessWidget {
  final List<Map<String, int>> data;
  final List<String> hourLabels;
  final double target;

  const HourlyELLBarChart({
    super.key,
    required this.data,
    required this.hourLabels,
    required this.target,
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

  List<Map<String, dynamic>> computeShiftBandsFromLabels(
      List<String> hourLabels) {
    List<Map<String, dynamic>> bands = [];
    int? startIdx;
    String? currentShift;

    String getShift(String hourStr) {
      final hour = int.parse(hourStr.split(':')[0]);
      if (hour >= 6 && hour < 14) return 'S1';
      if (hour >= 14 && hour < 22) return 'S2';
      return 'S3';
    }

    for (int i = 0; i < hourLabels.length; i++) {
      String shift = getShift(hourLabels[i]);
      if (shift != currentShift) {
        if (startIdx != null) {
          bands.add({'start': startIdx, 'end': i - 1, 'shift': currentShift});
        }
        startIdx = i;
        currentShift = shift;
      }
    }

    if (startIdx != null && currentShift != null) {
      bands.add({
        'start': startIdx,
        'end': hourLabels.length - 1,
        'shift': currentShift
      });
    }

    return bands;
  }

  String getCurrentShiftLabel() {
    final now = TimeOfDay.now();
    final hour = now.hour;
    if (hour >= 6 && hour < 14) return 'S1';
    if (hour >= 14 && hour < 22) return 'S2';
    return 'S3';
  }

  @override
  Widget build(BuildContext context) {
    final bands = computeShiftBandsFromLabels(hourLabels);
    final currentShift = getCurrentShiftLabel();

    final maxY = _calculateMaxY();

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
                  'Target: $target',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final barSpacing = constraints.maxWidth / hourLabels.length;

                  return Stack(
                    children: [
                      // SHIFT BACKGROUND BANDS
                      for (var band in bands)
                        Positioned(
                          left: band['start'] * barSpacing,
                          width: (band['end'] - band['start'] + 1) * barSpacing,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: band['shift'] == currentShift
                                  ? Colors.white.withOpacity(0.0)
                                  : Colors.grey.withOpacity(0.18),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                                bottom: Radius.circular(8),
                              ),
                            ),
                            alignment: Alignment.topLeft,
                            padding: const EdgeInsets.only(top: 4, left: 8),
                            child: Text(
                              switch (band['shift']) {
                                'S1' => 'Shift 1',
                                'S2' => 'Shift 2',
                                'S3' => 'Shift 3',
                                _ => '',
                              },
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),

                      // BAR CHART ON TOP
                      BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxY,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (_) => Colors.transparent,
                              tooltipPadding: EdgeInsets.zero,
                              tooltipMargin: 0,
                              fitInsideHorizontally: true,
                              fitInsideVertically: true,
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                final value = rod.toY.toString();
                                return BarTooltipItem(
                                  value,
                                  const TextStyle(
                                    color: Colors.black,
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
                              y: target,
                              color: Colors.orangeAccent,
                              strokeWidth: 2,
                              dashArray: [8, 4],
                            ),
                          ]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HourlySTRBarChart extends StatelessWidget {
  final List<Map<String, int>> data;
  final List<String> hourLabels;
  final double target;

  const HourlySTRBarChart({
    super.key,
    required this.data,
    required this.hourLabels,
    required this.target,
  });

  double _calculateMaxY() {
    final totals = data.map((e) => e['ok']! + e['ng']!).toList();
    final maxData =
        totals.isNotEmpty ? totals.reduce((a, b) => a > b ? a : b) : 0;
    return maxData.toDouble() + 10; // Reduced padding
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
            width: 16, // Smaller bar width
            rodStackItems: [
              if (ok > 0) BarChartRodStackItem(0, ok.toDouble(), Colors.green),
              if (ng > 0)
                BarChartRodStackItem(
                    ok.toDouble(), total.toDouble(), Colors.red),
            ],
            borderRadius: const BorderRadius.all(Radius.circular(3)),
          ),
        ],
      );
    });
  }

  List<Map<String, dynamic>> computeShiftBandsFromLabels(
      List<String> hourLabels) {
    List<Map<String, dynamic>> bands = [];
    int? startIdx;
    String? currentShift;

    String getShift(String hourStr) {
      final hour = int.parse(hourStr.split(':')[0]);
      if (hour >= 6 && hour < 14) return 'S1';
      if (hour >= 14 && hour < 22) return 'S2';
      return 'S3';
    }

    for (int i = 0; i < hourLabels.length; i++) {
      String shift = getShift(hourLabels[i]);
      if (shift != currentShift) {
        if (startIdx != null) {
          bands.add({'start': startIdx, 'end': i - 1, 'shift': currentShift});
        }
        startIdx = i;
        currentShift = shift;
      }
    }

    if (startIdx != null && currentShift != null) {
      bands.add({
        'start': startIdx,
        'end': hourLabels.length - 1,
        'shift': currentShift
      });
    }

    return bands;
  }

  String getCurrentShiftLabel() {
    final now = TimeOfDay.now();
    final hour = now.hour;
    if (hour >= 6 && hour < 14) return 'S1';
    if (hour >= 14 && hour < 22) return 'S2';
    return 'S3';
  }

  @override
  Widget build(BuildContext context) {
    final bands = computeShiftBandsFromLabels(hourLabels);
    final currentShift = getCurrentShiftLabel();
    final maxY = _calculateMaxY();

    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: SizedBox(
          height: 140, // 🔧 Adjust to fit your layout
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barSpacing = constraints.maxWidth / hourLabels.length;

              return Stack(
                children: [
                  for (var band in bands)
                    Positioned(
                      left: band['start'] * barSpacing,
                      width: (band['end'] - band['start'] + 1) * barSpacing,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: band['shift'] == currentShift
                              ? Colors.white.withOpacity(0.0)
                              : Colors.grey.withOpacity(0.15),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                            bottom: Radius.circular(4),
                          ),
                        ),
                        alignment: Alignment.topLeft,
                        padding: const EdgeInsets.only(top: 2, left: 4),
                        child: Text(
                          switch (band['shift']) {
                            'S1' => 'S1',
                            'S2' => 'S2',
                            'S3' => 'S3',
                            _ => '',
                          },
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black45,
                          ),
                        ),
                      ),
                    ),
                  BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => Colors.transparent,
                          tooltipPadding: EdgeInsets.zero,
                          tooltipMargin: 0,
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final value = rod.toY.toString();
                            return BarTooltipItem(
                              value,
                              const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
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
                                  style: const TextStyle(fontSize: 10),
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
                          y: target,
                          color: Colors.orangeAccent,
                          strokeWidth: 1.5,
                          dashArray: [6, 3],
                        ),
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDashed;
  final textSize;

  const LegendItem({
    super.key,
    required this.color,
    required this.label,
    this.isDashed = false,
    this.textSize = 14,
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
        Text(
          label,
          style: TextStyle(fontSize: textSize),
        ),
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
                  'Yield per Shift',
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
                          getTooltipColor: (_) => Colors.grey
                              .withOpacity(0.8), // 🔹 semi-transparent grey
                          tooltipPadding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          tooltipMargin: 6,
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final value = rod.toY.toStringAsFixed(0);

                            return BarTooltipItem(
                              '$value%',
                              const TextStyle(
                                color: Colors.white, // 🔸 white text
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

class YieldComparisonELLBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final double target;

  const YieldComparisonELLBarChart({
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
                  'Yield per Shift',
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
                          getTooltipColor: (_) => Colors.grey
                              .withOpacity(0.8), // 🔹 semi-transparent grey
                          tooltipPadding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          tooltipMargin: 6,
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final value = rod.toY.toStringAsFixed(0);

                            return BarTooltipItem(
                              '$value%',
                              const TextStyle(
                                color: Colors.white, // 🔸 white text
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
                        if (item['FPY'] == null || item['RWK'] == null) {
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
                                toY: (item['FPY'] as num).toDouble(),
                                width: 40,
                                color: Colors.blue.shade900,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                fromY: 0,
                                toY: (item['RWK'] as num).toDouble(),
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
                LegendItem(color: Colors.blue.shade900, label: 'FPY'),
                LegendItem(
                    color: Colors.lightBlue.shade200,
                    label: 'Yield con ReWork'),
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

class YieldComparisonSTRBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final double target;

  const YieldComparisonSTRBarChart({
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
                  'Yield per Shift',
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
                          getTooltipColor: (_) => Colors.grey
                              .withOpacity(0.8), // 🔹 semi-transparent grey
                          tooltipPadding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          tooltipMargin: 6,
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final value = rod.toY.toStringAsFixed(0);

                            return BarTooltipItem(
                              '$value%',
                              const TextStyle(
                                color: Colors.white, // 🔸 white text
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
                        if (item['STR_Yield'] == null ||
                            item['Overall_Yield'] == null) {
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
                                toY: item['STR_Yield'],
                                width: 40,
                                color: Colors.blue.shade900,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                fromY: 0,
                                toY: item['Overall_Yield'],
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
                LegendItem(color: Colors.blue.shade900, label: 'Yield STR'),
                LegendItem(
                    color: Colors.lightBlue.shade200, label: 'Yield Overall'),
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

class YieldBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final double target;

  const YieldBarChart({
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
    final adjustedData = data
        .map((d) => {
              ...d,
              'shift':
                  d['label'], // 👈 injects compatibility for reorderShifts()
            })
        .toList();

    final orderedData = reorderShifts(adjustedData, currentShift);

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
                  BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 100,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => Colors.grey.withOpacity(0.8),
                          tooltipPadding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          tooltipMargin: 6,
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final value = rod.toY.toStringAsFixed(0);
                            return BarTooltipItem(
                              '$value%',
                              const TextStyle(
                                color: Colors.white,
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
                              return Text(orderedData[i]['label']);
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
                          showingTooltipIndicators: [0],
                          x: index,
                          barRods: [
                            BarChartRodData(
                              fromY: 0,
                              toY: (item['yield'] ?? 0).toDouble(),
                              width: 40,
                              color: Colors.blue.shade900,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
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
                LegendItem(color: Colors.blue.shade900, label: 'Yield'),
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

class Yield2LineChart extends StatelessWidget {
  final List<Map<String, dynamic>> hourlyData1;
  final List<Map<String, dynamic>> hourlyData2;
  final double target;

  const Yield2LineChart({
    super.key,
    required this.hourlyData1,
    required this.hourlyData2,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final length = hourlyData1.length; // assume same length for both

    List<Map<String, dynamic>> computeShiftBands(
        List<Map<String, dynamic>> data) {
      List<Map<String, dynamic>> bands = [];
      int? startIdx;
      String? currentShift;

      String getShift(String hourStr) {
        final hour = int.parse(hourStr.split(':')[0]);
        if (hour >= 6 && hour < 14) return 'S1';
        if (hour >= 14 && hour < 22) return 'S2';
        return 'S3';
      }

      for (int i = 0; i < data.length; i++) {
        String shift = getShift(data[i]['hour']);
        if (shift != currentShift) {
          if (startIdx != null && currentShift != null) {
            bands.add({'start': startIdx, 'end': i - 1, 'shift': currentShift});
          }
          startIdx = i;
          currentShift = shift;
        }
      }

      if (startIdx != null && currentShift != null) {
        bands.add(
            {'start': startIdx, 'end': data.length - 1, 'shift': currentShift});
      }

      return bands;
    }

    String getCurrentShiftLabel() {
      final now = TimeOfDay.now();
      final hour = now.hour;
      if (hour >= 6 && hour < 14) return 'S1';
      if (hour >= 14 && hour < 22) return 'S2';
      return 'S3';
    }

    final currentShift = getCurrentShiftLabel();
    final shiftBands = computeShiftBands(hourlyData1); // based on data1 timing

    final shiftAnnotations = shiftBands.map((band) {
      final isCurrent = band['shift'] == currentShift;
      final color = isCurrent
          ? Colors.white.withOpacity(0.0) // transparent for current shift
          : Colors.grey.withOpacity(0.18); // light grey for others

      return VerticalRangeAnnotation(
        x1: band['start'].toDouble(),
        x2: band['end'].toDouble() + 1,
        color: color,
      );
    }).toList();

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
                    rangeAnnotations: RangeAnnotations(
                      verticalRangeAnnotations: shiftAnnotations,
                    ),
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

class YieldLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> hourlyData1;
  final double target;

  const YieldLineChart({
    super.key,
    required this.hourlyData1,
    required this.target,
  });

  List<Map<String, dynamic>> computeShiftBands(
      List<Map<String, dynamic>> data) {
    List<Map<String, dynamic>> bands = [];
    int? startIdx;
    String? currentShift;

    String getShift(String hourStr) {
      final hour = int.parse(hourStr.split(':')[0]);
      if (hour >= 6 && hour < 14) return 'S1';
      if (hour >= 14 && hour < 22) return 'S2';
      return 'S3';
    }

    for (int i = 0; i < data.length; i++) {
      String shift = getShift(data[i]['hour']);
      if (shift != currentShift) {
        if (startIdx != null && currentShift != null) {
          bands.add({
            'start': startIdx,
            'end': i - 1,
            'shift': currentShift,
          });
        }
        startIdx = i;
        currentShift = shift;
      }
    }

    if (startIdx != null && currentShift != null) {
      bands.add({
        'start': startIdx,
        'end': data.length - 1,
        'shift': currentShift,
      });
    }

    return bands;
  }

  @override
  Widget build(BuildContext context) {
    final int length = hourlyData1.length;

    String getCurrentShiftLabel() {
      final now = TimeOfDay.now();
      final hour = now.hour;
      if (hour >= 6 && hour < 14) return 'S1';
      if (hour >= 14 && hour < 22) return 'S2';
      return 'S3';
    }

    final currentShift = getCurrentShiftLabel();
    final shiftBands = computeShiftBands(hourlyData1);

    final shiftAnnotations = shiftBands.map((band) {
      final isCurrent = band['shift'] == currentShift;
      final color = isCurrent
          ? Colors.white.withOpacity(0.0) // no overlay = white background
          : Colors.grey.withOpacity(0.15); // light grey overlay

      return VerticalRangeAnnotation(
        x1: band['start'].toDouble(),
        x2: band['end'].toDouble() + 1,
        color: color,
      );
    }).toList();

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

    final targetLine = LineChartBarData(
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
                    style: const TextStyle(
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
                    rangeAnnotations: RangeAnnotations(
                      verticalRangeAnnotations: shiftAnnotations,
                    ),
                    lineTouchData: LineTouchData(
                      enabled: true,
                      handleBuiltInTouches: false,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => Colors.transparent,
                        tooltipRoundedRadius: 0,
                        tooltipPadding: EdgeInsets.zero,
                        tooltipMargin: 8,
                        getTooltipItems: (spots) {
                          return spots.map((spot) {
                            if (spot.barIndex == 1) {
                              return null; // skip target line
                            }
                            return LineTooltipItem(
                              '${spot.y.toInt()}%',
                              TextStyle(
                                color: Colors.blue.shade900,
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
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
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
                    showingTooltipIndicators: List.generate(length, (index) {
                      return ShowingTooltipIndicators([
                        LineBarSpot(
                          line1,
                          0,
                          FlSpot(
                            index.toDouble(),
                            (hourlyData1[index]['yield'] ?? 0).toDouble(),
                          ),
                        ),
                      ]);
                    }),
                    lineBarsData: [
                      line1, // barIndex 0
                      targetLine, // barIndex 1
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class YieldELLLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> hourlyData_FPY;
  final List<Map<String, dynamic>> hourlyData_RWK;
  final double target;

  const YieldELLLineChart({
    super.key,
    required this.hourlyData_FPY,
    required this.hourlyData_RWK,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final length = hourlyData_FPY.length; // assume same length for both

    List<Map<String, dynamic>> computeShiftBands(
        List<Map<String, dynamic>> data) {
      List<Map<String, dynamic>> bands = [];
      int? startIdx;
      String? currentShift;

      String getShift(String hourStr) {
        final hour = int.parse(hourStr.split(':')[0]);
        if (hour >= 6 && hour < 14) return 'S1';
        if (hour >= 14 && hour < 22) return 'S2';
        return 'S3';
      }

      for (int i = 0; i < data.length; i++) {
        String shift = getShift(data[i]['hour']);
        if (shift != currentShift) {
          if (startIdx != null && currentShift != null) {
            bands.add({'start': startIdx, 'end': i - 1, 'shift': currentShift});
          }
          startIdx = i;
          currentShift = shift;
        }
      }

      if (startIdx != null && currentShift != null) {
        bands.add(
            {'start': startIdx, 'end': data.length - 1, 'shift': currentShift});
      }

      return bands;
    }

    String getCurrentShiftLabel() {
      final now = TimeOfDay.now();
      final hour = now.hour;
      if (hour >= 6 && hour < 14) return 'S1';
      if (hour >= 14 && hour < 22) return 'S2';
      return 'S3';
    }

    final currentShift = getCurrentShiftLabel();
    final shiftBands =
        computeShiftBands(hourlyData_FPY); // based on data1 timing

    final shiftAnnotations = shiftBands.map((band) {
      final isCurrent = band['shift'] == currentShift;
      final color = isCurrent
          ? Colors.white.withOpacity(0.0) // transparent for current shift
          : Colors.grey.withOpacity(0.18); // light grey for others

      return VerticalRangeAnnotation(
        x1: band['start'].toDouble(),
        x2: band['end'].toDouble() + 1,
        color: color,
      );
    }).toList();

    final line1 = LineChartBarData(
      isCurved: false,
      show: true,
      spots: List.generate(
        hourlyData_FPY.length,
        (i) =>
            FlSpot(i.toDouble(), (hourlyData_FPY[i]['yield'] ?? 0).toDouble()),
      ),
      color: Colors.blue.shade900,
      barWidth: 2,
      dotData: FlDotData(show: true),
    );

    final line2 = LineChartBarData(
      isCurved: false,
      spots: List.generate(
        hourlyData_RWK.length,
        (i) =>
            FlSpot(i.toDouble(), (hourlyData_RWK[i]['yield'] ?? 0).toDouble()),
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
                    rangeAnnotations: RangeAnnotations(
                      verticalRangeAnnotations: shiftAnnotations,
                    ),
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
                                index < hourlyData_FPY.length &&
                                value == index.toDouble()) {
                              return SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  hourlyData_FPY[index]['hour'],
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
                              (hourlyData_FPY[index]['yield'] ?? 0).toDouble(),
                            ),
                          ),
                          LineBarSpot(
                            line2,
                            1,
                            FlSpot(
                              index.toDouble(),
                              (hourlyData_RWK[index]['yield'] ?? 0).toDouble(),
                            ),
                          ),
                        ]);
                      }),
                    ],
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: false,
                        spots: List.generate(
                          hourlyData_FPY.length,
                          (i) => FlSpot(i.toDouble(),
                              (hourlyData_FPY[i]['yield'] ?? 0).toDouble()),
                        ),
                        color: Colors.blue.shade900,
                        barWidth: 2,
                        dotData: FlDotData(show: true),
                      ),
                      LineChartBarData(
                        isCurved: false,
                        show: true,
                        spots: List.generate(
                          hourlyData_RWK.length,
                          (i) => FlSpot(i.toDouble(),
                              (hourlyData_RWK[i]['yield'] ?? 0).toDouble()),
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

class TopDefectsRMIHorizontalBarChart extends StatelessWidget {
  final List<String> defectLabels;
  final List<int> min1Counts;
  final List<int> min2Counts;
  final List<int> ellCounts;

  const TopDefectsRMIHorizontalBarChart({
    super.key,
    required this.defectLabels,
    required this.min1Counts,
    required this.min2Counts,
    required this.ellCounts,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 10,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ Title
            const Text(
              "Difetti RMI",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // ✅ Legends
            Wrap(
              spacing: 20,
              children: [
                LegendItem(color: Colors.blue.shade900, label: 'MIN01'),
                LegendItem(color: Colors.lightBlue, label: 'MIN02'),
                LegendItem(color: Colors.orange, label: 'ELL'),
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
                          final min1 = min1Counts[index].toDouble();
                          final min2 = min2Counts[index].toDouble();
                          final ell = ellCounts[index].toDouble();
                          return BarChartGroupData(
                            showingTooltipIndicators: [0, 1, 2],
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: min1,
                                width: 10,
                                color: Colors.blue.shade900,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                toY: min2,
                                width: 10,
                                color: Colors.lightBlue.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                toY: ell,
                                width: 10,
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                            barsSpace: 2,
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

class TopDefectsHorizontalBarChartSTR extends StatelessWidget {
  final List<String> defectLabels;
  final List<int> Counts;

  const TopDefectsHorizontalBarChartSTR({
    super.key,
    required this.defectLabels,
    required this.Counts,
  });

  @override
  Widget build(BuildContext context) {
    // Dynamic maxY (fallback to 10 if empty)
    final double ymax = Counts.isEmpty
        ? 10
        : (Counts.reduce(max).toDouble() * 1.2); // +20% headroom

    return Card(
      elevation: 10,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Top 5 Difetti QG2 Shift",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RotatedBox(
                quarterTurns: 1,
                child: BarChart(
                  BarChartData(
                    maxY: ymax,
                    alignment: BarChartAlignment.spaceBetween,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Colors.transparent,
                        rotateAngle: -90,
                        tooltipPadding: EdgeInsets.zero,
                        tooltipMargin: 8,
                        tooltipRoundedRadius: 0,
                        tooltipBorder: BorderSide.none,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.toInt()}',
                            TextStyle(
                              color: rod.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          );
                        },
                      ),
                    ),
                    barGroups: List.generate(defectLabels.length, (index) {
                      final counts = index < Counts.length
                          ? Counts[index].toDouble()
                          : 0.0;
                      return BarChartGroupData(
                        showingTooltipIndicators: [0],
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: counts,
                            width: 16,
                            color: Colors.blue.shade900,
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

class VPFDefectsHorizontalBarChartSTR extends StatelessWidget {
  final List<String> defectLabels;
  final List<int> Counts;

  const VPFDefectsHorizontalBarChartSTR({
    super.key,
    required this.defectLabels,
    required this.Counts,
  });

  @override
  Widget build(BuildContext context) {
    final double ymax = Counts.isEmpty
        ? 10
        : (Counts.reduce(max).toDouble() * 1.2); // +20% headroom

    return Card(
      elevation: 10,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Top 5 Difetti VPF Shift",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RotatedBox(
                quarterTurns: 1,
                child: BarChart(
                  BarChartData(
                    maxY: ymax,
                    alignment: BarChartAlignment.spaceBetween,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Colors.transparent,
                        rotateAngle: -90,
                        tooltipPadding: EdgeInsets.zero,
                        tooltipMargin: 8,
                        tooltipRoundedRadius: 0,
                        tooltipBorder: BorderSide.none,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.toInt()}',
                            TextStyle(
                              color: rod.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          );
                        },
                      ),
                    ),
                    barGroups: List.generate(defectLabels.length, (index) {
                      final counts = index < Counts.length
                          ? Counts[index].toDouble()
                          : 0.0;
                      return BarChartGroupData(
                        showingTooltipIndicators: [0],
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: counts,
                            width: 16,
                            color: Colors.blue.shade900,
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
            ),
          ],
        ),
      ),
    );
  }
}

class BufferChart extends StatefulWidget {
  final List<Map<String, dynamic>> bufferDefectSummary;

  const BufferChart(this.bufferDefectSummary, {super.key});

  @override
  State<BufferChart> createState() => _BufferChartState();
}

class _BufferChartState extends State<BufferChart> {
  final ScrollController _scrollController = ScrollController();
  Map<String, String> etaByObjectId = {};
  Set<String> loadingETAs = {};

  @override
  void didUpdateWidget(covariant BufferChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    for (final item in widget.bufferDefectSummary) {
      final objectId = item['object_id']?.toString();
      if (objectId != null &&
          !etaByObjectId.containsKey(objectId) &&
          !loadingETAs.contains(objectId)) {
        loadingETAs.add(objectId);
        _fetchEtaForObject(objectId);
      }
    }
  }

  Future<void> _fetchEtaForObject(String objectId) async {
    final result = await ApiService.predictReworkETAByObject(objectId);
    if (!mounted) return;

    final etaMin = result['etaInfo']?['eta_min'];
    final etaString = etaMin != null ? "${etaMin.round()} min" : "N/A";

    setState(() {
      etaByObjectId[objectId] = etaString;
    });
  }

  List<Map<String, dynamic>> get defects {
    return widget.bufferDefectSummary.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;

      final objectId = data['object_id']?.toString() ?? 'N/A';
      final eta = etaByObjectId[objectId] ?? "⏳...";
      final rawDefects = data['defects'];

      List<Map<String, dynamic>> defectsList = [];
      if (rawDefects is List) {
        defectsList = rawDefects.whereType<Map<String, dynamic>>().toList();
      }

      final rework = data['rework_count'] ?? 0;

      final defectTypes = defectsList
          .map((d) => d['defect_type']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      return {
        "id": index + 1,
        "name": objectId,
        "eta": eta,
        "rework": rework,
        "defectTypes": defectTypes,
      };
    }).toList();
  }

  Color _etaColor(String eta) {
    final min = int.tryParse(eta.replaceAll('min', '').trim());
    if (min == null) return Colors.grey.shade500;
    if (min < 5) return Colors.green;
    if (min < 15) return Colors.orange;
    return Colors.red;
  }

  void _showExpandedDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.grey.shade100,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.85,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: 56,
                    color: Colors.grey.shade200,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Buffer Difetti",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  // Page content
                  Expanded(
                    child: BufferPageContent(
                        plcIp: '192.168.32.2',
                        db: 19603,
                        byte: 0,
                        length: 21,
                        visuals: true),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String get totalEtaSummary {
    final etaValues = etaByObjectId.values
        .map((e) => int.tryParse(e.replaceAll('min', '').trim()))
        .whereType<int>()
        .toList();

    if (etaValues.isEmpty) return "ETA: ⏳...";

    final totalMin = etaValues.fold(0, (sum, e) => sum + e);
    return "ETA: $totalMin min";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: 400, // 🔧 Make this height fixed or dynamic if needed
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        "Buffer RMI01",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        totalEtaSummary,
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_full),
                    onPressed: _showExpandedDialog,
                    tooltip: "Espandi",
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                // ✅ FIX: this makes ListView take only remaining space
                child: defects.isEmpty
                    ? const Center(child: Text("Nessun modulo in buffer"))
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: defects.length,
                        itemBuilder: (context, index) {
                          final defect = defects.reversed.toList()[index];
                          final bgColor = index.isEven
                              ? Colors.grey.shade100
                              : Colors.grey.shade200;

                          return Container(
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(6),
                            child: _DefectCard(
                              number: defect["id"],
                              name: defect["name"],
                              eta: defect["eta"],
                              etaColor: _etaColor(defect["eta"]),
                              rework: defect["rework"],
                              defectTypes: defect["defectTypes"],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefectCard extends StatelessWidget {
  final int number;
  final String name;
  final String eta;
  final Color etaColor;
  final int rework;
  final List<String> defectTypes;

  const _DefectCard({
    required this.number,
    required this.name,
    required this.eta,
    required this.etaColor,
    required this.rework,
    required this.defectTypes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "#$number",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: etaColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "ETA: $eta",
                  style: TextStyle(
                    fontSize: 12,
                    color: etaColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.autorenew, size: 16),
              const SizedBox(width: 6),
              Text("x$rework"),
              const SizedBox(width: 10),
              if (defectTypes.isNotEmpty)
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: defectTypes
                        .map(
                          (type) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              type,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class SpeedBar extends StatefulWidget {
  const SpeedBar({
    super.key,
    required this.medianSec,
    required this.currentSec,
    this.maxSec = 120,
    this.barHeight = 64,
    this.textColor = Colors.black,
    this.bgColor = Colors.grey,
    this.tickStep = 10,
  });

  final double medianSec;
  final double currentSec;
  final double maxSec;
  final double barHeight;
  final Color textColor;
  final Color bgColor;
  final double tickStep;

  @override
  State<SpeedBar> createState() => _SpeedBarState();
}

class _SpeedBarState extends State<SpeedBar> {
  @override
  Widget build(BuildContext context) {
    final medianAlignX =
        ((widget.medianSec / widget.maxSec).clamp(0, 1) * 2 - 1).toDouble();
    final currentAlignX =
        ((widget.currentSec / widget.maxSec).clamp(0, 1) * 2 - 1).toDouble();

    return Column(
      children: [
        SizedBox(
          height: widget.barHeight + 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Background bar ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: widget.barHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.yellow,
                        Colors.green,
                        Colors.yellow,
                        Colors.red
                      ],
                      stops: [0, 0.3, 0.5, 0.7, 1],
                    ),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                ),
              ),

              // ── Median line ──
              if (widget.medianSec > 0)
                Align(
                  alignment: Alignment(medianAlignX, 1),
                  child: Container(
                    width: 2,
                    height: widget.barHeight,
                    color: Colors.black,
                  ),
                ),

              // ── Animated Arrow ──
              if (widget.currentSec > 0)
                AnimatedAlign(
                  alignment: Alignment(currentAlignX, 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  child: Transform.translate(
                    offset: const Offset(0, -5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: const [
                            Icon(Icons.arrow_drop_down,
                                size: 85, color: Colors.white),
                            Icon(Icons.arrow_drop_down,
                                size: 80, color: Color(0xFF215F9A)),
                          ],
                        ),
                        Text(
                          '${widget.currentSec.round()} sec',
                          style:
                              TextStyle(fontSize: 12, color: widget.textColor),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Axis labels ──
        SizedBox(
          width: double.infinity,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('0 sec', style: TextStyle(color: widget.textColor)),
              ),
              if (widget.medianSec > 0)
                Align(
                  alignment: Alignment(medianAlignX, 0),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      'Tempo medio: ${widget.medianSec.round()} sec',
                      style: TextStyle(color: widget.textColor),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: Text('${widget.maxSec.round()} sec',
                    style: TextStyle(color: widget.textColor)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DefectBarChartCard extends StatelessWidget {
  final List<Map<String, dynamic>> defects;

  const DefectBarChartCard({super.key, required this.defects});

  static const Map<String, String> defectDescriptions = {
    "NG1": "Cella rotta o scheggiata a V",
    "NG1.1": "Cella rotta in prossimità JBX",
    "NG2": "Macchie ECA / AG Paste",
    "NG2.1": "Materiale estraneo sulla cella o matrice di celle",
    "NG3": "Disallineamento celle/stringhe o materiale estraneo",
    "NG3.1": "Deviazione ribbon rispetto al busbar",
    "NG4": "Rottura o disallineamenti su glass",
    "NG5": "Graffi o sporco su glass",
    "NG 7": "Bolle lungo i bordi o nei fori JB",
    "NG7.1": "Delaminazioni o bolle nella matrice",
    "NG8": "Difetti JBX (silicone, cavi danneggiati)",
    "NG8.1": "Difetti potting: bolle/mancanza",
    "NG9": "Difetti su Power Label",
    "NG10": "Difetti su telaio",
  };

  List<Map<String, dynamic>> normalizeDefects(List<Map<String, dynamic>> raw) {
    final Map<String, int> inputMap = {
      for (var item in raw) item['label']: item['count'],
    };

    return defectDescriptions.keys.map((code) {
      return {
        'label': code,
        'count': inputMap[code] ?? 0,
      };
    }).toList();
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeDefects(defects);
    final colors = List<Color>.generate(
      normalized.length,
      (i) => Colors.primaries[i % Colors.primaries.length],
    );
    final maxY = normalized
            .map((d) => d['count'] as int)
            .fold(0, (a, b) => a > b ? a : b)
            .toDouble() +
        1;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Left side: Title + BarChart
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Difetti VPF ( R = 0 )',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        barGroups: List.generate(normalized.length, (i) {
                          final count =
                              (normalized[i]['count'] as int).toDouble();
                          return BarChartGroupData(
                            x: i,
                            barsSpace: 1,
                            barRods: [
                              BarChartRodData(
                                toY: count,
                                color: colors[i],
                                width: 18,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                            showingTooltipIndicators: [0],
                          );
                        }),
                        maxY: maxY,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Colors.transparent,
                            tooltipRoundedRadius: 6,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final code = normalized[group.x.toInt()]['label'];
                              final count =
                                  normalized[group.x.toInt()]['count'];
                              return BarTooltipItem(
                                '$code\n$count',
                                const TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 24),

            /// Right side: Legend aligned with top
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(normalized.length, (i) {
                  final code = normalized[i]['label'];
                  final description = defectDescriptions[code] ?? code;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: LegendItem(
                      color: colors[i],
                      label: '$code - ${_truncate(description, 40)}',
                      textSize: 12,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StackedDefectBarCard extends StatelessWidget {
  final List<Map<String, dynamic>> defects;

  const StackedDefectBarCard({super.key, required this.defects});

  static const Map<String, String> defectDescriptions = {
    "NG1": "Cella rotta o scheggiata a V",
    "NG1.1": "Cella rotta in prossimità JBX",
    "NG2": "Macchie ECA / AG Paste",
    "NG2.1": "Materiale estraneo sulla cella o matrice di celle",
    "NG3": "Disallineamento celle/stringhe o materiale estraneo",
    "NG3.1": "Deviazione ribbon rispetto al busbar",
    "NG4": "Rottura o disallineamenti su glass",
    "NG5": "Graffi o sporco su glass",
    "NG 7": "Bolle lungo i bordi o nei fori JB",
    "NG7.1": "Delaminazioni o bolle nella matrice",
    "NG8": "Difetti JBX (silicone, cavi danneggiati)",
    "NG8.1": "Difetti potting: bolle/mancanza",
    "NG9": "Difetti su Power Label",
    "NG10": "Difetti su telaio",
  };

  List<Map<String, dynamic>> normalizeAndFilter(
      List<Map<String, dynamic>> raw) {
    final inputMap = {for (var item in raw) item['label']: item['count'] ?? 0};

    final result = defectDescriptions.keys
        .map((code) => {
              'label': code,
              'count': inputMap[code] ?? 0,
              'index': defectDescriptions.keys.toList().indexOf(code),
            })
        .where((e) => e['count']! > 0)
        .toList();

    result.sort((a, b) =>
        (a['count'] as int).compareTo(b['count'] as int)); // ascending

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeAndFilter(defects);
    final total =
        normalized.fold<int>(0, (sum, e) => sum + (e['count'] as int));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: Colors.white,
      child: SizedBox(
        height: 240,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Difetti VPF ( R = 0 )',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Show either chart or fallback text
              Expanded(
                child: total == 0
                    ? Center(
                        child: Text(
                          'Nessun difetto rilevato',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 150,
                          child: Column(
                            children: normalized.map((defect) {
                              final label = defect['label'] as String;
                              final count = defect['count'] as int;
                              final index = defect['index'] as int;
                              final fraction = count / total;
                              final color = Colors
                                  .primaries[index % Colors.primaries.length];

                              return Expanded(
                                flex: count,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 2),
                                  color: color,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$label: $count, ${(fraction * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DefectMatrixCard extends StatelessWidget {
  final Map<String, Map<String, int>> defectStationCountMap;

  const DefectMatrixCard({
    super.key,
    required this.defectStationCountMap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 4, left: 8, top: 4),
              child: Text(
                'EQ di provenienza per difetto',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio:
                  3.2, // <-- Increase aspect ratio makes cards shorter
              children: defectStationCountMap.entries.map((entry) {
                final defect = entry.key;
                final counts = entry.value;

                if (defect == 'NG1.1' || defect == 'NG3') {
                  final rowStations = [
                    'AIN01',
                    'AIN02',
                    'LMN01',
                    'LMN02'
                  ]; // + LMN if needed
                  final allValuesAreZero = counts.values.every((v) => v == 0);

                  if (allValuesAreZero) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.blueGrey[50],
                        border: Border.all(color: Colors.black),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            defect,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          const Text('Nessun dato',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.blueGrey[50],
                      border: Border.all(color: Colors.black),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          defect,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Table(
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.top,
                          columnWidths: const {
                            0: FixedColumnWidth(100),
                            1: FixedColumnWidth(50),
                            2: FixedColumnWidth(50),
                          },
                          children: [
                            TableRow(
                              children: [
                                const SizedBox(),
                                const Center(
                                  child: Text('RMI01',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                const Center(
                                  child: Text('RWS01',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            TableRow(
                              children: [
                                Padding(
                                  // ⬅️ Add padding to give slight space
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: rowStations.map((name) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 1), // ⬅️ reduce from 2
                                        child: Text(
                                            '$name: ${counts[name] ?? 0}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                Center(
                                  child: Text(
                                    '${counts['RMI01'] ?? 0}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Center(
                                  child: Text(
                                    '${counts['RWS01'] ?? 0}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                // Default rendering for other defects
                final sortedStations = counts.entries
                    .where((e) => e.value > 0)
                    .toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                final stationWidgets = sortedStations.map((e) {
                  return RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 11, color: Colors.black),
                      children: [
                        TextSpan(
                            text: '${e.key}: ',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(
                          text: '${e.value}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }).toList();

                final stationChunks = <List<Widget>>[[], []];
                for (int i = 0; i < stationWidgets.length; i++) {
                  stationChunks[i % 2].add(stationWidgets[i]);
                }

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.blueGrey[50],
                    border: Border.all(color: Colors.black),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        defect,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      sortedStations.isEmpty
                          ? const Text('Nessun dato',
                              style: TextStyle(fontSize: 12))
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: Column(children: stationChunks[0])),
                                const SizedBox(width: 4),
                                Expanded(
                                    child: Column(children: stationChunks[1])),
                              ],
                            ),
                    ],
                  ),
                );
              }).toList(),
            )
          ],
        ),
      ),
    );
  }
}

class ReWorkSpeedBar extends StatefulWidget {
  const ReWorkSpeedBar({
    super.key,
    required this.medianSec,
    required this.currentSec,
    required this.maxSec,
    this.barHeight = 40,
    this.textColor = Colors.black,
    this.bgColor = Colors.grey,
    this.tickStep = 10,
  });

  final double medianSec; // still in seconds
  final double currentSec; // still in seconds
  final double maxSec; // still in seconds
  final double barHeight;
  final Color textColor;
  final Color bgColor;
  final double tickStep;

  @override
  State<ReWorkSpeedBar> createState() => _ReWorkSpeedBarState();
}

class _ReWorkSpeedBarState extends State<ReWorkSpeedBar> {
  @override
  Widget build(BuildContext context) {
    // still use seconds for alignment logic
    final medianAlignX =
        ((widget.medianSec / widget.maxSec).clamp(0, 1) * 2 - 1).toDouble();
    final currentAlignX =
        ((widget.currentSec / widget.maxSec).clamp(0, 1) * 2 - 1).toDouble();

    // convert to minutes for display
    final medianMin = widget.medianSec / 60;
    final currentMin = widget.currentSec / 60;
    final maxMin = widget.maxSec / 60;

    return Column(
      children: [
        SizedBox(
          height: widget.barHeight + 43,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Background bar ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: widget.barHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.yellow,
                        Colors.green,
                        Colors.yellow,
                        Colors.red
                      ],
                      stops: [0, 0.3, 0.5, 0.7, 1],
                    ),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                ),
              ),

              // ── Median line ──
              if (widget.medianSec > 0)
                Align(
                  alignment: Alignment(medianAlignX, 1),
                  child: Container(
                    width: 2,
                    height: widget.barHeight,
                    color: Colors.black,
                  ),
                ),

              // ── Animated Arrow ──
              if (widget.currentSec > 0)
                AnimatedAlign(
                  alignment: Alignment(currentAlignX, 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  child: Transform.translate(
                    offset: const Offset(0, -5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: const [
                            Icon(Icons.arrow_drop_down,
                                size: 65, color: Colors.white),
                            Icon(Icons.arrow_drop_down,
                                size: 60, color: Color(0xFF215F9A)),
                          ],
                        ),
                        Text(
                          '${currentMin.toStringAsFixed(1)} min',
                          style:
                              TextStyle(fontSize: 12, color: widget.textColor),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Axis labels ──
        SizedBox(
          width: double.infinity,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('0 min', style: TextStyle(color: widget.textColor)),
              ),
              if (widget.medianSec > 0)
                Align(
                  alignment: Alignment(medianAlignX, 0),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      'Tempo medio: ${medianMin.toStringAsFixed(1)} min',
                      style: TextStyle(color: widget.textColor),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: Text('${maxMin.toStringAsFixed(1)} min',
                    style: TextStyle(color: widget.textColor)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
