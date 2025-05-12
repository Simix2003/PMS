import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProductionDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const ProductionDetailPage({super.key, required this.data});

  String _formatDateTime(dynamic value) {
    if (value == null) return 'N/A';
    try {
      return DateFormat('dd MMM yyyy – HH:mm').format(DateTime.parse(value));
    } catch (_) {
      return value.toString();
    }
  }

  String _formatCycleTime(dynamic value) {
    if (value == null) return '-';
    if (value is int) {
      final duration = Duration(seconds: value);
      return duration.toString().split('.').first.padLeft(8, "0");
    }
    return value.toString();
  }

  Color _getStatusColor(int? esito) {
    if (esito == 1 || esito == 5) return Colors.green;
    if (esito == 2) return Colors.grey;
    if (esito == 4) return Colors.amber;
    if (esito == 6) return Colors.red;
    return Colors.blueGrey;
  }

  String _getStatusLabel(int? esito) {
    switch (esito) {
      case 1:
        return 'G';
      case 2:
        return 'In Produzione';
      case 4:
        return 'Escluso';
      case 5:
        return 'G Operatore';
      case 6:
        return 'NG';
      default:
        return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final esito = data['esito'] as int?;
    final statusColor = _getStatusColor(esito);

    return Scaffold(
      appBar: AppBar(
        title: Text('ID Modulo: ${data['id_modulo']}'),
        foregroundColor: Colors.white,
        backgroundColor: statusColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // STATUS CARD
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: statusColor.withOpacity(0.9),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Esito Produzione',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        _getStatusLabel(esito),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // GENERAL INFO
          _buildSectionTitle('Informazioni Generali'),
          _buildInfoTile(Icons.factory, 'Linea', data['line_display_name']),
          _buildInfoTile(
              Icons.precision_manufacturing, 'Stazione', data['station_name']),
          _buildInfoTile(Icons.person, 'Operatore', data['operator_id']),
          _buildInfoTile(Icons.timer_outlined, 'Tempo ciclo',
              _formatCycleTime(data['cycle_time'])),
          const SizedBox(height: 20),

          // TIMINGS
          _buildSectionTitle('Tempi'),
          _buildInfoTile(
              Icons.login, 'Ingresso', _formatDateTime(data['start_time'])),
          _buildInfoTile(
              Icons.logout, 'Uscita', _formatDateTime(data['end_time'])),
          const SizedBox(height: 20),

          // DEFECTS
          _buildSectionTitle('Difetti Rilevati'),
          if (data['defect_categories'] != null &&
              (data['defect_categories'] as String).trim().isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (data['defect_categories'] as String)
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .map(
                    (category) => Chip(
                      label: Text(category),
                      backgroundColor: Colors.red.shade100,
                      labelStyle: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                  .toList(),
            )
          else
            Text('Nessun difetto rilevato.',
                style: TextStyle(color: Colors.green.shade700, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String? value) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(value ?? '-', style: const TextStyle(fontSize: 16)),
    );
  }
}
