import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// ╔══════════════════════════════════════════════════════════════════╗
/// ║  VISUAL MANAGEMENT  –  LINE-OVERVIEW SINGLE-PAGE DASHBOARD       ║
/// ╚══════════════════════════════════════════════════════════════════╝
class VisualPage extends StatelessWidget {
  const VisualPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // ─────────── TOP HEADERS (blue) ───────────
              Row(
                children: const [
                  _HeaderBox(
                    title: 'Produzione Shift',
                    subtitle: 'target 360',
                    icon: Icons.factory,
                  ),
                  _HeaderBox(
                    title: 'YIELD',
                    subtitle: 'target 90%',
                    icon: Icons.show_chart,
                  ),
                  _HeaderBox(
                    title: 'ESCALATION',
                    subtitle: '',
                    icon: Icons.warning_amber,
                    rightIcon: Icons.escalator_warning,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ─────────── FIRST GRID ROW (left, middle, right) ───────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ◀ LEFT COLUMN  (AIN 1 / 2 metrics + Throughput cards)
                  Expanded(
                    child: Column(
                      children: const [
                        _LineMetricCard(
                          lineName: 'AIN 1',
                          colorDot: Colors.amber,
                          good: 176,
                          ng: 19,
                        ),
                        SizedBox(height: 10),
                        _LineMetricCard(
                          lineName: 'AIN 2',
                          colorDot: Colors.red,
                          good: 42,
                          ng: 4,
                        ),
                        SizedBox(height: 12),
                        _ChartCard(
                          title: 'Throughput',
                          child: _ThroughputBar(),
                        ),
                        SizedBox(height: 12),
                        _ChartCard(
                          title: 'Throughput cumulato',
                          child: _CumLineChart(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ◀ MIDDLE COLUMN (Yield metrics + charts)
                  Expanded(
                    child: Column(
                      children: const [
                        _YieldMetricCard(colorDot: Colors.amber, value: 89),
                        SizedBox(height: 10),
                        _YieldMetricCard(colorDot: Colors.green, value: 90),
                        SizedBox(height: 12),
                        _ChartCard(title: 'Yield', child: _YieldShiftBar()),
                        SizedBox(height: 12),
                        _ChartCard(
                          title: 'Yield oraria cumulata',
                          child: _YieldLineChart(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ◀ RIGHT COLUMN (Escalation traffic light + table)
                  Expanded(
                    child: Column(
                      children: const [
                        _TrafficLight(),
                        SizedBox(height: 12),
                        _EscalationTable(),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ─────────── SECOND ROW – UPTIME / DOWNTIME & PARETO ───────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ◀ LEFT  –  UPTIME / DOWNTIME SHIFT
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: const [
                        _SectionTitle('UPTIME /DOWNTIME Shift',
                            icon: Icons.timer),
                        SizedBox(height: 8),
                        _GaugeCard(),
                        SizedBox(height: 8),
                        _DowntimeTable(),
                        SizedBox(height: 8),
                        _PieTop5(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ◀ RIGHT –  PARETO SHIFT
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: const [
                        _SectionTitle('Pareto Shift', icon: Icons.bar_chart),
                        SizedBox(height: 8),
                        _TotalNgBadge(total: 56),
                        SizedBox(height: 8),
                        _ParetoBar(),
                      ],
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

//////////////////////////////////////////////////////////////////////
/// WIDGETS – High-level “lego bricks” used in the layout         ///
/// (Only minimal styling & demo data – replace with real data)    ///
//////////////////////////////////////////////////////////////////////

// ────────── BLUE TOP-STRIP BOX ──────────
class _HeaderBox extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final IconData? rightIcon;
  const _HeaderBox(
      {required this.title,
      required this.subtitle,
      required this.icon,
      this.rightIcon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0054A6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
            if (rightIcon != null) ...[
              const Spacer(),
              Icon(rightIcon, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}

// ────────── SECTION TITLE (blue strip) ──────────
class _SectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionTitle(this.text, {required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0054A6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ────────── SMALL STAT CARDS (AIN 1/2) ──────────
class _LineMetricCard extends StatelessWidget {
  final String lineName;
  final Color colorDot;
  final int good, ng;
  const _LineMetricCard(
      {required this.lineName,
      required this.colorDot,
      required this.good,
      required this.ng});

  @override
  Widget build(BuildContext context) {
    const txtStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
    final boxDecoration = BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(10),
      color: Colors.white,
    );

    Widget metricBox(String label, int value) => Container(
          width: 90,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: boxDecoration,
          child: Column(
            children: [
              Text('$value', style: txtStyle),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
        );

    return Row(
      children: [
        CircleAvatar(radius: 8, backgroundColor: colorDot),
        const SizedBox(width: 6),
        Text(lineName, style: const TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        metricBox('IN Good', good),
        const SizedBox(width: 8),
        metricBox('Out NG', ng),
      ],
    );
  }
}

// ────────── YIELD METRIC CARDS ──────────
class _YieldMetricCard extends StatelessWidget {
  final Color colorDot;
  final int value;
  const _YieldMetricCard({required this.colorDot, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 8, backgroundColor: colorDot),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Text('$value%',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }
}

// ────────── WRAPPER FOR CHARTS ──────────
class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      height: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ────────── TRAFFIC LIGHT WIDGET ──────────
class _TrafficLight extends StatelessWidget {
  const _TrafficLight();

  @override
  Widget build(BuildContext context) {
    Widget lamp(Color color, int num) => Column(
          children: [
            CircleAvatar(radius: 18, backgroundColor: color),
            const SizedBox(height: 4),
            Text('$num',
                style: const TextStyle(fontSize: 11, color: Colors.black)),
          ],
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          lamp(Colors.red, 2),
          const SizedBox(height: 6),
          lamp(Colors.amber, 1),
          const SizedBox(height: 6),
          lamp(Colors.green, 5),
        ],
      ),
    );
  }
}

// ────────── ESCALATION THRESHOLD TABLE ──────────
class _EscalationTable extends StatelessWidget {
  const _EscalationTable();

  @override
  Widget build(BuildContext context) {
    TableRow row(String role, String threshold, Color color) => TableRow(
          decoration: BoxDecoration(color: color),
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(role,
                  style: const TextStyle(fontSize: 11, color: Colors.black)),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(threshold,
                  style: const TextStyle(fontSize: 11, color: Colors.black)),
            ),
          ],
        );

    return Table(
      border: TableBorder.all(color: Colors.black26),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        row('Area Head', '< 2h', Colors.lightGreen),
        row('Shift Manager', '2h<<4h', Colors.yellow),
        row('Head of production', '>4h', Colors.orange),
      ],
    );
  }
}

// ────────── CIRCULAR GAUGE (UPTIME ) ──────────
class _GaugeCard extends StatelessWidget {
  const _GaugeCard();

  @override
  Widget build(BuildContext context) {
    // Simple demo gauge with fl_chart – you can replace by another package.
    return _ChartCard(
      title: 'Available time',
      child: PieChart(
        PieChartData(
          sectionsSpace: 0,
          centerSpaceRadius: 40,
          sections: [
            PieChartSectionData(value: 79, radius: 12, color: Colors.green),
            PieChartSectionData(value: 21, radius: 12, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}

// ────────── DOWNTIME TABLE (static demo) ──────────
class _DowntimeTable extends StatelessWidget {
  const _DowntimeTable();

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
        fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black);

    DataRow row(String type, String mac, int freq, int cum, int avg) => DataRow(
          cells: [
            DataCell(Text(type)),
            DataCell(Text(mac)),
            DataCell(Text('$freq')),
            DataCell(Text('$cum')),
            DataCell(Text('$avg')),
          ],
        );

    return DataTable(
      headingRowColor: MaterialStateProperty.all(const Color(0xFFE0E0E0)),
      columnSpacing: 6,
      headingTextStyle: headerStyle,
      dataTextStyle: const TextStyle(fontSize: 11),
      columns: const [
        DataColumn(label: Text('Tipo Fermata')),
        DataColumn(label: Text('Macchina')),
        DataColumn(label: Text('Frequenza')),
        DataColumn(label: Text('Tempo fermo\ncumulato [min]')),
        DataColumn(label: Text('Media tempo\nfermo [min]')),
      ],
      rows: [
        row('Mancato carico', 'AIN1', 3, 126, 42),
        row('Mancata saldatura', 'AIN2', 1, 294, 294),
        row('Driver bruciato', 'AIN1', 1, 180, 180),
      ],
    );
  }
}

// ────────── PIE TOP 5 DEFECTS ──────────
class _PieTop5 extends StatelessWidget {
  const _PieTop5();

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Top 5 difetti QG2 – Shift',
      child: PieChart(
        PieChartData(
          centerSpaceRadius: 0,
          sectionsSpace: 1,
          sections: [
            PieChartSectionData(value: 21, title: '21%', radius: 18),
            PieChartSectionData(value: 13, title: '13%', radius: 18),
            PieChartSectionData(value: 9, title: '9%', radius: 18),
            PieChartSectionData(value: 7, title: '7%', radius: 18),
            PieChartSectionData(
                value: 50,
                title: '',
                radius: 0,
                showTitle: false,
                color: Colors.transparent),
          ],
        ),
      ),
    );
  }
}

// ────────── TOTAL NG BADGE ──────────
class _TotalNgBadge extends StatelessWidget {
  final int total;
  const _TotalNgBadge({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Text('$total',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Totale NG QG2',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ────────── PARETO BAR CHART ──────────
class _ParetoBar extends StatelessWidget {
  const _ParetoBar();

  @override
  Widget build(BuildContext context) {
    final items = [
      ('NG Macchie ECA', 17, 4),
      ('NG Saldatura', 8, 5),
      ('NG Bad Soldering', 9, 1),
      ('NG Mancanza L', 7, 1),
      ('NG Celle Rotte', 3, 2),
    ];

    List<BarChartGroupData> groups = [];
    for (var i = 0; i < items.length; i++) {
      groups.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(toY: items[i].$2.toDouble(), width: 6),
        BarChartRodData(
            toY: items[i].$3.toDouble(),
            width: 6,
            color: Colors.lightBlueAccent),
      ]));
    }

    return _ChartCard(
      title: 'Top 5 difetti OG2 – Shift',
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 20,
          barGroups: groups,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    return RotatedBox(
                      quarterTurns: 3,
                      child: Text(items[v.toInt()].$1,
                          style: const TextStyle(fontSize: 9)),
                    );
                  }),
            ),
            leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 24)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true),
          barTouchData: BarTouchData(enabled: false),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////////////////
/// CHART MOCK-UPS  (Throughput, cumulative yield …)                 ///
////////////////////////////////////////////////////////////////////////

class _ThroughputBar extends StatelessWidget {
  const _ThroughputBar();
  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        maxY: 450,
        barGroups: [
          BarChartGroupData(x: 0, barRods: [
            BarChartRodData(toY: 213, color: Colors.green),
            BarChartRodData(toY: 430, color: Colors.grey),
          ]),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(toY: 341, color: Colors.green),
            BarChartRodData(toY: 430, color: Colors.grey),
          ]),
          BarChartGroupData(x: 2, barRods: [
            BarChartRodData(toY: 241, color: Colors.green),
            BarChartRodData(toY: 430, color: Colors.grey),
          ]),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) => Text('S${v.toInt() + 1}')),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        ),
        barTouchData: BarTouchData(enabled: false),
        gridData: FlGridData(show: true),
      ),
    );
  }
}

class _CumLineChart extends StatelessWidget {
  const _CumLineChart();
  @override
  Widget build(BuildContext context) {
    List<FlSpot> good = [
      const FlSpot(22, 29),
      const FlSpot(0, 34),
      const FlSpot(2, 26),
      const FlSpot(4, 33),
      const FlSpot(6, 25),
    ];
    List<FlSpot> ng = [
      const FlSpot(22, 1),
      const FlSpot(0, 1),
      const FlSpot(2, 1),
      const FlSpot(4, 5),
      const FlSpot(6, 2),
    ];
    return LineChart(
      LineChartData(
        maxY: 50,
        minX: 22,
        maxX: 6,
        lineBarsData: [
          LineChartBarData(spots: good, isCurved: true, color: Colors.green),
          LineChartBarData(spots: ng, isCurved: true, color: Colors.red),
        ],
        titlesData: FlTitlesData(show: false),
        gridData: FlGridData(show: true),
      ),
    );
  }
}

class _YieldShiftBar extends StatelessWidget {
  const _YieldShiftBar();
  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        maxY: 100,
        barGroups: [
          BarChartGroupData(x: 0, barRods: [
            BarChartRodData(toY: 89, color: Colors.blue),
            BarChartRodData(toY: 67, color: Colors.blueGrey),
          ]),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(toY: 97.5, color: Colors.blue),
            BarChartRodData(toY: 81, color: Colors.blueGrey),
          ]),
          BarChartGroupData(x: 2, barRods: [
            BarChartRodData(toY: 97.5, color: Colors.blue),
            BarChartRodData(toY: 90, color: Colors.blueGrey),
          ]),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) => Text('S${v.toInt() + 1}'))),
          leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 24)),
        ),
        gridData: FlGridData(show: true),
      ),
    );
  }
}

class _YieldLineChart extends StatelessWidget {
  const _YieldLineChart();
  @override
  Widget build(BuildContext context) {
    final List<FlSpot> ain1 = [
      const FlSpot(22, 15),
      const FlSpot(0, 15),
      const FlSpot(2, 0),
      const FlSpot(4, 6.5),
      const FlSpot(6, 19),
    ];
    final List<FlSpot> ain2 = [
      const FlSpot(22, 12),
      const FlSpot(0, 11),
      const FlSpot(2, 0),
      const FlSpot(4, 6),
      const FlSpot(6, 18),
    ];
    return LineChart(
      LineChartData(
        maxY: 20,
        minX: 22,
        maxX: 6,
        lineBarsData: [
          LineChartBarData(spots: ain1, isCurved: true, color: Colors.blue),
          LineChartBarData(
              spots: ain2, isCurved: true, color: Colors.lightBlue),
        ],
        titlesData: FlTitlesData(show: false),
        gridData: FlGridData(show: true),
      ),
    );
  }
}
