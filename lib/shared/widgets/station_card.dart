// ignore_for_file: deprecated_member_use, prefer_typing_uninitialized_variables

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StationCard extends StatelessWidget {
  final String station;
  final Map<String, dynamic> stationData;
  final DateTime? selectedDate;
  final DateTimeRange? selectedRange;
  final TimeOfDay? selectedStartTime;
  final TimeOfDay? selectedEndTime;
  final int turno;
  final thresholdSeconds;

  const StationCard({
    super.key,
    required this.station,
    required this.stationData,
    required this.selectedDate,
    required this.selectedRange,
    required this.selectedStartTime,
    required this.selectedEndTime,
    required this.turno,
    required this.thresholdSeconds,
  });

  static const List<String> allDefectCategories = [
    "Generali",
    "Saldatura",
    "Disallineamento",
    "Mancanza Ribbon",
    "Macchie ECA",
    "Celle Rotte",
    "Lunghezza String Ribbon",
    "Altro",
    "Generico",
  ];

  // iOS color palette - softer, more vibrant colors
  static const Map<String, Color> defectColors = {
    "Generali": Color(0xFF007AFF), // iOS Blue
    "Saldatura": Color(0xFFFF9500), // iOS Orange
    "Disallineamento": Color(0xFFFF3B30), // iOS Red
    "Mancanza Ribbon": Color(0xFFFF2D55), // iOS Pink
    "Macchie ECA": Color(0xFFAF52DE), // iOS Purple
    "Celle Rotte": Color(0xFF5856D6), // iOS Indigo
    "Lunghezza String Ribbon": Color(0xFFA2845E), // iOS Brown
    "Altro": Color(0xFF8E8E93), // iOS Gray
    "Generico": Color(0xFFFF3B30), // iOS Red
  };

  String formatCycleTimeToMinutes(String rawTime) {
    try {
      final timeWithoutMicros = rawTime.split('.')[0];
      final parts = timeWithoutMicros.split(':').map(int.parse).toList();
      int totalSeconds = 0;
      if (parts.length == 3) {
        totalSeconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
      }
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    } catch (e) {
      return "00:00";
    }
  }

  String _formatTime(String dateTime) {
    try {
      final time = DateTime.parse(dateTime);
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Tempo non disponibile';
    }
  }

  Widget _buildStatBox(
      String label, int value, Color color, IconData iconData) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 300;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          height: isNarrow ? null : 80, // auto-height if stacked
          child: isNarrow
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(iconData, color: color, size: 24),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: color,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$value',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(iconData, color: color, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget buildWarningBox(int thresholdSeconds) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 300;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFE0B2), width: 1),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: Color(0xFFFF9500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Good Non Controllati QG2: cicli inferiori a $thresholdSeconds secondi',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFB76E00),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: Color(0xFFFF9500),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Good Non Controllati QG2: cicli inferiori a $thresholdSeconds secondi',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFB76E00),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final defectsRaw = stationData['defects'];
    final defects =
        defectsRaw is Map ? Map<String, dynamic>.from(defectsRaw) : {};

    final rawCycleTime = stationData["avg_cycle_time"] ?? "00:00:00";
    final avgCycleTime = formatCycleTimeToMinutes(rawCycleTime);
    final koCount = (stationData['bad_count'] ?? 0);

    final allCycles = (stationData['cycle_times'] as List?)?.cast<num>() ?? [];

    int gCount = 0;
    int ncCount = 0;

    for (final cycle in allCycles) {
      if (cycle >= thresholdSeconds) {
        gCount++;
      } else {
        ncCount++;
      }
    }

    final total = gCount + ncCount + koCount;

    final yield = total > 0
        ? ((gCount + ncCount) / total * 100).toStringAsFixed(1)
        : "0.0";

    // Fill missing categories with 0
    final filledDefects = {
      for (var key in allDefectCategories) key: (defects[key] ?? 0) as num
    };

    final chartMaxY =
        filledDefects.values.map((e) => e.toDouble()).fold<double>(0, max) + 5;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: Colors.black.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with SF Pro Display style
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        station,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.arrow_forward_ios_rounded,
                              size: 18),
                          color: const Color(0xFF007AFF),
                          tooltip: "Dettagli",
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                  if (selectedRange != null)
                    Text(
                      '${DateFormat("dd MMMM yyyy", "it_IT").format(selectedRange!.start)} → ${DateFormat("dd MMMM yyyy", "it_IT").format(selectedRange!.end)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    )
                  else if (selectedDate != null)
                    Text(
                      DateFormat("dd MMMM yyyy", "it_IT").format(selectedDate!),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  if (selectedStartTime != null &&
                      selectedEndTime != null &&
                      turno == 0)
                    Text(
                      '${selectedStartTime?.format(context)} → ${selectedEndTime?.format(context)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey,
                      ),
                    ),
                  if (turno != 0)
                    Text(
                      'Turno $turno',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey,
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildStatBox(
                          'Totale Prodotti',
                          total as int,
                          const Color(0xFF007AFF),
                          Icons.precision_manufacturing_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatBox(
                          'Good',
                          gCount,
                          const Color(0xFF34C759),
                          Icons.check_circle_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

// 🟠 Show 'Good Non Controllati' only when NOT M326
                  if (station != 'M326 - ReWork' && station != 'M326') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildStatBox(
                            'Good Non Controllati QG2',
                            ncCount,
                            const Color(0xFFFF9500),
                            Icons.warning_amber_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // ✅ No Good is shown here too
                        Expanded(
                          child: _buildStatBox(
                            'No Good',
                            koCount,
                            const Color(0xFFFF3B30),
                            Icons.cancel_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    buildWarningBox(thresholdSeconds),
                  ],

// 🔴 Show only 'No Good' when in M326
                  if (station == 'M326 - ReWork' || station == 'M326') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildStatBox(
                            'No Good',
                            koCount,
                            const Color(0xFFFF3B30),
                            Icons.cancel_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Production summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildInfoRow(
                            Icons.check_circle_outline_rounded,
                            'Yield (TPY)',
                            '$yield%',
                            const Color(0xFF34C759),
                          ),
                        ),
                        Expanded(
                          child: _buildInfoRow(
                            Icons.timer_outlined,
                            'Ciclo Medio',
                            '$avgCycleTime m:s',
                            const Color(0xFF5856D6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Defect chart with iOS styling
                  if (total > 0 && station != 'M326 - ReWork' ||
                      station != 'M326')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Distribuzione Difetti',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 280,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: BarChart(
                            BarChartData(
                              maxY: chartMaxY,
                              barTouchData: BarTouchData(
                                enabled: true,
                                touchTooltipData: BarTouchTooltipData(
                                  tooltipRoundedRadius: 12,
                                  getTooltipItem:
                                      (group, groupIndex, rod, rodIndex) {
                                    return BarTooltipItem(
                                      '',
                                      const TextStyle(),
                                      children: [
                                        TextSpan(
                                          text: rod.toY.toInt().toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 90,
                                    getTitlesWidget: (value, meta) {
                                      final label =
                                          allDefectCategories[value.toInt()];
                                      return Transform.rotate(
                                        angle: -0.4,
                                        child: SideTitleWidget(
                                          meta: meta,
                                          space: 16,
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        value.toInt().toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade600,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                              ),
                              gridData: FlGridData(
                                show: true,
                                horizontalInterval: 5,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: Colors.grey.shade200,
                                    strokeWidth: 1,
                                  );
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups: allDefectCategories
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final name = entry.value;
                                final count = filledDefects[name]!.toDouble();
                                final color = defectColors[name] ?? Colors.grey;
                                return BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: count,
                                      color: color,
                                      width: 24,
                                      borderRadius: BorderRadius.circular(8),
                                      backDrawRodData:
                                          BackgroundBarChartRodData(
                                        show: true,
                                        toY: chartMaxY,
                                        color: color.withOpacity(0.1),
                                      ),
                                    ),
                                  ],
                                  showingTooltipIndicators: [
                                    0
                                  ], // 👈 Always show tooltip for the 1st rod
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Last cycle card - Apple Card inspired
                  _buildLastModuleCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLastModuleCard() {
    final lastEsito = stationData['last_esito'];
    final isSuccess = lastEsito == 1;
    final isNoData = lastEsito != 1 && lastEsito != 6;

    final statusColor = isNoData
        ? Colors.grey
        : (isSuccess ? const Color(0xFF34C759) : const Color(0xFFFF3B30));

    final statusLabel = isNoData ? 'N/A' : (isSuccess ? 'OK' : 'KO');

    final lastObject = stationData['last_object'] ?? 'ID non disponibile';
    final lastCycleTime =
        stationData['last_cycle_time'] ?? 'Tempo non disponibile';
    final lastInTime = stationData['last_in_time'] != null
        ? _formatTime(stationData['last_in_time'])
        : 'Ingresso non disponibile';
    final lastOutTime = stationData['last_out_time'] != null
        ? _formatTime(stationData['last_out_time'])
        : 'Uscita non disponibile';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ultimo Modulo',
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLastModuleInfoRow(
                      Icons.data_object_rounded,
                      'ID:',
                      lastObject,
                      Colors.white,
                    ),
                    const SizedBox(height: 8),
                    _buildLastModuleInfoRow(
                      Icons.timer_outlined,
                      'Tempo Ciclo:',
                      lastCycleTime,
                      Colors.white,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLastModuleInfoRow(
                      Icons.login_rounded,
                      'Ingresso:',
                      lastInTime,
                      Colors.white,
                    ),
                    const SizedBox(height: 8),
                    _buildLastModuleInfoRow(
                      Icons.logout_rounded,
                      'Uscita:',
                      lastOutTime,
                      Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLastModuleInfoRow(
      IconData icon, String label, String value, Color color) {
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
}
