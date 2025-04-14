// ignore_for_file: deprecated_member_use, library_private_types_in_public_api

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../shared/services/api_service.dart';
import '../../shared/services/socket_service.dart';
import '../../shared/widgets/station_card.dart';

class DataViewPage extends StatefulWidget {
  final bool canSearch;

  const DataViewPage({super.key, required this.canSearch});

  @override
  _DataViewPageState createState() => _DataViewPageState();
}

class _DataViewPageState extends State<DataViewPage> {
  final WebSocketService _webSocketService = WebSocketService();

  // Initially using a single date; if a range is selected, _selectedRange will be non-null
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _selectedRange;
  // Initialize start and end time to default full-day range
  TimeOfDay? selectedStartTime =
      TimeOfDay(hour: 0, minute: 0); // Default: 00:00
  TimeOfDay? selectedEndTime =
      TimeOfDay(hour: 23, minute: 59); // Default: 23:59

  // Using 0 to represent "Full Day" and 1, 2, 3 for the three shifts.
  // Default is full day.
  int selectedTurno = 0;

  String selectedLine = "Linea2";
  final List<String> availableLines = ["Linea1", "Linea2"];
  final Map<String, String> lineDisplayNames = {
    'Linea1': 'Linea A',
    'Linea2': 'Linea B',
  };

  Map<String, dynamic>? _fetchedData;

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
    _fetchData().then((data) {
      if (mounted) {
        setState(() {
          _fetchedData = data;
        });
      }
    });
  }

  @override
  void dispose() {
    _webSocketService.close();
    super.dispose();
  }

  void _initializeWebSocket() {
    _webSocketService.connectToSummary(
      selectedLine: selectedLine,
      onMessage: () async {
        final newData = await _fetchData();
        if (mounted) {
          setState(() {
            _fetchedData = newData; // Update only the graph/stat section
          });
        }
      },
    );
  }

  void _onLineChange(String? newLine) {
    if (newLine != null && newLine != selectedLine) {
      setState(() {
        selectedLine = newLine;
        _initializeWebSocket(); // reconnect WebSocket for the new line
      });

      _fetchData().then((data) {
        if (mounted) {
          setState(() {
            _fetchedData = data;
          });
        }
      });
    }
  }

  Future<Map<String, dynamic>> _fetchData() {
    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      selectedStartTime?.hour ?? 0,
      selectedStartTime?.minute ?? 0,
    );

    final endDateTime = (_selectedRange != null
        ? DateTime(
            _selectedRange!.end.year,
            _selectedRange!.end.month,
            _selectedRange!.end.day,
            selectedEndTime?.hour ?? 23,
            selectedEndTime?.minute ?? 59,
          )
        : DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            selectedEndTime?.hour ?? 23,
            selectedEndTime?.minute ?? 59,
          ));

    return ApiService.fetchProductionSummary(
      selectedLine: selectedLine,
      singleDate: _selectedRange == null ? _selectedDate : null,
      range: _selectedRange,
      selectedTurno: selectedTurno,
      startTime: startDateTime,
      endTime: endDateTime,
    );
  }

  String _getDateTitle() {
    if (_selectedRange != null) {
      final from =
          DateFormat('d MMMM y', 'it_IT').format(_selectedRange!.start);
      final to = DateFormat('d MMMM y', 'it_IT').format(_selectedRange!.end);
      return '$from → $to';
    } else {
      final today = DateTime.now();
      final isToday = _selectedDate.year == today.year &&
          _selectedDate.month == today.month &&
          _selectedDate.day == today.day;

      final formatted = DateFormat('d MMMM y', 'it_IT').format(_selectedDate);
      return isToday ? 'Oggi, $formatted' : formatted;
    }
  }

  Future<void> _selectDateOrRange() async {
    final DateTime firstDate = DateTime(DateTime.now().year - 1);
    final DateTime lastDate = DateTime.now();

    final (DateTime? pickedDate, DateTimeRange? pickedRange) =
        await _showCustomCalendarPicker(context, firstDate, lastDate) ??
            (null, null);

    if (pickedDate != null || pickedRange != null) {
      setState(() {
        if (pickedDate != null) {
          _selectedDate = pickedDate;
          _selectedRange = null;
        } else if (pickedRange != null) {
          _selectedDate = pickedRange.start;
          _selectedRange = pickedRange;
        }
      });

      _fetchData().then((data) {
        if (mounted) {
          setState(() {
            _fetchedData = data;
          });
        }
      });
    }
  }

  Future<(DateTime?, DateTimeRange?)?> _showCustomCalendarPicker(
      BuildContext context, DateTime firstDate, DateTime lastDate) async {
    final Color backgroundColor = Colors.white.withOpacity(0.9);
    final Color primaryColor = const Color(0xFF007AFF);
    final Color textColor = Colors.black87;

    List<DateTime?> selectedDates = [];

    final config = CalendarDatePicker2WithActionButtonsConfig(
      weekdayLabels: const [
        'Dom',
        'Lun',
        'Mar',
        'Mer',
        'Gio',
        'Ven',
        'Sab',
      ],
      firstDayOfWeek: 1, // 1 = Monday
      calendarType: CalendarDatePicker2Type.range,
      selectedDayHighlightColor: primaryColor,
      selectedRangeHighlightColor: primaryColor.withOpacity(0.15),
      dayTextStyle: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.normal,
      ),
      disabledDayTextStyle: TextStyle(
        color: textColor.withOpacity(0.4),
        fontSize: 16,
        fontWeight: FontWeight.normal,
      ),
      weekdayLabelTextStyle: TextStyle(
        color: textColor.withOpacity(0.7),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      controlsTextStyle: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      yearTextStyle: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      todayTextStyle: TextStyle(
        color: primaryColor,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      dayBorderRadius: BorderRadius.circular(10),
      selectableDayPredicate: (day) => true,
      controlsHeight: 60,
      centerAlignModePicker: true,
      customModePickerIcon: const SizedBox(),
      cancelButtonTextStyle: const TextStyle(
        color: Colors.red,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      okButtonTextStyle: const TextStyle(
        color: Color(0xFF007AFF),
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      cancelButton: Text(
        'Annulla',
        style: TextStyle(
          color: const Color(0xFFFF3B30),
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      okButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Conferma',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );

    return showDialog<(DateTime?, DateTimeRange?)>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.height * 0.7,
                child: CalendarDatePicker2WithActionButtons(
                  config: config,
                  value: selectedDates,
                  onValueChanged: (dates) {
                    selectedDates = dates;
                  },
                  onCancelTapped: () {
                    Navigator.pop(context, (null, null));
                  },
                  onOkTapped: () {
                    if (selectedDates.length == 1 && selectedDates[0] != null) {
                      Navigator.pop(context, (selectedDates[0], null));
                    } else if (selectedDates.length == 2 &&
                        selectedDates[0] != null &&
                        selectedDates[1] != null) {
                      final range = DateTimeRange(
                        start: selectedDates[0]!,
                        end: selectedDates[1]!,
                      );
                      Navigator.pop(context, (null, range));
                    } else {
                      Navigator.pop(context, (null, null));
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static const List<String> allDefectCategories = [
    "Generali",
    "Saldatura",
    "Disallineamento",
    "Mancanza Ribbon",
    "Macchie ECA",
    "Celle Rotte",
    "Lunghezza\nString Ribbon",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: const Text(
          'Analisi Dati',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Text(
                  "Linea:",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButton<String>(
                    value: selectedLine,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF007AFF),
                    ),
                    underline: Container(), // Remove the default underline
                    borderRadius: BorderRadius.circular(16),
                    items: availableLines.map((line) {
                      return DropdownMenuItem(
                        value: line,
                        child: Text(
                          lineDisplayNames[line] ?? line,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: _onLineChange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _fetchedData == null
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF007AFF),
                strokeWidth: 3,
              ),
            )
          : _fetchedData!.containsKey('error')
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 60,
                          color: Colors.red[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Errore nel caricamento dei dati',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_fetchedData!['error']}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            _fetchData().then((data) {
                              if (mounted) {
                                setState(() {
                                  _fetchedData = data;
                                });
                              }
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text("Riprova"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Builder(
                  builder: (context) {
                    final data = _fetchedData!;
                    final stations = data['stations'].entries.toList();

                    final maxY = stations.map((entry) {
                          final counts = entry.value as Map<String, dynamic>;
                          return (counts['good_count'] as int) +
                              (counts['bad_count'] as int);
                        }).fold(0, (a, b) => a > b ? a : b) +
                        20;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderCard(maxY, stations),
                          const SizedBox(height: 24),
                          _buildLineaOverviewCard(
                            stations,
                            selectedLine,
                            lineDisplayNames,
                            _selectedDate,
                            _selectedRange,
                          ),
                          const SizedBox(height: 24),
                          ...stations.map((entry) {
                            final stationCode = entry.key;
                            final stationData =
                                entry.value as Map<String, dynamic>;
                            final visualName =
                                stationData['display'] ?? stationCode;
                            return StationCard(
                              station: visualName,
                              stationData: stationData,
                              selectedDate: _selectedDate,
                              selectedRange: _selectedRange,
                            );
                          }).toList(),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  double _parseCycleTime(dynamic value) {
    if (value is num) return value.toDouble();

    if (value is String) {
      try {
        final parts = value.split(':');
        if (parts.length == 3) {
          final hours = int.tryParse(parts[0]) ?? 0;
          final minutes = int.tryParse(parts[1]) ?? 0;
          final seconds = double.tryParse(parts[2]) ?? 0.0;
          return hours * 3600 + minutes * 60 + seconds;
        }
      } catch (_) {
        return 0.0;
      }
    }

    return 0.0;
  }

  Widget _buildStatBox(
      String label, int value, Color color, IconData iconData) {
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
      height: 80,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
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
          ),
          Center(
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

  Widget _buildLineaOverviewCard(
    List<MapEntry<String, dynamic>> stations,
    String selectedLine,
    Map<String, String> lineDisplayNames,
    DateTime? selectedDate,
    DateTimeRange? selectedRange,
  ) {
    final m308 = stations.firstWhere((e) => e.key == 'M308',
        orElse: () => MapEntry('M308', {}));
    final m309 = stations.firstWhere((e) => e.key == 'M309',
        orElse: () => MapEntry('M309', {}));

    final m308Data = m308.value as Map<String, dynamic>? ?? {};
    final m309Data = m309.value as Map<String, dynamic>? ?? {};

    final m308Cycle = _parseCycleTime(m308Data['avg_cycle_time']);
    final m309Cycle = _parseCycleTime(m309Data['avg_cycle_time']);

    final cycleCount = [
      if (m308Cycle > 0) m308Cycle,
      if (m309Cycle > 0) m309Cycle,
    ];

    final avgCycleSeconds = cycleCount.isNotEmpty
        ? cycleCount.reduce((a, b) => a + b) / cycleCount.length
        : 0.0;

    // Format as mm:ss
    final minutes = avgCycleSeconds ~/ 60;
    final seconds = (avgCycleSeconds % 60).round();
    final avgCycleTime = '$minutes:${seconds.toString().padLeft(2, '0')}';

    final okCount =
        (m308Data['good_count'] ?? 0) + (m309Data['good_count'] ?? 0);
    final koCount = (m308Data['bad_count'] ?? 0) + (m309Data['bad_count'] ?? 0);
    final total = okCount + koCount;
    final yield =
        total > 0 ? (okCount / total * 100).toStringAsFixed(1) : "0.0";

    final m308defectsRaw = m308Data['defects'];
    final m309defectsRaw = m309Data['defects'];

    final m308defects =
        m308defectsRaw is Map ? Map<String, dynamic>.from(m308defectsRaw) : {};
    final m309defects =
        m309defectsRaw is Map ? Map<String, dynamic>.from(m309defectsRaw) : {};

    final defects = <String, num>{};

    for (final key in {...m308defects.keys, ...m309defects.keys}) {
      final m308Val = m308defects[key] ?? 0;
      final m309Val = m309defects[key] ?? 0;
      defects[key] = (m308Val as num) + (m309Val as num);
    }

    // Fill missing categories with 0
    final filledDefects = {
      for (var key in allDefectCategories) key: (defects[key] ?? 0)
    };

    final chartMaxY =
        filledDefects.values.map((e) => e.toDouble()).fold<double>(0, max) + 5;

    final displayName = lineDisplayNames[selectedLine] ?? selectedLine;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.black.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$displayName,  QG2 ( M308 + M309 )',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              if (selectedRange != null)
                Text(
                  '${DateFormat("dd MMMM yyyy", "it_IT").format(selectedRange.start)} → ${DateFormat("dd MMMM yyyy", "it_IT").format(selectedRange.end)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                )
              else if (selectedDate != null)
                Text(
                  DateFormat("dd MMMM yyyy", "it_IT").format(selectedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildStatBox(
                      'Prodotti',
                      total,
                      const Color(0xFF007AFF),
                      Icons.precision_manufacturing_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatBox(
                      'OK',
                      okCount,
                      const Color(0xFF34C759),
                      Icons.check_circle_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatBox(
                      'KO',
                      koCount,
                      const Color(0xFFFF3B30),
                      Icons.cancel_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
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
              if (total > 0)
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
                          barGroups:
                              allDefectCategories.asMap().entries.map((entry) {
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
                                  backDrawRodData: BackgroundBarChartRodData(
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
            ],
          ),
        ),
      ),
    );
  }

  void _updateTime(TimeOfDay? start, TimeOfDay? end) {
    setState(() {
      selectedStartTime =
          start ?? TimeOfDay(hour: 0, minute: 0); // default to 00:00
      selectedEndTime =
          end ?? TimeOfDay(hour: 23, minute: 59); // default to 23:59
    });

    _fetchData().then((data) {
      if (mounted) {
        setState(() {
          _fetchedData = data;
        });
      }
    });
  }

  Widget _buildHeaderCard(
      double maxY, List<MapEntry<String, dynamic>> stations) {
    return ClipRRect(
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
              color: Colors.black.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 20,
                                color: Color(0xFF007AFF),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getDateTitle(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildDateSelectButton(),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedStartTime ??
                                  const TimeOfDay(hour: 0, minute: 0),
                            );
                            if (picked != null) {
                              _updateTime(picked, selectedEndTime);
                            }
                          },
                          child: _buildTimeContainer(
                            label: selectedStartTime != null
                                ? selectedStartTime!.format(context)
                                : 'Ora Inizio',
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedEndTime ??
                                  const TimeOfDay(hour: 23, minute: 59),
                            );
                            if (picked != null) {
                              _updateTime(selectedStartTime, picked);
                            }
                          },
                          child: _buildTimeContainer(
                            label: selectedEndTime != null
                                ? selectedEndTime!.format(context)
                                : 'Ora Fine',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildShiftToggleButtons(),
                const SizedBox(height: 24),
                SizedBox(
                  height: 250,
                  child: _buildProductionChart(maxY, stations),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeContainer({required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF007AFF).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF007AFF),
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildDateSelectButton() {
    return GestureDetector(
      onTap: _selectDateOrRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF007AFF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF007AFF).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.date_range_rounded,
              color: Color(0xFF007AFF),
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              "Seleziona Data",
              style: TextStyle(
                color: Color(0xFF007AFF),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftToggleButtons() {
    // iOS-style segmented control
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildShiftButton(0, "Giorno\nIntero"),
          _buildShiftButton(1, "Turno 1\n06:00-14:00"),
          _buildShiftButton(2, "Turno 2\n14:00-22:00"),
          _buildShiftButton(3, "Turno 3\n22:00-06:00"),
        ],
      ),
    );
  }

  Widget _buildShiftButton(int turno, String label) {
    final isSelected = selectedTurno == turno;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTurno = turno;
          });
          _fetchData().then((data) {
            if (mounted) {
              setState(() {
                _fetchedData = data;
              });
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductionChart(
      double maxY, List<MapEntry<String, dynamic>> stations) {
    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 16,
            tooltipBorder: BorderSide(color: Colors.grey.shade200, width: 1),
            tooltipPadding: const EdgeInsets.all(12),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final value = rod.toY.toInt();

              return BarTooltipItem(
                '',
                const TextStyle(),
                children: [
                  TextSpan(
                    text: value.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        barGroups: stations.asMap().entries.map<BarChartGroupData>((entry) {
          final idx = entry.key;
          final counts = entry.value.value as Map<String, dynamic>;
          final goodCount = (counts['good_count'] as int).toDouble();
          final badCount = (counts['bad_count'] as int).toDouble();

          return BarChartGroupData(
            x: idx,
            groupVertically: false,
            barRods: [
              BarChartRodData(
                toY: goodCount,
                color: const Color(0xFF34C759),
                width: 32,
                borderRadius: BorderRadius.circular(6),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: const Color(0xFF34C759).withOpacity(0.1),
                ),
              ),
              BarChartRodData(
                toY: badCount,
                color: const Color(0xFFFF3B30),
                width: 32,
                borderRadius: BorderRadius.circular(6),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: const Color(0xFFFF3B30).withOpacity(0.1),
                ),
              ),
            ],
            barsSpace: 8,
            showingTooltipIndicators: [
              0,
              1
            ], // 👈 ALWAYS show tooltips for both bars
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (double value, TitleMeta meta) {
                final entry = stations[value.toInt()];
                final label = entry.value['display'] ?? entry.key;
                return SideTitleWidget(
                  meta: meta,
                  space: 16,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
              dashArray: [4, 4],
            );
          },
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
