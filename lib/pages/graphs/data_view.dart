import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DataViewPage extends StatelessWidget {
  const DataViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grafici & Analisi')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('📊 Line Chart',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 200, child: AnimatedLineChart()),
            const SizedBox(height: 30),
            Text('📈 Bar Chart', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 200, child: AnimatedBarChart()),
            const SizedBox(height: 30),
            Text('🥧 Pie Chart', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 200, child: AnimatedPieChart()),
          ],
        ),
      ),
    );
  }
}

class AnimatedLineChart extends StatelessWidget {
  const AnimatedLineChart({super.key});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: [
              const FlSpot(0, 1),
              const FlSpot(1, 3),
              const FlSpot(2, 1.5),
              const FlSpot(3, 5),
              const FlSpot(4, 3),
              const FlSpot(5, 4),
            ],
            isCurved: true,
            barWidth: 4,
            dotData: FlDotData(show: true),
          ),
        ],
        titlesData: FlTitlesData(show: false),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class AnimatedBarChart extends StatelessWidget {
  const AnimatedBarChart({super.key});

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        barGroups: [
          BarChartGroupData(x: 0, barRods: [
            BarChartRodData(toY: 5, color: Colors.orange, width: 16)
          ]),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(toY: 7, color: Colors.orange, width: 16)
          ]),
          BarChartGroupData(x: 2, barRods: [
            BarChartRodData(toY: 3, color: Colors.orange, width: 16)
          ]),
          BarChartGroupData(x: 3, barRods: [
            BarChartRodData(toY: 6, color: Colors.orange, width: 16)
          ]),
        ],
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(show: false),
        gridData: FlGridData(show: false),
      ),
      swapAnimationDuration: const Duration(milliseconds: 800),
    );
  }
}

class AnimatedPieChart extends StatelessWidget {
  const AnimatedPieChart({super.key});

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
              value: 40, color: Colors.green, title: '40%', radius: 50),
          PieChartSectionData(
              value: 30, color: Colors.blue, title: '30%', radius: 50),
          PieChartSectionData(
              value: 15, color: Colors.purple, title: '15%', radius: 50),
          PieChartSectionData(
              value: 15, color: Colors.red, title: '15%', radius: 50),
        ],
        centerSpaceRadius: 30,
      ),
      swapAnimationDuration: const Duration(milliseconds: 800),
    );
  }
}
