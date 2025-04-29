// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../shared/services/api_service.dart';

// ───────────────────────────────────────────────── data models ───────────────
class GraphPoint {
  final DateTime time;
  final double value;
  GraphPoint({required this.time, required this.value});
  factory GraphPoint.fromJson(Map<String, dynamic> j) => GraphPoint(
        time: DateTime.parse(j['timestamp']),
        value: (j['value'] as num).toDouble(),
      );
}

class SeriesData {
  final String line;
  final String station;
  final String metric;
  final String? extraFilter; // <==== NEW
  List<GraphPoint> points;
  Color color;

  SeriesData({
    required this.line,
    required this.station,
    required this.metric,
    this.extraFilter, // <=== NEW
    required this.points,
    required this.color,
  });

  String get name {
    if (extraFilter != null && extraFilter!.isNotEmpty) {
      return '$line / $station / $metric / $extraFilter';
    }
    return '$line / $station / $metric';
  }
}

// ───────────────────────────────────────────────── GraphPage ────────────────
class GraphPage extends StatefulWidget {
  const GraphPage({super.key});
  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  // ─── date range state ───
  late DateTimeRange _selectedRange;
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 59);

  // ─── series‑builder state ───
  String _selectedLine = '';
  String _selectedStation = '';
  String _selectedMetric = '';
  String _selectedValue = '';

  // ─── chart state ───
  bool _loading = false;
  final List<SeriesData> _seriesList = [];
  late final TransformationController _tController;
  String _granularity = 'Hourly';

  // ─── static options ───
  final List<String> _granularityOptions = const ['Hourly', 'Daily', 'Weekly'];
  final List<String> _lineOptions = const ['Linea A', 'Linea B', 'Linea C'];
  final Map<String, List<String>> _stationOptions = const {
    'Linea A': ['M308', 'M309', 'M326'],
    'Linea B': ['M308', 'M309', 'M326'],
    'Linea C': ['M308', 'M309', 'M326'],
  };
  final List<String> _metricOptions = const [
    'Esito',
    'Tempo Ciclo',
    'Yield',
    'Difetto'
  ];
  final List<String> esitoOptions = [
    'G',
    'NG',
    'Escluso',
    'In Produzione',
    'G Operatore',
  ];
  String? selectedDifettoGroup;

  String? selectedCycleTimeCondition;
  // ───────────────────────────────────────────── lifecycle ────────────────
  @override
  void initState() {
    super.initState();
    _tController = TransformationController();

    // default: last 7 complete days (00:00 – 23:59)
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 1));
    _selectedRange = DateTimeRange(
      start: yesterday.subtract(const Duration(days: 6)),
      end: yesterday.add(const Duration(hours: 23, minutes: 59)),
    );
  }

  @override
  void dispose() {
    _tController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────── series helpers ────────────────
  Future<void> _addSeries() async {
    setState(() => _loading = true);

    try {
      final pts = await _fetchSeriesPoints(
        line: _selectedLine,
        station: _selectedStation,
        metric: _selectedMetric,
        extraFilter: _selectedValue,
      );

      final color =
          Colors.primaries[_seriesList.length % Colors.primaries.length];

      setState(() {
        _seriesList.add(SeriesData(
          line: _selectedLine,
          station: _selectedStation,
          metric: _selectedMetric,
          extraFilter: _selectedValue.isNotEmpty ? _selectedValue : null,
          points: pts,
          color: color,
        ));

        _selectedLine = '';
        _selectedStation = '';
        _selectedMetric = '';
        _selectedValue = '';
      });
    } catch (e) {
      _snack('Errore: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<List<GraphPoint>> _fetchSeriesPoints({
    required String line,
    required String station,
    required String metric,
    String? extraFilter,
  }) async {
    final start = _selectedRange.start
        .copyWith(hour: _startTime.hour, minute: _startTime.minute);
    final end = _selectedRange.end
        .copyWith(hour: _endTime.hour, minute: _endTime.minute);

    final raw = await ApiService.fetchGraphData(
      line: line,
      station: station,
      start: start.toIso8601String(),
      end: end.toIso8601String(),
      metrics: [metric],
      groupBy: _granularity.toLowerCase(),
      extraFilter: extraFilter,
    );

    print('Fetched raw data for $metric with filter $extraFilter: $raw');

    final key =
        (extraFilter != null && extraFilter.isNotEmpty) ? extraFilter : metric;
    final list = raw[key];

    return (list is List)
        ? list
            .map((e) => GraphPoint.fromJson(e as Map<String, dynamic>))
            .toList()
        : <GraphPoint>[];
  }

  Future<void> _refreshAllSeries() async {
    if (_seriesList.isEmpty) {
      _snack('Aggiungi almeno una serie');
      return;
    }
    setState(() => _loading = true);
    for (final s in _seriesList) {
      try {
        s.points = await _fetchSeriesPoints(
          line: s.line,
          station: s.station,
          metric: s.metric,
          extraFilter: s.extraFilter,
        );
      } catch (e) {
        _snack('Errore su ${s.name}: $e');
      }
    }
    setState(() => _loading = false);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<Color?> _pickColor(Color current) async {
    return showDialog<Color>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Seleziona Colore'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Colors.primaries
                .map((c) => GestureDetector(
                      onTap: () => Navigator.pop(context, c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: c == current
                                  ? Colors.black
                                  : Colors.transparent,
                              width: 2),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'))
        ],
      ),
    );
  }

  // ──────────────────────────────────────────── UI widgets ────────────────
  Widget _buildStyledDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String description = '',
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (description.isNotEmpty) ...[
          Text(
            "$description:",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButton<String>(
            value: value,
            hint: Text(hint),
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF007AFF)),
            underline: Container(),
            borderRadius: BorderRadius.circular(16),
            items: items
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget? _buildDynamicInput() {
    switch (_selectedMetric) {
      case 'Esito':
        return _buildStyledDropdown(
          hint: 'Esito',
          value: _selectedValue.isNotEmpty ? _selectedValue : null,
          items: esitoOptions,
          onChanged: (val) => setState(() => _selectedValue = val ?? ''),
        );

      case 'Difetto':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStyledDropdown(
              hint: 'Gruppo Difetto',
              value: selectedDifettoGroup,
              items: [
                'Generali',
                'Saldatura',
                'Disallineamento',
                'Mancanza Ribbon',
                'Macchie ECA',
                'Celle Rotte',
                'I Ribbon Leadwire',
                'Lunghezza String Ribbon',
                'Graffio su Cella',
                'Altro',
              ],
              onChanged: (val) {
                setState(() {
                  selectedDifettoGroup = val;
                });
              },
            ),
          ],
        );

      default:
        return null; // <== nothing shown if not a special metric
    }
  }

  Widget _seriesRowCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;

        final lineDrop = _styledDropdown(
          hint: 'Linea',
          value: _selectedLine.isNotEmpty ? _selectedLine : null,
          items: _lineOptions,
          onChanged: (v) => setState(() {
            _selectedLine = v!;
            _selectedStation = '';
          }),
        );

        final stationDrop = _styledDropdown(
          hint: 'Stazione',
          value: _selectedStation.isNotEmpty ? _selectedStation : null,
          items:
              _selectedLine.isNotEmpty ? _stationOptions[_selectedLine]! : [],
          onChanged: (v) => setState(() => _selectedStation = v ?? ''),
        );

        final metricDrop = _styledDropdown(
          hint: 'Tipo',
          value: _selectedMetric.isNotEmpty ? _selectedMetric : null,
          items: _metricOptions,
          onChanged: (v) => setState(() => _selectedMetric = v!),
        );

        final dynamicInput = _buildDynamicInput();

        final addButton = ElevatedButton(
          onPressed: _loading ? null : _addSeries,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007AFF),
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 20),
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    lineDrop,
                    const SizedBox(width: 12),
                    stationDrop,
                    const SizedBox(width: 12),
                    metricDrop,
                    if (dynamicInput != null) ...[
                      const SizedBox(width: 12),
                      dynamicInput,
                    ],
                    const Spacer(),
                    addButton,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: lineDrop),
                        const SizedBox(width: 12),
                        addButton,
                      ],
                    ),
                    const SizedBox(height: 12),
                    stationDrop,
                    const SizedBox(height: 12),
                    metricDrop,
                    if (dynamicInput != null) ...[
                      const SizedBox(height: 12),
                      dynamicInput,
                    ],
                  ],
                ),
        );
      },
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      );

  Widget _styledDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String description = '',
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (description.isNotEmpty) ...[
          Text(
            "$description:",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButton<String>(
            value: value,
            hint: Text(
              hint,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF007AFF), // <=== fix hint text color!
              ),
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF007AFF)),
            underline: Container(),
            borderRadius: BorderRadius.circular(16),
            items: items
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String txt) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Row(children: [
          Expanded(child: Divider(color: Colors.grey.shade400)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(txt,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700))),
          Expanded(child: Divider(color: Colors.grey.shade400)),
        ]),
      );

  // ─────────────────────────────────────────────── build ────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Graph Page'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── date / granularity card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: _FiltersBar(
              range: _selectedRange,
              startTime: _startTime,
              endTime: _endTime,
              granularity: _granularity,
              granOptions: _granularityOptions,
              onPickRange: _pickRange,
              onPickStart: () async {
                final t = await showTimePicker(
                    context: context, initialTime: _startTime);
                if (t != null) setState(() => _startTime = t);
              },
              onPickEnd: () async {
                final t = await showTimePicker(
                    context: context, initialTime: _endTime);
                if (t != null) setState(() => _endTime = t);
              },
              onGranChanged: (g) => setState(() => _granularity = g),
            ),
          ),

          const SizedBox(height: 16),
          _seriesRowCard(),

          if (_seriesList.isNotEmpty) ...[
            _sectionTitle('Dati Attivi'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _seriesList
                  .map((s) => InputChip(
                        avatar:
                            CircleAvatar(radius: 10, backgroundColor: s.color),
                        label: Text(s.name, overflow: TextOverflow.ellipsis),
                        onPressed: () async {
                          final c = await _pickColor(s.color);
                          if (c != null) setState(() => s.color = c);
                        },
                        onDeleted: () => setState(() => _seriesList.remove(s)),
                        deleteIcon: const Icon(Icons.close),
                        deleteIconColor: Colors.red,
                        backgroundColor: Colors.blue.withOpacity(.1),
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : _refreshAllSeries,
            child: Text(_loading ? 'Loading…' : 'Visualizza'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : GraphChartWidget(
                    seriesList: _seriesList,
                    granularity: _granularity,
                    panEnabled: true,
                    scaleEnabled: true,
                    controller: _tController,
                  ),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────── date picker helpers ───────────
  Future<void> _pickRange() async {
    List<DateTime?> tmp = [_selectedRange.start, _selectedRange.end];
    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => Dialog(
        child: CalendarDatePicker2WithActionButtons(
          value: tmp,
          config: CalendarDatePicker2WithActionButtonsConfig(
            calendarType: CalendarDatePicker2Type.range,
            firstDayOfWeek: 1,
          ),
          onValueChanged: (v) => tmp = v,
          onOkTapped: () {
            if (tmp.length == 2 && tmp[0] != null && tmp[1] != null) {
              Navigator.pop(
                  context, DateTimeRange(start: tmp[0]!, end: tmp[1]!));
            } else {
              Navigator.pop(context);
            }
          },
          onCancelTapped: () => Navigator.pop(context),
        ),
      ),
    );
    if (picked != null) setState(() => _selectedRange = picked);
  }
}

// ────────────────────────────────────────────── FiltersBar ────────────────
class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.range,
    required this.startTime,
    required this.endTime,
    required this.granularity,
    required this.granOptions,
    required this.onPickRange,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onGranChanged,
  });
  final DateTimeRange range;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String granularity;
  final List<String> granOptions;
  final VoidCallback onPickRange;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final ValueChanged<String> onGranChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(Widget child) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withOpacity(.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: child,
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        chip(TextButton(
            onPressed: onPickRange,
            child: Text(
                '${DateFormat('dd MMM yyyy').format(range.start)} ${startTime.format(context)} → ${DateFormat('dd MMM yyyy').format(range.end)} ${endTime.format(context)}'))),
        const SizedBox(width: 8),
        chip(TextButton(
            onPressed: onPickStart,
            child: Text('Start: ${startTime.format(context)}'))),
        const SizedBox(width: 8),
        chip(TextButton(
            onPressed: onPickEnd,
            child: Text('End: ${endTime.format(context)}'))),
        const SizedBox(width: 8),
        chip(DropdownButton<String>(
          value: granularity,
          underline: const SizedBox(),
          items: granOptions
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: (v) => onGranChanged(v!),
        )),
      ]),
    );
  }
}

// ───────────────────────────────────────────── Chart widget ────────────────
class GraphChartWidget extends StatelessWidget {
  const GraphChartWidget({
    super.key,
    required this.seriesList,
    required this.granularity,
    required this.panEnabled,
    required this.scaleEnabled,
    required this.controller,
  });
  final List<SeriesData> seriesList;
  final String granularity;
  final bool panEnabled;
  final bool scaleEnabled;
  final TransformationController controller;

  List<VerticalLine> _buildShiftLines(List<DateTime> allTimes) {
    List<VerticalLine> lines = [];

    for (int i = 0; i < allTimes.length; i++) {
      final time = allTimes[i];

      // Only apply if granularity is Hourly or Daily
      if (granularity == 'Hourly' || granularity == 'Daily') {
        final hour = time.hour;

        if (hour == 6 || hour == 14 || hour == 22) {
          lines.add(
            VerticalLine(
              x: i.toDouble(),
              color: Colors.blue.withOpacity(0.6),
              strokeWidth: 2,
              dashArray: [4, 4],
            ),
          );
        }
      }
    }

    return lines;
  }

  @override
  Widget build(BuildContext context) {
    if (seriesList.isEmpty) return const Center(child: Text('Nessun dato'));

    final allTimes = seriesList
        .expand((s) => s.points.map((p) => p.time))
        .toSet()
        .toList()
      ..sort();

    List<LineChartBarData> bars = [];
    for (final s in seriesList) {
      bars.add(LineChartBarData(
        spots: allTimes.mapIndexed((i, t) {
          final p = s.points.firstWhere(
            (e) =>
                e.time.difference(t).inMinutes.abs() <
                5, // allow small difference
            orElse: () => GraphPoint(time: t, value: 0),
          );
          return FlSpot(i.toDouble(), p.value);
        }).toList(),
        color: s.color,
        isCurved: false,
        barWidth: 2,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
                colors: [s.color.withOpacity(.3), s.color.withOpacity(0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter)),
      ));
    }

    if (seriesList.any((s) => s.metric == 'Yield')) {
      bars.add(LineChartBarData(
        spots: [FlSpot(0, 100), FlSpot(allTimes.length.toDouble() - 1, 100)],
        color: Colors.lime,
        dashArray: [6, 4],
        barWidth: 1,
        dotData: FlDotData(show: false),
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LineChart(
        transformationConfig: FlTransformationConfig(
          scaleAxis: FlScaleAxis.horizontal,
          minScale: 1,
          maxScale: 25,
          panEnabled: panEnabled,
          scaleEnabled: scaleEnabled,
          transformationController: controller,
        ),
        LineChartData(
          minX: 0,
          maxX: allTimes.length.toDouble() - 1,
          gridData: FlGridData(show: true),
          extraLinesData: ExtraLinesData(
            verticalLines: _buildShiftLines(allTimes),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= allTimes.length) {
                        return const SizedBox();
                      }
                      final dt = allTimes[idx];
                      final txt = granularity == 'Hourly'
                          ? DateFormat('HH:mm').format(dt)
                          : DateFormat('dd/MM').format(dt);
                      return SideTitleWidget(
                          meta: meta,
                          child: Transform.rotate(
                              angle: -45 * 3.1416 / 180,
                              child: Text(txt,
                                  style: const TextStyle(fontSize: 10))));
                    })),
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 52)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(handleBuiltInTouches: true),
          lineBarsData: bars,
        ),
        duration: Duration.zero,
      ),
    );
  }
}

// ────────────────────────────────────────────── ext helpers ────────────────
extension _MapIndexed<E> on Iterable<E> {
  Iterable<T> mapIndexed<T>(T Function(int i, E e) f) {
    var i = 0;
    return map((e) => f(i++, e));
  }
}
