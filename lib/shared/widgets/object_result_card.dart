// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ObjectResultCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const ObjectResultCard({super.key, required this.data});

  Color _getStatusColor(int? esito) {
    if (esito == 1) return const Color(0xFF34C759); // OK
    if (esito == 6) return const Color(0xFFFF3B30); // KO
    return Colors.grey; // N/A
  }

  String _getStatusLabel(int? esito) {
    if (esito == 1) return 'OK';
    if (esito == 6) return 'KO';
    return 'N/A';
  }

  String _formatTime(dynamic dateTime) {
    if (dateTime == null) return 'Non disponibile';
    return DateFormat('dd MMM yyyy – HH:mm').format(dateTime);
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color.withOpacity(0.8), size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final esito = data['esito'] as int?;
    final statusColor = _getStatusColor(esito);
    final statusLabel = _getStatusLabel(esito);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.8),
            statusColor,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${data['id_modulo']}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              // Calculate column count based on card width
              int columnCount = 1;
              if (constraints.maxWidth > 600) columnCount = 2;
              if (constraints.maxWidth > 900) columnCount = 3;

              final infoItems = [
                _buildInfoRow(Icons.person, 'Operatore:',
                    data['operatore'] ?? '-', Colors.white),
                _buildInfoRow(Icons.access_time, 'Tempo Ciclo:',
                    data['cycle_time'] ?? '-', Colors.white),
                _buildInfoRow(Icons.login, 'Ingresso:',
                    _formatTime(data['start_time']), Colors.white),
                _buildInfoRow(Icons.logout, 'Uscita:',
                    _formatTime(data['end_time']), Colors.white),
              ];

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: List.generate(infoItems.length, (index) {
                  return SizedBox(
                    width: (constraints.maxWidth - 16 * (columnCount - 1)) /
                        columnCount,
                    child: infoItems[index],
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}
