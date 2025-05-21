import 'package:flutter/material.dart';

import '../../shared/services/api_service.dart';

class MBJDetailPage extends StatelessWidget {
  final Map<String, dynamic> data; // contains 'id_modulo'

  const MBJDetailPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final idModulo = data['id_modulo'] ?? data['object_id'];

    return Scaffold(
      appBar: AppBar(title: const Text('Dettagli MBJ')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: ApiService.fetchMBJDetails(idModulo),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
                child: Text('Nessun dettaglio trovato per questo modulo.'));
          }

          final mbjData = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                _buildDetailTile('Object ID', mbjData['id_modulo']),
                _buildDetailTile('Stazione', mbjData['station_name']),
                _buildDetailTile('Linea', mbjData['line_display_name']),
                _buildDetailTile('Operatore', mbjData['operator_id']),
                _buildDetailTile('Inizio', mbjData['start_time']),
                _buildDetailTile('Fine', mbjData['end_time']),
                _buildDetailTile(
                    'Cycle Time', mbjData['cycle_time'].toString()),
                const SizedBox(height: 24),
                const Placeholder(fallbackHeight: 200),
                const SizedBox(height: 16),
                const Text(
                  'Grafici, difetti o immagini verranno mostrati qui...',
                  style: TextStyle(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailTile(String label, dynamic value) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(value?.toString() ?? 'N/A'),
    );
  }
}
