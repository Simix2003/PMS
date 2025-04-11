// ignore_for_file: deprecated_member_use, non_constant_identifier_names, library_private_types_in_public_api, avoid_web_libraries_in_flutter, use_build_context_synchronously, avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;
import '../../shared/services/api_service.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/object_result_card.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'dart:ui';

class FindPage extends StatefulWidget {
  const FindPage({super.key});

  @override
  _FindPageState createState() => _FindPageState();
}

class _FindPageState extends State<FindPage> {
  // Initially using a single date; if a range is selected, _selectedRange will be non-null
  String? selectedFilterType;
  String filterValue = '';
  DateTimeRange? selectedRange;
  DateTime? pickedDate;
  TimeOfDay? selectedStartTime;
  TimeOfDay? selectedEndTime;
  String? selectedRibbonSide;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _numericController = TextEditingController();
  bool isSelecting = false;
  final Set<String> selectedObjectIds = {};
  // Main selection for 'Difetto'
  String? selectedDifettoGroup;

// === GENERALI ===
  String? selectedGenerali;

// === SALDATURA ===
  String? selectedSaldaturaStringa;
  String? selectedSaldaturaSide;
  String? selectedSaldaturaPin;

// === DISALLINEAMENTO ===
  String? selectedDisallineamentoMode; // 'Stringa' or 'Ribbon'
  String? selectedDisallineamentoStringa;
  String? selectedDisallineamentoRibbonSide; // Lato F, M, B
  String? selectedDisallineamentoRibbon;

// === MANCANZA RIBBON ===
  String? selectedMancanzaRibbonSide; // Lato F, M, B
  String? selectedMancanzaRibbon;

// === MACCHIE ECA ===
  String? selectedMacchieECAStringa;

// === CELLE ROTTE ===
  String? selectedCelleRotteStringa;

// === LUNGHEZZA STRING RIBBON ===
  String? selectedLunghezzaStringa;

  final List<Map<String, String>> activeFilters = [];

  final List<String> filterOptions = [
    'Linea',
    'Stazione',
    'Esito',
    'Difetto',
    'ID Modulo',
    'Data',
    'Turno',
    "Stringatrice",
    'Operatore',
  ];

  final List<String> esitoOptions = [
    'OK',
    'KO',
    'In Produzione',
  ];

  final List<String> generaliOptions = [
    'Non Lavorato Poe Scaduto',
    'Non Lavorato da Telecamere',
    'Materiale Esterno su Celle',
    'Bad Soldering',
  ];

  final List<String> saldaturaOptions_1 = [
    'Stringa[1]',
    'Stringa[2]',
    'Stringa[3]',
    'Stringa[4]',
    'Stringa[5]',
    'Stringa[6]',
    'Stringa[7]',
    'Stringa[8]',
    'Stringa[9]',
    'Stringa[10]',
    'Stringa[11]',
    'Stringa[12]',
  ];

  final List<String> saldaturaOptions_2 = [
    'Lato F',
    'Lato M',
    'Lato B',
  ];

  final List<String> saldaturaOptions_3 = [
    'Pin[1]',
    'Pin[2]',
    'Pin[3]',
    'Pin[4]',
    'Pin[5]',
    'Pin[6]',
    'Pin[7]',
    'Pin[8]',
    'Pin[9]',
    'Pin[10]',
  ];

  final List<String> disallineamentoOptions_1 = ['Stringa', 'Ribbon'];

  final List<String> disallineamentoOptions_stringa = [
    'Stringa[1]',
    'Stringa[2]',
    'Stringa[3]',
    'Stringa[4]',
    'Stringa[5]',
    'Stringa[6]',
    'Stringa[7]',
    'Stringa[8]',
    'Stringa[9]',
    'Stringa[10]',
    'Stringa[11]',
    'Stringa[12]',
  ];

  final List<String> disallineamentoOptions_ribbon = [
    'Lato F',
    'Lato M',
    'Lato B',
  ];

  final List<String> disallineamentoOptions_ribbon_m = [
    'Ribbon[1]',
    'Ribbon[2]',
    'Ribbon[3]',
    'Ribbon[4]',
  ];

  final List<String> mancanzaRibbonOptions = [
    'Lato F',
    'Lato M',
    'Lato B',
  ];

  final List<String> mancanzaRibbonOptions_m = [
    'Ribbon[1]',
    'Ribbon[2]',
    'Ribbon[3]',
    'Ribbon[4]',
  ];

  final List<String> macchieECAOptions = [
    'Stringa[1]',
    'Stringa[2]',
    'Stringa[3]',
    'Stringa[4]',
    'Stringa[5]',
    'Stringa[6]',
    'Stringa[7]',
    'Stringa[8]',
    'Stringa[9]',
    'Stringa[10]',
    'Stringa[11]',
    'Stringa[12]',
  ];

  final List<String> celle_rotteOptions = [
    'Stringa[1]',
    'Stringa[2]',
    'Stringa[3]',
    'Stringa[4]',
    'Stringa[5]',
    'Stringa[6]',
    'Stringa[7]',
    'Stringa[8]',
    'Stringa[9]',
    'Stringa[10]',
    'Stringa[11]',
    'Stringa[12]',
  ];

  final List<String> lunghezzaStringRibbonOptions = [
    'Stringa[1]',
    'Stringa[2]',
    'Stringa[3]',
    'Stringa[4]',
    'Stringa[5]',
    'Stringa[6]',
    'Stringa[7]',
    'Stringa[8]',
    'Stringa[9]',
    'Stringa[10]',
    'Stringa[11]',
    'Stringa[12]',
  ];

  String? selectedOrderBy = 'Data';
  String? selectedLimit = '1000';
  String? selectedOrderDirection = 'Decrescente';

  final List<String> orderOptions = [
    'Data',
    'Esito',
    'ID Modulo',
    'Operatore',
    'Linea',
    'Stazione',
    'Tempo Ciclo',
  ];

  final List<String> limitOptions = ['100', '500', '1000', '5000'];
  final orderDirections = ['Crescente', 'Decrescente']; // A-Z / Z-A

  final List<Map<String, dynamic>> results = [];

  void _addFilter() {
    if (selectedFilterType == null) return;

    String compositeValue = '';

    if (selectedFilterType == 'Difetto') {
      if (selectedDifettoGroup == null) return;
      compositeValue = selectedDifettoGroup!;

      switch (selectedDifettoGroup) {
        case 'Generali':
          compositeValue += ' > ${selectedGenerali ?? ''}';
          break;

        case 'Saldatura':
          compositeValue += ' > ${selectedSaldaturaStringa ?? ''}';
          compositeValue += ' > ${selectedSaldaturaSide ?? ''}';
          compositeValue += ' > ${selectedSaldaturaPin ?? ''}';
          break;

        case 'Disallineamento':
          compositeValue += ' > ${selectedDisallineamentoMode ?? ''}';
          if (selectedDisallineamentoMode == 'Stringa') {
            compositeValue += ' > ${selectedDisallineamentoStringa ?? ''}';
            // Pad to 4 parts
            compositeValue += ' > ';
          } else if (selectedDisallineamentoMode == 'Ribbon') {
            compositeValue += ' > ${selectedDisallineamentoRibbonSide ?? ''}';
            compositeValue += ' > ${selectedDisallineamentoRibbon ?? ''}';
          } else {
            // pad both
            compositeValue += ' >  > ';
          }
          break;

        case 'Mancanza Ribbon':
          compositeValue += ' > ${selectedMancanzaRibbonSide ?? ''}';
          compositeValue += ' > ${selectedMancanzaRibbon ?? ''}';
          break;

        case 'Macchie ECA':
          compositeValue += ' > ${selectedMacchieECAStringa ?? ''}';
          break;

        case 'Celle Rotte':
          compositeValue += ' > ${selectedCelleRotteStringa ?? ''}';
          break;

        case 'Lunghezza String Ribbon':
          compositeValue += ' > ${selectedLunghezzaStringa ?? ''}';
          break;

        case 'Altro':
          // Optionally add extra input in the future
          compositeValue += ' > ';
          break;
      }
    } else if (selectedFilterType == 'Data') {
      if (selectedRange == null && pickedDate == null) return;

      DateTime? startDate;
      DateTime? endDate;

      if (selectedRange != null) {
        startDate = selectedRange!.start;
        endDate = selectedRange!.end;
      } else if (pickedDate != null) {
        startDate = pickedDate;
        endDate = pickedDate;
      }

      if (startDate != null && endDate != null) {
        final startDateTime = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          selectedStartTime?.hour ?? 0,
          selectedStartTime?.minute ?? 0,
        );

        final endDateTime = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          selectedEndTime?.hour ?? 23,
          selectedEndTime?.minute ?? 59,
        );

        compositeValue =
            '${DateFormat('dd MMM y – HH:mm').format(startDateTime)} → ${DateFormat('dd MMM y – HH:mm').format(endDateTime)}';

        setState(() {
          activeFilters.add({
            'type': 'Data',
            'value': compositeValue,
            'start': startDateTime.toIso8601String(),
            'end': endDateTime.toIso8601String(),
          });

          // Reset selections
          selectedFilterType = null;
          filterValue = '';
          selectedRange = null;
          pickedDate = null;
          selectedStartTime = null;
          selectedEndTime = null;
        });
      }

      return;
    } else {
      if (filterValue.isEmpty) return;
      compositeValue = filterValue;
    }

    if (compositeValue.isNotEmpty) {
      setState(() {
        activeFilters.add({
          'type': selectedFilterType!,
          'value': compositeValue,
        });

        // Reset all selections
        selectedFilterType = null;
        filterValue = '';
        selectedDifettoGroup = null;
        selectedGenerali = null;
        selectedSaldaturaStringa = null;
        selectedSaldaturaSide = null;
        selectedSaldaturaPin = null;
        selectedDisallineamentoMode = null;
        selectedDisallineamentoStringa = null;
        selectedDisallineamentoRibbonSide = null;
        selectedDisallineamentoRibbon = null;
        selectedMancanzaRibbonSide = null;
        selectedMancanzaRibbon = null;
        selectedMacchieECAStringa = null;
        selectedCelleRotteStringa = null;
        selectedLunghezzaStringa = null;
        _textController.clear();
        _numericController.clear();
      });
    }
  }

  void _removeFilter(int index) {
    setState(() {
      activeFilters.removeAt(index);
    });
  }

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

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String hint,
    bool isNumeric = false,
    required void Function(String) onChanged,
    double width = 150,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF).withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDynamicInput() {
    switch (selectedFilterType) {
      case 'Linea':
        return _buildStyledDropdown(
          hint: 'Linea',
          value: filterValue.isNotEmpty ? filterValue : null,
          items: ['Linea A', 'Linea B'],
          onChanged: (val) => setState(() => filterValue = val ?? ''),
        );

      case 'Stazione':
        return _buildStyledDropdown(
          hint: 'Stazione',
          value: filterValue.isNotEmpty ? filterValue : null,
          items: ['M308', 'M309', 'M326'],
          onChanged: (val) => setState(() => filterValue = val ?? ''),
        );

      case 'Esito':
        return _buildStyledDropdown(
          hint: 'Esito',
          value: filterValue.isNotEmpty ? filterValue : null,
          items: esitoOptions,
          onChanged: (val) => setState(() => filterValue = val ?? ''),
        );

      case 'Difetto':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dropdown: Select defect group
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
                'Lunghezza String Ribbon',
                'Altro',
              ],
              onChanged: (val) {
                setState(() {
                  selectedDifettoGroup = val;
                  // Reset all sub-selections
                  selectedGenerali = null;
                  selectedSaldaturaStringa = null;
                  selectedSaldaturaSide = null;
                  selectedSaldaturaPin = null;
                  selectedDisallineamentoMode = null;
                  selectedDisallineamentoStringa = null;
                  selectedDisallineamentoRibbonSide = null;
                  selectedDisallineamentoRibbon = null;
                  selectedMancanzaRibbonSide = null;
                  selectedMancanzaRibbon = null;
                  selectedMacchieECAStringa = null;
                  selectedCelleRotteStringa = null;
                  selectedLunghezzaStringa = null;
                });
              },
            ),
            const SizedBox(width: 12),

            // === GENERALI ===
            if (selectedDifettoGroup == 'Generali')
              _buildStyledDropdown(
                hint: 'Seleziona difetto Generale',
                value: selectedGenerali,
                items: generaliOptions,
                onChanged: (val) => setState(() => selectedGenerali = val),
              ),

            // === SALDATURA ===
            if (selectedDifettoGroup == 'Saldatura') ...[
              _buildStyledDropdown(
                hint: 'Stringa',
                value: selectedSaldaturaStringa,
                items: saldaturaOptions_1,
                onChanged: (val) =>
                    setState(() => selectedSaldaturaStringa = val),
              ),
              const SizedBox(width: 8),
              _buildStyledDropdown(
                hint: 'Lato',
                value: selectedSaldaturaSide,
                items: saldaturaOptions_2,
                onChanged: (val) => setState(() => selectedSaldaturaSide = val),
              ),
              const SizedBox(width: 8),
              _buildStyledDropdown(
                hint: 'Pin',
                value: selectedSaldaturaPin,
                items: saldaturaOptions_3,
                onChanged: (val) => setState(() => selectedSaldaturaPin = val),
              ),
            ],

            // === DISALLINEAMENTO ===
            if (selectedDifettoGroup == 'Disallineamento') ...[
              _buildStyledDropdown(
                hint: 'Tipo Disallineamento',
                value: selectedDisallineamentoMode,
                items: disallineamentoOptions_1,
                onChanged: (val) {
                  setState(() {
                    selectedDisallineamentoMode = val;
                    selectedDisallineamentoStringa = null;
                    selectedDisallineamentoRibbonSide = null;
                    selectedDisallineamentoRibbon = null;
                  });
                },
              ),
              const SizedBox(width: 8),
              _buildStyledDropdown(
                hint: 'Stringa',
                value: selectedDisallineamentoStringa,
                items: disallineamentoOptions_stringa,
                onChanged: (val) =>
                    setState(() => selectedDisallineamentoStringa = val),
              ),
              const SizedBox(width: 8),
              _buildStyledDropdown(
                hint: 'Lato',
                value: selectedDisallineamentoRibbonSide,
                items: disallineamentoOptions_ribbon,
                onChanged: (val) {
                  setState(() {
                    selectedDisallineamentoRibbonSide = val;
                    selectedDisallineamentoRibbon = null;
                  });
                },
              ),
              const SizedBox(width: 8),
              _buildStyledDropdown(
                hint: 'Ribbon',
                value: selectedDisallineamentoRibbon,
                items: disallineamentoOptions_ribbon_m,
                onChanged: (val) =>
                    setState(() => selectedDisallineamentoRibbon = val),
              ),
            ],

            // === MANCANZA RIBBON ===
            if (selectedDifettoGroup == 'Mancanza Ribbon') ...[
              _buildStyledDropdown(
                hint: 'Lato',
                value: selectedMancanzaRibbonSide,
                items: mancanzaRibbonOptions,
                onChanged: (val) {
                  setState(() {
                    selectedMancanzaRibbonSide = val;
                    selectedMancanzaRibbon = null;
                  });
                },
              ),
              const SizedBox(width: 8),
              _buildStyledDropdown(
                hint: 'Ribbon',
                value: selectedMancanzaRibbon,
                items: mancanzaRibbonOptions_m,
                onChanged: (val) =>
                    setState(() => selectedMancanzaRibbon = val),
              ),
            ],

            // === MACCHIE ECA ===
            if (selectedDifettoGroup == 'Macchie ECA')
              _buildStyledDropdown(
                hint: 'Stringa',
                value: selectedMacchieECAStringa,
                items: macchieECAOptions,
                onChanged: (val) =>
                    setState(() => selectedMacchieECAStringa = val),
              ),

            // === CELLE ROTTE ===
            if (selectedDifettoGroup == 'Celle Rotte')
              _buildStyledDropdown(
                hint: 'Stringa',
                value: selectedCelleRotteStringa,
                items: celle_rotteOptions,
                onChanged: (val) =>
                    setState(() => selectedCelleRotteStringa = val),
              ),

            // === LUNGHEZZA STRING RIBBON ===
            if (selectedDifettoGroup == 'Lunghezza String Ribbon')
              _buildStyledDropdown(
                hint: 'Stringa',
                value: selectedLunghezzaStringa,
                items: lunghezzaStringRibbonOptions,
                onChanged: (val) =>
                    setState(() => selectedLunghezzaStringa = val),
              ),
          ],
        );

      case 'ID Modulo':
        return _buildStyledTextField(
          controller: _textController,
          hint: 'Testo',
          onChanged: (val) => filterValue = val,
        );

      case 'Data':
        return Row(
          children: [
            GestureDetector(
              onTap: () async {
                final DateTime firstDate = DateTime(DateTime.now().year - 1);
                final DateTime lastDate = DateTime.now();

                final DateSelectionResult? result =
                    await _showCustomCalendarPicker(
                        context, firstDate, lastDate);

                if (result != null) {
                  setState(() {
                    pickedDate = result.singleDate;
                    selectedRange = result.range;

                    if (pickedDate != null) {
                      selectedRange = null;
                      filterValue = DateFormat('dd MMM y').format(pickedDate!);
                    } else if (selectedRange != null) {
                      pickedDate = null;
                      filterValue =
                          '${DateFormat('dd MMM y').format(selectedRange!.start)} → ${DateFormat('dd MMM y').format(selectedRange!.end)}';
                    }
                  });
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    Text(
                      filterValue.isEmpty ? "Seleziona Data" : filterValue,
                      style: const TextStyle(
                        color: Color(0xFF007AFF),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime:
                      selectedStartTime ?? TimeOfDay(hour: 0, minute: 0),
                );
                if (picked != null) {
                  setState(() => selectedStartTime = picked);
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
                  initialTime:
                      selectedEndTime ?? TimeOfDay(hour: 23, minute: 59),
                );
                if (picked != null) {
                  setState(() => selectedEndTime = picked);
                }
              },
              child: _buildTimeContainer(
                label: selectedEndTime != null
                    ? selectedEndTime!.format(context)
                    : 'Ora Fine',
              ),
            ),
          ],
        );

      case 'Turno':
        return _buildStyledDropdown(
          hint: 'Turno',
          value: filterValue.isNotEmpty ? filterValue : null,
          items: ['1', '2', '3'],
          onChanged: (val) => setState(() => filterValue = val ?? ''),
        );

      case 'Stringatrice':
        return _buildStyledDropdown(
          hint: 'Stringatrice',
          value: filterValue.isNotEmpty ? filterValue : null,
          items: ['1', '2', '3', '4', '5'],
          onChanged: (val) => setState(() => filterValue = val ?? ''),
        );

      case 'Operatore':
        return _buildStyledTextField(
          controller: _textController,
          hint: 'Testo',
          onChanged: (val) => filterValue = val,
        );

      default:
        return const SizedBox.shrink();
    }
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

  Future<DateSelectionResult?> _showCustomCalendarPicker(
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

    return showDialog<DateSelectionResult>(
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
                      Navigator.pop(context,
                          DateSelectionResult(singleDate: selectedDates[0]));
                    } else if (selectedDates.length == 2 &&
                        selectedDates[0] != null &&
                        selectedDates[1] != null) {
                      final range = DateTimeRange(
                        start: selectedDates[0]!,
                        end: selectedDates[1]!,
                      );
                      Navigator.pop(context, DateSelectionResult(range: range));
                    } else {
                      Navigator.pop(context, null);
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

  Widget _buildFilterRowCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;

        final filterDropdown = DropdownButton<String>(
          value: selectedFilterType,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF007AFF),
          ),
          underline: Container(), // Remove the default underline
          borderRadius: BorderRadius.circular(16),
          hint: const Text('Tipo Filtro'),
          items: filterOptions
              .map((f) => DropdownMenuItem(
                    value: f,
                    child: Text(
                      f,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              selectedFilterType = value;
              filterValue = '';
              _textController.clear();
              _numericController.clear();
              selectedRibbonSide = null;
            });
          },
        );

        final addButton = ElevatedButton(
          onPressed: _addFilter,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007AFF),
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 20),
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    filterDropdown,
                    const SizedBox(width: 12),
                    _buildDynamicInput(),
                    const Spacer(),
                    addButton,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: filterDropdown),
                        const SizedBox(width: 12),
                        addButton,
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDynamicInput(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade400)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    if (activeFilters.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(activeFilters.length, (index) {
        final f = activeFilters[index];
        return Chip(
          label: Text('${f['type']}: ${f['value']}'),
          backgroundColor: Colors.blue.shade50,
          deleteIcon: const Icon(Icons.close),
          onDeleted: () => _removeFilter(index),
        );
      }),
    );
  }

  void _onSearchPressed() async {
    setState(() => results.clear());

    try {
      final data = await ApiService.fetchSearchResults(
        filters: activeFilters,
        orderBy: selectedOrderBy,
        orderDirection: selectedOrderDirection,
        limit: selectedLimit,
      );

      setState(() {
        results.addAll(data);
      });
    } catch (e) {
      print("❌ Errore nel caricamento dei risultati: $e");
      // Show a Snackbar or Alert if needed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: const Text(
          'Ricerca Dati',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: results.isNotEmpty
            ? [
                if (isSelecting) ...[
                  TextButton(
                    onPressed: () {
                      setState(() => isSelecting = false);
                    },
                    child: const Text(
                      'Annulla',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedObjectIds
                            .addAll(results.map((r) => r['id_modulo']));
                      });
                    },
                    child: const Text(
                      'Seleziona Tutti',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedObjectIds.clear();
                      });
                    },
                    child: const Text(
                      'Deseleziona Tutti',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                  ),
                ],
                TextButton.icon(
                  onPressed: () {
                    if (isSelecting && selectedObjectIds.isNotEmpty) {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return ExportConfirmationDialog(
                            selectedCount: selectedObjectIds.length,
                            activeFilters: activeFilters,
                            onConfirm: () async {
                              final downloadUrl = await ApiService
                                  .exportSelectedObjectsAndGetDownloadUrl(
                                id_moduli: selectedObjectIds
                                    .map((id) => id.toString())
                                    .toList(),
                                filters: activeFilters,
                              );

                              if (downloadUrl != null) {
                                print(
                                    "📁 File pronto per il download: $downloadUrl");
                                setState(() => isSelecting = false);

                                if (kIsWeb) {
                                  html.window.open(downloadUrl, "_blank");
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            "File generato: $downloadUrl")),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Errore durante l'esportazione")),
                                );
                              }
                            },
                          );
                        },
                      );
                    } else {
                      // ✅ Entering selection mode: clear previous selections
                      setState(() {
                        isSelecting = true;
                        selectedObjectIds.clear();
                      });
                    }
                  },
                  icon: Icon(
                    isSelecting ? Icons.check_circle : Icons.download,
                    color: const Color(0xFF007AFF),
                  ),
                  label: Text(
                    isSelecting ? 'Fine selezione' : 'Esporta',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterRowCard(),
            if (activeFilters.isNotEmpty) _buildSectionTitle("Filtri Attivi"),
            if (activeFilters.isNotEmpty) _buildFilterChips(),
            const SizedBox(height: 20),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 1000;
                final controls = [
                  _buildStyledDropdown(
                    hint: 'Ordina per',
                    value: selectedOrderBy,
                    items: orderOptions,
                    onChanged: (val) {
                      setState(() => selectedOrderBy = val);
                      if (results.isNotEmpty) {
                        _onSearchPressed();
                      }
                    },
                    description: 'Ordina per',
                  ),
                  _buildStyledDropdown(
                    hint: '↑ ↓',
                    value: selectedOrderDirection,
                    items: orderDirections,
                    onChanged: (val) {
                      setState(() => selectedOrderDirection = val);
                      if (results.isNotEmpty) {
                        _onSearchPressed();
                      }
                    },
                  ),
                  _buildStyledDropdown(
                    hint: 'Limite',
                    value: selectedLimit,
                    items: limitOptions,
                    onChanged: (val) {
                      setState(() => selectedLimit = val);
                      if (results.isNotEmpty) {
                        _onSearchPressed();
                      }
                    },
                    description: 'Limita a',
                  ),
                  ElevatedButton.icon(
                    onPressed: _onSearchPressed,
                    icon: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 25,
                    ),
                    label: const Text("Cerca"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ];

                final countLabel = results.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(right: 12, bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${results.length} Elementi Visualizzati',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 20,
                                color: Colors.black87,
                              ),
                            ),
                            if (isSelecting)
                              Text(
                                '${selectedObjectIds.length} Elementi Selezionati',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                  color: Color(0xFF007AFF),
                                ),
                              ),
                          ],
                        ),
                      )
                    : const SizedBox();

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      countLabel,
                      const Spacer(),
                      ...controls.map((w) => Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: w,
                          )),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Align(alignment: Alignment.centerLeft, child: countLabel),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.end,
                        children: controls,
                      ),
                    ],
                  );
                }
              },
            ),

            _buildSectionTitle("Dati"),

            // 🧩 Cards Scrollable Area
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        'Nessun dato da mostrare',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ObjectResultCard(
                            data: results[index],
                            isSelectable: isSelecting,
                            isSelected: selectedObjectIds
                                .contains(results[index]['id_modulo']),
                            onTap: isSelecting
                                ? () {
                                    final id = results[index]['id_modulo'];
                                    setState(() {
                                      if (selectedObjectIds.contains(id)) {
                                        selectedObjectIds.remove(id);
                                      } else {
                                        selectedObjectIds.add(id);
                                      }
                                    });
                                  }
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class DateSelectionResult {
  final DateTime? singleDate;
  final DateTimeRange? range;

  const DateSelectionResult({this.singleDate, this.range});
}
