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

  @override
  Widget build(BuildContext context) {
    final defectsRaw = stationData['defects'];
    final defects =
        defectsRaw is Map ? Map<String, dynamic>.from(defectsRaw) : {};

    final avgCycleTime = stationData["avg_cycle_time"] ?? "00:00:00";
    final good = stationData["good_count"] ?? 0;
    final bad = stationData["bad_count"] ?? 0;
    final total = good + bad;

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

              // Total produced
              Row(
                children: [
                  const Icon(Icons.precision_manufacturing,
                      size: 20, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Totale prodotti: $total',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Avg cycle time
              Row(
                children: [
                  const Icon(Icons.timer, size: 20, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Text(
                    'Tempo Ciclo medio: $avgCycleTime',
                    style: const TextStyle(fontSize: 16),
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
