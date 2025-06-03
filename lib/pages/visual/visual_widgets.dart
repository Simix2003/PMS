import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

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
            color: Colors.white,
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
            child: TrafficLightCircle(color: Colors.red, label: '2'),
          ),
          Positioned(
            top: 75,
            child: TrafficLightCircle(color: Colors.amber.shade700, label: '1'),
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
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

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
    return Expanded(
      child: Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text(
                "Top 5 Difetti QG2 - Shift",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 15,
                    sections: _generateSections(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _generateSections() {
    // Example hardcoded data — replace with your dynamic values
    final data = [
      {'label': 'Macchie ECA', 'value': 30.0, 'color': Colors.red},
      {'label': 'Celle Rotte', 'value': 25.0, 'color': Colors.purple},
      {
        'label': 'Disallineamento',
        'value': 20.0,
        'color': Colors.amber.shade700
      },
      {'label': 'Saldatura', 'value': 15.0, 'color': Colors.green},
      {'label': 'Altro', 'value': 10.0, 'color': Colors.blue},
    ];

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
