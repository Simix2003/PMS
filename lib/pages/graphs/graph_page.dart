// ignore_for_file: deprecated_member_use, must_be_immutable

import 'dart:ui';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../shared/models/globals.dart';
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
  String _granularity = 'Daily';

  // ─── static options ───
  final List<String> _granularityOptions = const ['Hourly', 'Daily', 'Shifts'];
  final Map<String, String> _granularityLabels = {
    'Hourly': 'Oraria',
    'Daily': 'Giornaliera',
    'Shifts': 'Turni',
  };

  bool _showShiftLines = true;
  bool _showDayLines = true;
  bool _showDayBackground = true;

  // LINES //Should get from MySQL : production_lines
  // STATIONS //Should get from MySQL : stations
  final Map<String, List<String>> _stationOptions = const {
    'Linea A': ['M308', 'M309', 'M326'],
    'Linea B': ['M308', 'M309', 'M326'],
    'Linea C': ['M308', 'M309', 'M326'],
  };
  final List<String> _metricOptions = const ['Esito', 'Yield', 'Difetto'];
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

  Future<void> _addSeries() async {
    // Do not proceed if essential fields are empty
    if (_selectedLine.isEmpty ||
        _selectedStation.isEmpty ||
        _selectedMetric.isEmpty) {
      _snack('Compila almeno linea, stazione e metrica');
      return;
    }

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
              value: _selectedValue.isNotEmpty ? _selectedValue : null,
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
                'Bad Soldering',
                'Altro',
              ],
              onChanged: (val) {
                setState(() => _selectedValue = val ?? '');
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
          items: lineOptions,
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

  void _showChartOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Impostazioni Grafico',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey.shade300),
                    const Text(
                      'Visualizzazione Oraria',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      title: const Text('Linee Turni (6:00 / 14:00 / 22:00)'),
                      value: _showShiftLines,
                      onChanged: (val) {
                        setState(() => _showShiftLines = val); // parent
                        setStateDialog(() {}); // local dialog
                      },
                      activeColor: const Color(0xFF007AFF),
                    ),
                    SwitchListTile.adaptive(
                      title: const Text('Sfondo Giorni Alterni'),
                      value: _showDayBackground,
                      onChanged: (val) {
                        setState(() => _showDayBackground = val);
                        setStateDialog(() {});
                      },
                      activeColor: const Color(0xFF007AFF),
                    ),
                    const SizedBox(height: 8),
                    Divider(color: Colors.grey.shade300),
                    const Text(
                      'Visualizzazione Giornaliera',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      title: const Text('Linee Cambio Giorno'),
                      value: _showDayLines,
                      onChanged: (val) {
                        setState(() => _showDayLines = val);
                        setStateDialog(() {});
                      },
                      activeColor: const Color(0xFF007AFF),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF007AFF),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Chiudi'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grafici'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.remove_red_eye),
          tooltip: 'Opzioni Grafico',
          onPressed: _showChartOptionsDialog,
        ),
        flexibleSpace: Padding(
          padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: _CompactFiltersBar(
              range: _selectedRange,
              startTime: _startTime,
              endTime: _endTime,
              granularity: _granularity,
              granOptions: _granularityOptions,
              granularityLabels: _granularityLabels,
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
              onRefreshRequested: _refreshAllSeries,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _seriesRowCard(),
            if (_seriesList.isNotEmpty) ...[
              _sectionTitle('Linee Attive'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _seriesList
                    .map((s) => InputChip(
                          avatar: CircleAvatar(
                              radius: 10, backgroundColor: s.color),
                          label: Text(s.name, overflow: TextOverflow.ellipsis),
                          onPressed: () async {
                            final c = await _pickColor(s.color);
                            if (c != null) setState(() => s.color = c);
                          },
                          onDeleted: () =>
                              setState(() => _seriesList.remove(s)),
                          deleteIcon: const Icon(Icons.close),
                          deleteIconColor: Colors.red,
                          backgroundColor: Colors.blue.withOpacity(.1),
                        ))
                    .toList(),
              ),
            ],
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
                      showShiftLines: _showShiftLines,
                      showDayLines: _showDayLines,
                      showDayBackground: _showDayBackground,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────── date picker helpers ───────────
  Future<void> _pickRange() async {
    final result = await _showCustomCalendarPicker(
      context,
      DateTime(2022), // first available date
      DateTime.now().add(const Duration(days: 365)), // last available date
    );

    final DateTimeRange? pickedRange = result?.$2;

    if (pickedRange != null) {
      setState(() => _selectedRange = pickedRange);
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
}

class _CompactFiltersBar extends StatelessWidget {
  final DateTimeRange range;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String granularity;
  final List<String> granOptions;
  final Map<String, String> granularityLabels;
  final Future<void> Function() onPickRange;
  final Future<void> Function() onPickStart;
  final Future<void> Function() onPickEnd;
  final Function(String) onGranChanged;
  final VoidCallback onRefreshRequested;

  const _CompactFiltersBar({
    required this.range,
    required this.startTime,
    required this.endTime,
    required this.granularity,
    required this.granOptions,
    required this.granularityLabels,
    required this.onPickRange,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onGranChanged,
    required this.onRefreshRequested,
  });

  String _formatDate(DateTime d) {
    final months = [
      'Gen',
      'Feb',
      'Mar',
      'Apr',
      'Mag',
      'Giu',
      'Lug',
      'Ago',
      'Set',
      'Ott',
      'Nov',
      'Dic'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Widget _buildStyledButton({
    required VoidCallback onTap,
    required IconData icon,
    required String text,
  }) {
    return GestureDetector(
      onTap: onTap,
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
            Icon(icon, color: const Color(0xFF007AFF), size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
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

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildStyledButton(
          onTap: () async {
            await onPickRange();
            onRefreshRequested();
          },
          icon: Icons.date_range_rounded,
          text: '${_formatDate(range.start)} → ${_formatDate(range.end)}',
        ),
        _buildStyledButton(
          onTap: () async {
            await onPickStart();
            onRefreshRequested();
          },
          icon: Icons.access_time_rounded,
          text: 'Inizio: ${startTime.format(context)}',
        ),
        _buildStyledButton(
          onTap: () async {
            await onPickEnd();
            onRefreshRequested();
          },
          icon: Icons.access_time_rounded,
          text: 'Fine: ${endTime.format(context)}',
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButton<String>(
                value: granularity,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF007AFF),
                ),
                underline: const SizedBox(),
                borderRadius: BorderRadius.circular(16),
                items: granOptions.map((g) {
                  return DropdownMenuItem(
                    value: g,
                    child: Text(
                      granularityLabels[g] ?? g,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (g) {
                  if (g != null) {
                    onGranChanged(g);
                    onRefreshRequested();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class GraphChartWidget extends StatefulWidget {
  const GraphChartWidget({
    super.key,
    required this.seriesList,
    required this.granularity,
    required this.panEnabled,
    required this.scaleEnabled,
    required this.controller,
    this.showShiftLines = true,
    this.showDayLines = true,
    this.showDayBackground = true,
  });

  final List<SeriesData> seriesList;
  final String granularity;
  final bool panEnabled;
  final bool scaleEnabled;
  final TransformationController controller;

  final bool showShiftLines; // <── NEW
  final bool showDayLines; // <── NEW
  final bool showDayBackground; // <── NEW

  @override
  State<GraphChartWidget> createState() => _GraphChartWidgetState();
}

class _GraphChartWidgetState extends State<GraphChartWidget> {
  double _labelInterval = 6;
  late VoidCallback _zoomListener;

  @override
  void initState() {
    super.initState();
    _zoomListener = () {
      final scale = widget.controller.value.getMaxScaleOnAxis();
      double newInterval;
      if (widget.granularity == 'Hourly') {
        newInterval = scale > 6
            ? 1
            : scale > 3
                ? 3
                : 12;
      } else if (widget.granularity == 'Daily') {
        newInterval = scale > 6
            ? 1
            : scale > 3
                ? 1
                : 1;
      }
      if (widget.granularity == 'Shifts') {
        newInterval = scale > 6
            ? 1
            : scale > 3
                ? 3
                : 12;
      } else {
        newInterval = scale > 6 ? 1 : 2;
      }
      if (_labelInterval != newInterval && mounted) {
        setState(() => _labelInterval = newInterval.toDouble());
      }
    };
    widget.controller.addListener(_zoomListener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_zoomListener);
    super.dispose();
  }

  List<VerticalLine> _buildShiftLines(List<DateTime> allTimes) {
    final List<VerticalLine> lines = [];

    for (int i = 1; i < allTimes.length; i++) {
      final baseTime = allTimes[i];

      // ─────── Real Shift Change Times for Hourly View ───────
      if ((widget.granularity == 'Hourly' &&
              [6, 14, 22].contains(baseTime.hour)) ||
          (widget.granularity == 'Shifts' &&
              [6, 14, 22].contains(baseTime.hour))) {
        if (!widget.showShiftLines) {
          continue; // optionally skip if toggle is off
        }
        lines.add(
          VerticalLine(
            x: i.toDouble(),
            color: Colors.blue.withOpacity(0.6),
            strokeWidth: 2,
            dashArray: [4, 4],
            label: VerticalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
              labelResolver: (_) {
                final hour = baseTime.hour;
                if (hour == 6) return '1';
                if (hour == 14) return '2';
                if (hour == 22) return '3';
                return '';
              },
            ),
          ),
        );
      }

      // ─────── Day Change Lines ───────
      if ((widget.granularity == 'Daily' || widget.granularity == 'Shifts') &&
          widget.showDayLines &&
          baseTime.day != allTimes[i - 1].day) {
        lines.add(
          VerticalLine(
            x: i.toDouble(),
            color: Colors.grey.shade700.withOpacity(0.6),
            strokeWidth: 1.5,
            dashArray: [4, 4],
          ),
        );
      }
    }

    return lines;
  }

  /// Generates alternating day shading in Hourly and Daily views.
  List<VerticalRangeAnnotation> _buildDayShading(List<DateTime> allTimes) {
    if (!widget.showDayBackground ||
        !(widget.granularity == 'Hourly' || widget.granularity == 'Daily')) {
      return [];
    }

    // Group indices by calendar day
    final Map<DateTime, List<int>> dayToIndices = {};
    for (var i = 0; i < allTimes.length; i++) {
      final d = DateTime(allTimes[i].year, allTimes[i].month, allTimes[i].day);
      dayToIndices.putIfAbsent(d, () => []).add(i);
    }

    bool shade = false;
    final List<VerticalRangeAnnotation> regions = [];
    for (final day in dayToIndices.keys.toList()..sort()) {
      final idxs = dayToIndices[day]!;
      final start = idxs.first.toDouble();
      final end = widget.granularity == 'Daily'
          ? start + 1.0 // Each day is one whole unit in Daily mode
          : idxs.last.toDouble() + 1.0;

      if (shade) {
        regions.add(VerticalRangeAnnotation(
          x1: start,
          x2: end,
          color: Colors.grey.withOpacity(0.1),
        ));
      }
      shade = !shade;
    }

    return regions;
  }

  @override
  Widget build(BuildContext context) {
    final seriesList = widget.seriesList;
    if (seriesList.isEmpty) return const Center(child: Text('Nessun dato'));

    // 1) Collect all times & values
    final allTimes = seriesList
        .expand((s) => s.points.map((p) => p.time))
        .toSet()
        .toList()
      ..sort();
    final allValues = seriesList.expand((s) => s.points.map((p) => p.value));

    // 2) Compute maxY + 5% and round up to nearest 10
    final maxValue =
        allValues.isNotEmpty ? allValues.reduce((a, b) => a > b ? a : b) : 0;
    final adjusted = maxValue + (maxValue * 0.05);
    final roundedMaxY = (adjusted / 10).ceil() * 10;

    // 3) Build each series' spots
    final bars = seriesList.map((s) {
      final spots = <FlSpot>[];
      for (var i = 0; i < allTimes.length; i++) {
        final t = allTimes[i];
        final pt = s.points.firstWhere(
            (e) => e.time.difference(t).inMinutes.abs() < 5,
            orElse: () => GraphPoint(time: t, value: 0));
        spots.add(FlSpot(i.toDouble(), pt.value));
      }
      return LineChartBarData(
        spots: spots,
        color: s.color,
        isCurved: true,
        preventCurveOverShooting: true,
        preventCurveOvershootingThreshold: 10.0,
        barWidth: 2,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [s.color.withOpacity(.3), s.color.withOpacity(0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      );
    }).toList();

    // 4) Optional Yield line
    if (seriesList.any((s) => s.metric == 'Yield')) {
      bars.add(LineChartBarData(
        spots: [FlSpot(0, 100), FlSpot(allTimes.length.toDouble() - 1, 100)],
        color: Colors.green,
        dashArray: [6, 4],
        barWidth: 1,
        dotData: FlDotData(show: false),
      ));
    }

    // 5) Prepare annotations
    final dayShading = _buildDayShading(allTimes);
    final shiftLines = _buildShiftLines(allTimes);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LineChart(
        transformationConfig: FlTransformationConfig(
          scaleAxis: FlScaleAxis.horizontal,
          minScale: 1,
          maxScale: 25,
          panEnabled: widget.panEnabled,
          scaleEnabled: widget.scaleEnabled,
          transformationController: widget.controller,
        ),
        LineChartData(
          maxY: roundedMaxY.toDouble(),
          minX: 0,
          maxX: allTimes.length.toDouble() - 1,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          rangeAnnotations: RangeAnnotations(
            verticalRangeAnnotations: dayShading,
          ),
          extraLinesData: ExtraLinesData(
            verticalLines: shiftLines,
          ),
          titlesData: FlTitlesData(
            // BOTTOM TITLES (hours / dates)
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                interval: widget.granularity == 'Shifts' ? 1 : _labelInterval,
                getTitlesWidget: (v, meta) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= allTimes.length) {
                    return const SizedBox();
                  }

                  final dt = allTimes[idx];
                  int inferShiftNumber(int hour) {
                    if (hour >= 6 && hour < 14) return 1;
                    if (hour >= 14 && hour < 22) return 2;
                    return 3;
                  }

                  final txt = switch (widget.granularity) {
                    'Hourly' => DateFormat('HH:mm').format(dt),
                    'Daily' => DateFormat('dd/MM').format(dt),
                    'Shifts' =>
                      'T${inferShiftNumber(dt.hour)}\n${DateFormat('dd/MM').format(dt)}',
                    _ => DateFormat('dd/MM').format(dt),
                  };

                  return SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: Transform.rotate(
                      angle: -0.7854,
                      child: Text(txt, style: const TextStyle(fontSize: 10)),
                    ),
                  );
                },
              ),
            ),

            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: widget.granularity == 'Hourly',
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= allTimes.length) {
                    return const SizedBox();
                  }
                  final dt = allTimes[idx];
                  if (dt.hour == 0) {
                    return SideTitleWidget(
                      meta: meta,
                      space: 6,
                      child: Text(
                        '${dt.day}/${dt.month}',
                        style: const TextStyle(
                          fontSize: 12, // ← increase this (was 10)
                          fontWeight: FontWeight.w700,
                          color: Colors.black87, // optional for better contrast
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),

            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 52),
            ),
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
