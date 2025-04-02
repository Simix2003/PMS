// ignore_for_file: deprecated_member_use, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../shared/services/api_service.dart';
import '../../shared/services/socket_service.dart';
import '../../shared/widgets/station_card.dart';

class DataViewPage extends StatefulWidget {
  const DataViewPage({super.key});

  @override
  _DataViewPageState createState() => _DataViewPageState();
}

class _DataViewPageState extends State<DataViewPage> {
  final WebSocketService _webSocketService = WebSocketService();
  late Future<Map<String, dynamic>> _dataFuture;

  // Initially using a single date; if a range is selected, _selectedRange will be non-null
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _selectedRange;

  // Using 0 to represent “Full Day” and 1, 2, 3 for the three shifts.
  // Default is full day.
  int selectedTurno = 0;

  String selectedLine = "Linea1";
  final List<String> availableLines = ["Linea1", "Linea2"];
  final Map<String, String> lineDisplayNames = {
    'Linea1': 'Linea A',
    'Linea2': 'Linea B',
  };

  final Map<String, String> stationDisplayNames = {
    'M308': 'M308 - QG2 di M306',
    'M309': 'M309 - QG2 di M307',
    'M326': 'M326 - RW1',
  };

  @override
  void initState() {
    super.initState();
    _initializeWebSocket(); // Initialize WebSocket connection
    _dataFuture = _fetchData();
  }

  @override
  void dispose() {
    _webSocketService.close();
    super.dispose();
  }

  void _initializeWebSocket() {
    _webSocketService.connectToSummary(
      selectedLine: selectedLine,
      onMessage: () {
        if (mounted) {
          setState(() {
            _dataFuture = _fetchData();
          });
        }
      },
    );
  }

  // Handle line change (update WebSocket connection and fetch new data)
  void _onLineChange(String? newLine) {
    if (newLine != null && newLine != selectedLine) {
      setState(() {
        selectedLine = newLine;
        _initializeWebSocket();
        _dataFuture = _fetchData();
      });
    }
  }

  Future<Map<String, dynamic>> _fetchData() {
    return ApiService.fetchProductionSummary(
      selectedLine: selectedLine,
      singleDate: _selectedDate,
      range: _selectedRange,
      selectedTurno: selectedTurno,
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

    setState(() {
      if (pickedDate != null) {
        _selectedDate = pickedDate;
        _selectedRange = null;
      } else if (pickedRange != null) {
        _selectedDate = pickedRange.start;
        _selectedRange = pickedRange;
      }
      _dataFuture = _fetchData();
    });
  }

  Future<(DateTime?, DateTimeRange?)?> _showCustomCalendarPicker(
      BuildContext context, DateTime firstDate, DateTime lastDate) async {
    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color cardColor = Theme.of(context).cardColor;
    final Color textColor = Theme.of(context).textTheme.bodyLarge!.color!;

    List<DateTime?> selectedDates = [];

    final config = CalendarDatePicker2WithActionButtonsConfig(
      calendarType: CalendarDatePicker2Type.range,
      selectedDayHighlightColor: primaryColor,
      selectedRangeHighlightColor: primaryColor.withOpacity(0.2),
      daySplashColor: primaryColor,
      weekdayLabelTextStyle: TextStyle(color: textColor),
      controlsTextStyle: TextStyle(color: textColor),
      dayTextStyle: TextStyle(color: textColor),
      disabledDayTextStyle: TextStyle(color: textColor.withOpacity(0.4)),
      yearTextStyle: TextStyle(color: textColor),
    );

    return showDialog<(DateTime?, DateTimeRange?)>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          surfaceTintColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: cardColor,
          child: Container(
            padding: const EdgeInsets.all(16),
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Analisi Dati',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                const Text("Linea: ",
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: selectedLine,
                  icon: const Icon(Icons.arrow_drop_down),
                  items: availableLines.map((line) {
                    return DropdownMenuItem(
                      value: line,
                      child: Text(lineDisplayNames[line] ?? line),
                    );
                  }).toList(),
                  onChanged: (newLine) {
                    if (newLine != null && newLine != selectedLine) {
                      setState(() {
                        selectedLine = newLine;
                        _onLineChange(selectedLine);
                        _dataFuture = _fetchData();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          } else {
            final data = snapshot.data!;
            final stations = ['M308', 'M309', 'M326'];

            final maxY = stations.map((station) {
                  final counts =
                      data['stations'][station] as Map<String, dynamic>;
                  return (counts['good_count'] as int) +
                      (counts['bad_count'] as int);
                }).reduce((a, b) => a > b ? a : b) +
                20;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📅 Header Card with Chart and Date Picker Button
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _getDateTitle(),
                                style: const TextStyle(
                                    fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: [
                                  // ToggleButtons for Full Day and Shifts
                                  ToggleButtons(
                                    isSelected: [0, 1, 2, 3]
                                        .map((turno) => selectedTurno == turno)
                                        .toList(),
                                    onPressed: (index) {
                                      setState(() {
                                        // Here, 0 represents “Full Day”
                                        selectedTurno = index;
                                        _dataFuture = _fetchData();
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    children: const [
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text("Giorno\nIntero",
                                            textAlign: TextAlign.center),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text("Turno 1\n06:00 - 14:00",
                                            textAlign: TextAlign.center),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text("Turno 2\n14:00 - 22:00",
                                            textAlign: TextAlign.center),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text("Turno 3\n22:00 - 06:00",
                                            textAlign: TextAlign.center),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 20),
                                  // Single button for date (or date range) selection
                                  ElevatedButton.icon(
                                    onPressed: _selectDateOrRange,
                                    icon: const Icon(Icons.date_range),
                                    label: const Text("Seleziona Data"),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.blueAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 220,
                            child: BarChart(
                              BarChartData(
                                maxY: maxY.toDouble(),
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    tooltipBorder:
                                        BorderSide(color: Colors.grey.shade300),
                                    getTooltipItem:
                                        (group, groupIndex, rod, rodIndex) {
                                      return BarTooltipItem(
                                        rod.toY.toInt().toString(),
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                barGroups:
                                    stations.asMap().entries.map((entry) {
                                  final station = entry.value;
                                  final idx = entry.key;
                                  final counts = data['stations'][station]
                                      as Map<String, dynamic>;
                                  return BarChartGroupData(
                                    x: idx,
                                    barRods: [
                                      BarChartRodData(
                                        toY: (counts['good_count'] as int)
                                            .toDouble(),
                                        color: Colors.green,
                                        width: 20,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      BarChartRodData(
                                        toY: (counts['bad_count'] as int)
                                            .toDouble(),
                                        color: Colors.red,
                                        width: 20,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                    showingTooltipIndicators: [0, 1],
                                    barsSpace: 25,
                                  );
                                }).toList(),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 48,
                                      getTitlesWidget:
                                          (double value, TitleMeta meta) {
                                        final stationCode =
                                            stations[value.toInt()];
                                        final label =
                                            stationDisplayNames[stationCode] ??
                                                stationCode;
                                        return SizedBox(
                                          width: 100,
                                          child: Text(
                                            label,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
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
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          value.toInt().toString(),
                                          style: const TextStyle(fontSize: 12),
                                          textAlign: TextAlign.center,
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  horizontalInterval: 10,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: Colors.grey.withOpacity(0.3),
                                      strokeWidth: 1,
                                      dashArray: [4, 4],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ...stations.map((station) {
                    final stationData =
                        data['stations'][station] as Map<String, dynamic>;
                    final visualName = stationDisplayNames[station] ?? station;
                    return StationCard(
                        station: visualName, stationData: stationData);
                  }).toList(),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
