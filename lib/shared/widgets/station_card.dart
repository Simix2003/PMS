import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StationCard extends StatelessWidget {
  final String station;
  final Map<String, dynamic> stationData;

  const StationCard({
    super.key,
    required this.station,
    required this.stationData,
  });

  String formatCycleTimeToMinutes(String rawTime) {
    try {
      final timeWithoutMicros = rawTime.split('.')[0];
      final parts = timeWithoutMicros.split(':').map(int.parse).toList();
      int totalSeconds = 0;

      if (parts.length == 3) {
        totalSeconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
      } else if (parts.length == 4) {
        totalSeconds =
            parts[0] * 86400 + parts[1] * 3600 + parts[2] * 60 + parts[3];
      }

      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    } catch (e) {
      return "00:00";
    }
  }

  // Function to extract only the time (HH:mm) from a datetime string
  String _formatTime(String dateTime) {
    try {
      final time = DateTime.parse(dateTime);
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Tempo non disponibile'; // In case the dateTime is invalid
    }
  }

  @override
  Widget build(BuildContext context) {
    final defectsRaw = stationData['defects'];
    final defects =
        defectsRaw is Map ? Map<String, dynamic>.from(defectsRaw) : {};

    final rawCycleTime = stationData["avg_cycle_time"] ?? "00:00:00";
    final avgCycleTime = formatCycleTimeToMinutes(rawCycleTime);
    final good = stationData["good_count"] ?? 0;
    final bad = stationData["bad_count"] ?? 0;
    final total = good + bad;
    final yield = total > 0 ? (good / total * 100).toStringAsFixed(1) : "0.0";

    // Data for Pie chart (good, main defects)
    final defectGroups = defects.entries.map((entry) => entry.value).toList();
    final defectLabels = defects.entries.map((entry) => entry.key).toList();

    // Prepare Pie chart sections
    final pieData = [
      PieChartSectionData(
        color: Colors.green,
        value: good.toDouble(),
        radius: 30,
        titleStyle: TextStyle(color: Colors.white, fontSize: 12),
      ),
      ...List.generate(defectGroups.length, (index) {
        return PieChartSectionData(
          color: Colors.primaries[index % Colors.primaries.length],
          value: defectGroups[index].toDouble(),
          radius: 30,
          titleStyle: TextStyle(color: Colors.white, fontSize: 12),
        );
      })
    ];

    // Create the Legend widget
    List<Widget> legendItems = [
      if (good > 0) ...[
        LegendItem(
          color: Colors.green,
          label: 'OK: $good',
        ),
      ],
      ...List.generate(defectGroups.length, (index) {
        return LegendItem(
          color: Colors.primaries[index % Colors.primaries.length],
          label: 'KO ${defectLabels[index]}: ${defectGroups[index]}',
        );
      })
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Station name and Dettagli button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    station,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Add action
                    },
                    icon: const Icon(Icons.info_outline),
                    label: const Text("Dettagli"),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Defects and Product info
              Row(
                children: [
                  // Left column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.precision_manufacturing,
                                size: 20, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              'Prodotti: $total',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.check_circle,
                                size: 20, color: Colors.teal),
                            const SizedBox(width: 8),
                            Text(
                              'Yield (TPY): $yield%',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Right column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timer,
                                size: 20, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Text(
                              'Ciclo Medio: $avgCycleTime m:s',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Pie Chart for Defect Distribution
              if (total > 0) ...[
                const Text(
                  'Distribuzione Difetti:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    // Pie chart inside a SizedBox to provide constraints
                    SizedBox(
                      height: 200, // Set a fixed height for the PieChart
                      width: 200, // Provide a fixed width for the PieChart
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 0,
                          centerSpaceRadius: 40,
                          sections: pieData,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Legend
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: legendItems,
                    ),
                    const SizedBox(width: 16),
                    // New Card for "Last object" information
                    Expanded(
                      child: Card(
                        elevation: 6, // Higher elevation for better visibility
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: stationData['last_esito'] == 1
                                ? Colors.green
                                : Colors.red,
                            width: 3,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 20, color: Colors.black87),
                                  SizedBox(width: 8),
                                  Text(
                                    'Ultimo Modulo:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Split the data into two columns
                              Row(
                                children: [
                                  // First Column (Left Side)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.data_object,
                                                size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                stationData['last_object'] !=
                                                        null
                                                    ? 'ID: ${stationData['last_object']}'
                                                    : 'ID non disponibile',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.grey[800]),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.timer_outlined,
                                                size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                stationData['last_cycle_time'] !=
                                                        null
                                                    ? 'Tempo Ciclo: ${stationData['last_cycle_time']}'
                                                    : 'Tempo non disponibile',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.grey[800]),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Second Column (Right Side)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.login, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                stationData['last_in_time'] !=
                                                        null
                                                    ? 'Ingresso: ${_formatTime(stationData['last_in_time'])}'
                                                    : 'Ingresso non disponibile',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.grey[800]),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.logout, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                stationData['last_out_time'] !=
                                                        null
                                                    ? 'Uscita: ${_formatTime(stationData['last_out_time'])}'
                                                    : 'Uscita non disponibile',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.grey[800]),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
