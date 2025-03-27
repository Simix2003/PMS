// station_card.dart

import 'package:flutter/material.dart';

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
      // Remove microseconds
      final timeWithoutMicros = rawTime.split('.')[0];

      // Split into parts
      final parts = timeWithoutMicros.split(':').map(int.parse).toList();

      int totalSeconds = 0;

      if (parts.length == 3) {
        totalSeconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
      } else if (parts.length == 4) {
        // If D:H:M:S
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

  @override
  Widget build(BuildContext context) {
    final defectsRaw = stationData['defects'];
    final defects =
        defectsRaw is Map ? Map<String, dynamic>.from(defectsRaw) : {};

    final rawCycleTime = stationData["avg_cycle_time"] ?? "00:00:00";
    final avgCycleTime = formatCycleTimeToMinutes(rawCycleTime);
    final rawLastCycleTime = stationData["last_cycle_time"] ?? "00:00:00";
    final lastCycleTime = formatCycleTimeToMinutes(rawLastCycleTime);
    final good = stationData["good_count"] ?? 0;
    final bad = stationData["bad_count"] ?? 0;
    final total = good + bad;
    final yield = total > 0 ? (good / total * 100).toStringAsFixed(1) : "0.0";

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
                        Row(
                          children: [
                            const Icon(Icons.access_time,
                                size: 20, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Text(
                              'Ultimo Ciclo: $lastCycleTime m:s',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Defect list
              if (defects.isNotEmpty) ...[
                const Text(
                  'Difetti KO:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...defects.entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '• ${entry.key}: ${entry.value}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    )),
              ] else
                const Text(
                  'Nessun difetto KO registrato.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
