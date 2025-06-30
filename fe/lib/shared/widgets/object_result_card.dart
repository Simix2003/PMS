// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ix_monitor/shared/utils/helpers.dart';

import '../services/api_service.dart';

class ObjectResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isSelectable;
  final bool isSelected;
  final int productionIdsCount;
  final void Function()? onTap;
  final double minCycleTimeThreshold;

  const ObjectResultCard({
    super.key,
    required this.data,
    required this.minCycleTimeThreshold,
    this.isSelectable = false,
    this.isSelected = false,
    this.productionIdsCount = 1,
    this.onTap,
  });

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
    int esito = data['esito'] as int? ?? 0;
    final cycleTime = data['cycle_time'] as int?;

    // Define stations where short cycle time → esito 7 (NC)
    const shortCycleCheckStations = {
      'MIN01',
      'MIN02',
      'RMI01',
      'RWS01',
      'VPF01',
      'FUG01',
      'FUG02',
      'VIM01'
    };

    // Apply condition only for those stations
    if (shortCycleCheckStations.contains(data['station_name'])) {
      if (esito == 1 &&
          cycleTime != null &&
          cycleTime < minCycleTimeThreshold) {
        esito = 7;
      }
    }

    final statusColor = getStatusColor(esito);
    final statusLabel = getStatusLabel(esito);

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
                // Title Row with badge under Esito
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
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
                      FutureBuilder(
                        future: data['station_name'] == 'ELL01'
                            ? ApiService.fetchMBJDetails(data['id_modulo'])
                                .catchError((_) => null)
                            : Future.value(null),
                        builder: (context, snapshot) {
                          final isMBJ = data['station_name'] == 'ELL01';
                          final showWarning = isMBJ &&
                              snapshot.connectionState ==
                                  ConnectionState.done &&
                              snapshot.data == null;

                          return Row(
                            children: [
                              Icon(Icons.precision_manufacturing,
                                  color: Colors.white.withOpacity(0.8),
                                  size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Stazione:',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      data['station_name'] ?? '-',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (showWarning)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 6),
                                        child: Icon(Icons.folder_off_rounded,
                                            color: Colors.white, size: 18),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      /*_buildInfoRow(Icons.person, 'Operatore:',
                          data['operator_id'] ?? '-', Colors.white),*/
                      _buildInfoRow(Icons.access_time, 'Tempo Ciclo:',
                          _formatCycleTime(data['cycle_time']), Colors.white),
                      _buildInfoRow(Icons.login, 'Ingresso:',
                          _formatTime(data['start_time']), Colors.white),
                      _buildInfoRow(Icons.logout, 'Uscita:',
                          _formatTime(data['end_time']), Colors.white),
                      if (data['station_name'] == "MIN01" ||
                          data['station_name'] == "MIN02")
                        _buildInfoRow(
                            Icons.work_history_sharp,
                            'Stringatrice:',
                            data['last_station_display_name'] ?? '-',
                            Colors.white),
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
                const SizedBox(height: 8),

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
                if (data['station_name'] == 'ELL01')
                  FutureBuilder(
                    future: ApiService.fetchMBJDetails(data['id_modulo']),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data == null) {
                        return const SizedBox.shrink(); // or a placeholder
                      }

                      final mbjData = snapshot.data as Map<String, dynamic>;
                      final hasBacklight = mbjData['NG PMS Backlight'] == true;
                      final hasEL =
                          mbjData['NG PMS Elettroluminescenza'] == true;

                      final tags = <String>[];
                      if (hasBacklight) tags.add('Backlight');
                      if (hasEL) tags.add('Elettroluminescenza');

                      if (tags.isEmpty) return const SizedBox.shrink();

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            tags.length > 1 ? 'MBJ Difetti:' : 'MBJ Difetto:',
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
                            children: tags
                                .map((label) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        label,
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

                // Always visible bottom-right counter
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, right: 4),
                    child: productionIdsCount > 1
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.folder,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$productionIdsCount eventi',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
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
