// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ObjectResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isSelectable;
  final bool isSelected;
  final void Function()? onTap;

  const ObjectResultCard({
    super.key,
    required this.data,
    this.isSelectable = false,
    this.isSelected = false,
    this.onTap,
  });

  Color _getStatusColor(int? esito) {
    if (esito == 1) return const Color(0xFF34C759); // OK
    if (esito == 2) return Colors.grey; // In Progress
    if (esito == 4) return const Color.fromARGB(255, 199, 189, 52); // Escluso
    if (esito == 5) return const Color(0xFF34C759); // G Operatore
    if (esito == 6) return const Color(0xFFFF3B30); // KO
    return Colors.grey; // N/A
  }

  String _getStatusLabel(int? esito) {
    if (esito == 1) return 'G';
    if (esito == 2) return 'In Produzione';
    if (esito == 4) return 'Escluso';
    if (esito == 5) return 'G Operatore';
    if (esito == 6) return 'NG';
    return 'N/A';
  }

  String _formatTime(dynamic dateTime) {
    if (dateTime == null) return 'Non disponibile';

    // Convert ISO string to DateTime if needed
    if (dateTime is String) {
      try {
        dateTime = DateTime.parse(dateTime);
      } catch (e) {
        return 'Data non valida';
      }
    }

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

  String _formatCycleTime(dynamic cycleTime) {
    if (cycleTime == null) return '-';
    if (cycleTime is String) return cycleTime;
    if (cycleTime is int) {
      final duration = Duration(seconds: cycleTime);
      return duration.toString().split('.').first.padLeft(8, "0"); // HH:mm:ss
    }
    if (cycleTime is Duration) {
      return cycleTime.toString().split('.').first.padLeft(8, "0");
    }
    return cycleTime.toString();
  }

  @override
  Widget build(BuildContext context) {
    final esito = data['esito'] as int?;
    final statusColor = _getStatusColor(esito);
    final statusLabel = _getStatusLabel(esito);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
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
              border: isSelectable && isSelected
                  ? Border.all(color: Colors.yellowAccent, width: 3)
                  : null,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
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

                // Info rows (unchanged)
                LayoutBuilder(
                  builder: (context, constraints) {
                    int columnCount = 1;
                    if (constraints.maxWidth > 600) columnCount = 2;
                    if (constraints.maxWidth > 900) columnCount = 3;

                    final infoItems = [
                      _buildInfoRow(Icons.factory, 'Linea:',
                          data['line_display_name'] ?? '-', Colors.white),
                      _buildInfoRow(Icons.precision_manufacturing, 'Stazione:',
                          data['station_name'] ?? '-', Colors.white),
                      _buildInfoRow(Icons.person, 'Operatore:',
                          data['operator_id'] ?? '-', Colors.white),
                      _buildInfoRow(Icons.access_time, 'Tempo Ciclo:',
                          _formatCycleTime(data['cycle_time']), Colors.white),
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
                          width:
                              (constraints.maxWidth - 16 * (columnCount - 1)) /
                                  columnCount,
                          child: infoItems[index],
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(height: 12),

                if (data['defect_categories'] != null &&
                    (data['defect_categories'] as String).trim().isNotEmpty)
                  Builder(
                    builder: (context) {
                      final categories = (data['defect_categories'] as String)
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();

                      final labelText =
                          categories.length > 1 ? 'Difetti:' : 'Difetto:';

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            labelText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: categories
                                .map((category) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        category,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          if (isSelectable)
            Positioned(
              bottom: 16,
              right: 16,
              child: Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? Colors.yellowAccent : Colors.white70,
              ),
            ),
        ],
      ),
    );
  }
}
