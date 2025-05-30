// ignore_for_file: deprecated_member_use, non_constant_identifier_names, library_private_types_in_public_api, avoid_web_libraries_in_flutter, use_build_context_synchronously, avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ix_monitor/pages/settings_page.dart';
import 'dart:html' as html;
//import '../ai_helper_chat.dart';
import '../../shared/models/globals.dart';
import '../manuali/manualSelection_page.dart';
import '../object_details/mbjDetails_page.dart';
import '../object_details/objectDetails_page.dart';
import '../object_details/productionDetails_page.dart';
import '../../shared/services/api_service.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/object_result_card.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'dart:ui';
//import 'package:rive/rive.dart';

class FindPage extends StatefulWidget {
  final List<Map<String, String>>? initialFilters;
  final bool autoSearch;
  final VoidCallback? onSearchCompleted;

  const FindPage({
    super.key,
    this.initialFilters,
    this.autoSearch = false,
    this.onSearchCompleted,
  });

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
  final TextEditingController _eventiController = TextEditingController();
  bool isSelecting = false;
  final Set<String> selectedObjectIds = {}; // Main selection for 'Difetto'
  String? selectedDifettoGroup;
  bool isExporting = false;
  bool searching = false;

  String? selectedCycleTimeCondition;

  String? selectedEventiCondition;

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

// === I RIBBON LEADWIRE ===
  String? selectedLeadwireRibbonSide; // Lato M
  String? selectedLeadwireRibbon;

// === MACCHIE ECA ===
  String? selectedMacchieECAStringa;

// === CELLE ROTTE ===
  String? selectedCelleRotteStringa;

// === GRAFFIO SU CELLA ===
  String? selectedGraffioSuCellaStringa;

// === BAD SOLDERING ===
  String? selectedBadSolderingStringa;

// === LUNGHEZZA STRING RIBBON ===
  String? selectedLunghezzaStringa;

  final List<Map<String, String>> activeFilters = [];

  //Artboard? _riveArtboard;
  //SMIBool? _boolInput;

  final List<String> filterOptions = [
    'Data',
    'Difetto',
    'Esito',
    'Eventi',
    'ID Modulo',
    'Linea',
    'Operatore',
    'Stazione',
    'Stringatrice',
    'Tempo Ciclo',
    'Turno',
  ];

  final List<String> esitoOptions = [
    'G',
    'NG',
    'Escluso',
    'In Produzione',
    'G Operatore',
  ];

  final List<String> generaliOptions = [
    'Non Lavorato Poe Scaduto',
    'No Good da Bussing',
    'Materiale Esterno su Celle',
    'Passthrough al Bussing',
    'Poe in Eccesso',
    'Solo Poe',
    'Solo Vetro',
    'Matrice Incompleta',
    'Molteplici Bus Bar',
    'Test'
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

  final List<String> badSolderingOptions = [
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

  final List<String> leadwireRibbonOptions = [
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

  final List<String> graffioSuCellaOptions = [
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

  Map<String, List<String>> moduloIdToProductionIds = {};

  final List<String> orderOptions = [
    'Data',
    'Esito',
    'ID Modulo',
    'Operatore',
    'Linea',
    'Stazione',
    'Tempo Ciclo',
  ];

  final List<String> limitOptions = [
    '100',
    '500',
    '1000',
    '5000',
    '10000',
    '50000'
  ];
  final orderDirections = ['Crescente', 'Decrescente']; // A-Z / Z-A
  String? selectedOrderDirection = 'Decrescente';

  final List<Map<String, dynamic>> results = [];
  double _thresholdSeconds = 3;

  @override
  void initState() {
    super.initState();

    _loadSettings();

    /*rootBundle.load('rive/logo_interaction.riv').then(
      (data) async {
        final file = RiveFile.import(data);
        final artboard = file.mainArtboard;

        final controller =
            StateMachineController.fromArtboard(artboard, 'State Machine 1');
        if (controller != null) {
          artboard.addController(controller);
          _boolInput = controller.findInput<bool>('hvr ic') as SMIBool?;
        }

        setState(() => _riveArtboard = artboard);
      },
    );*/

    if (widget.initialFilters != null) {
      for (final filter in widget.initialFilters!) {
        final type = filter['type']?.toString();
        final value = filter['value'];

        if (type == 'Data' &&
            filter.containsKey('start') &&
            filter.containsKey('end')) {
          final startRaw = filter['start'];
          final endRaw = filter['end'];

          final start = startRaw is String ? DateTime.tryParse(startRaw) : null;
          final end = endRaw is String ? DateTime.tryParse(endRaw) : null;

          if (start != null && end != null) {
            selectedFilterType = 'Data';
            selectedStartTime =
                TimeOfDay(hour: start.hour, minute: start.minute);
            selectedEndTime = TimeOfDay(hour: end.hour, minute: end.minute);

            if (start.year == end.year &&
                start.month == end.month &&
                start.day == end.day) {
              // Single day
              pickedDate = start;
              selectedRange = null;
            } else {
              // It's a range!
              pickedDate = start; // still useful as fallback
              selectedRange = DateTimeRange(start: start, end: end);
            }

            _addFilter('Data', value.toString());

            Future.microtask(() {
              setState(() {
                selectedFilterType = null;
              });
            });
          }
        }

        // ✅ Restore Tempo Ciclo filter with special fields
        else if (type == 'Tempo Ciclo') {
          final condition = filter['condition']?.toString();
          final seconds = filter['seconds']?.toString();

          if (condition != null && seconds != null) {
            selectedFilterType = 'Tempo Ciclo';
            selectedCycleTimeCondition = condition;

            _addFilter(
                'Tempo Ciclo', seconds); // Triggers special composite logic
            // Delay reset to next frame so UI can react properly
            Future.microtask(() {
              setState(() {
                selectedFilterType = null;
              });
            });
          }
        }

        // ✅ All other filters (Stazione, Esito, etc.)
        else if (type != null && value != null) {
          selectedFilterType = type;
          _addFilter(type, value.toString());
          // Delay reset to next frame so UI can react properly
          Future.microtask(() {
            setState(() {
              selectedFilterType = null;
            });
          });
        }
      }
    }

    if (widget.autoSearch) {
      _onSearchPressed();
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await ApiService.getAllSettings();
      setState(() {
        _thresholdSeconds = (settings['min_cycle_threshold'] as num)
            .toDouble(); // we should set a global variable maybe
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Errore nel caricamento delle impostazioni: $e')),
      );
    }
  }

  void _addFilter(selectedFilterType, filterValue) {
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
            compositeValue += ' > ';
          } else if (selectedDisallineamentoMode == 'Ribbon') {
            compositeValue += ' > ${selectedDisallineamentoRibbonSide ?? ''}';
            compositeValue += ' > ${selectedDisallineamentoRibbon ?? ''}';
          } else {
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
        case 'Bad Soldering':
          compositeValue += ' > ${selectedBadSolderingStringa ?? ''}';
          break;
        case 'Lunghezza String Ribbon':
          compositeValue += ' > ${selectedLunghezzaStringa ?? ''}';
          break;
        case 'Altro':
          compositeValue += ' > ';
          break;
      }

      setState(() {
        activeFilters.add({
          'type': selectedFilterType!,
          'value': compositeValue,
        });
      });
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
        });
      }
    } else if (selectedFilterType == 'Tempo Ciclo') {
      if (selectedCycleTimeCondition == null || filterValue.isEmpty) return;
      compositeValue = '${selectedCycleTimeCondition!} $filterValue secondi';

      setState(() {
        activeFilters.add({
          'type': 'Tempo Ciclo',
          'value': compositeValue,
          'condition': selectedCycleTimeCondition!,
          'seconds': filterValue,
        });
      });
    } else if (selectedFilterType == 'Eventi') {
      if (selectedEventiCondition == null || filterValue.isEmpty) return;
      compositeValue = '${selectedEventiCondition!} $filterValue eventi';

      setState(() {
        activeFilters.add({
          'type': 'Eventi',
          'value': compositeValue,
          'condition': selectedEventiCondition!,
          'eventi': filterValue,
        });
      });
    } else {
      if (filterValue.isEmpty) return;

      compositeValue = filterValue;

      setState(() {
        activeFilters.add({
          'type': selectedFilterType!,
          'value': compositeValue,
        });
      });
    }

    // ✅ Reset all fields after adding filter (no matter the type)
    setState(() {
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
      selectedBadSolderingStringa = null;
      selectedLunghezzaStringa = null;
      selectedRange = null;
      pickedDate = null;
      selectedStartTime = null;
      selectedEndTime = null;
      selectedCycleTimeCondition = null;
      selectedEventiCondition = null;
      _textController.clear();
      _numericController.clear();
      _eventiController.clear();
    });
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

  // LINES //Should get from MySQL : production_lines
  Widget _buildDynamicInput() {
    switch (selectedFilterType) {
      case 'Linea':
        return _buildStyledDropdown(
          hint: 'Linea',
          value: filterValue.isNotEmpty ? filterValue : null,
          items: lineOptions,
          onChanged: (val) => setState(() => filterValue = val ?? ''),
        );
      // STATIONS //Should get from MySQL : stations
      case 'Stazione':
        return _buildStyledDropdown(
          hint: 'Stazione',
          value: filterValue.isNotEmpty ? filterValue : null,
          items: ['MIN01', 'MIN02', 'RMI01', 'ELL01'],
          onChanged: (val) => setState(() => filterValue = val ?? ''),
        );

      case 'Esito':
        return _buildStyledDropdown(
          hint: 'Esito',
          value: filterValue.isNotEmpty ? filterValue : null,
          items: esitoOptions,
          onChanged: (val) => setState(() => filterValue = val ?? ''),
        );

      case 'Tempo Ciclo':
        return Row(
          children: [
            _buildStyledDropdown(
              hint: 'Condizione',
              value: selectedCycleTimeCondition,
              items: [
                'Minore Di',
                'Minore o Uguale a',
                'Maggiore Di',
                'Maggiore o Uguale a',
                'Uguale A'
              ],
              onChanged: (val) => setState(() {
                selectedCycleTimeCondition = val;
              }),
            ),
            const SizedBox(width: 8),
            _buildStyledTextField(
              controller: _numericController,
              hint: 'Secondi',
              isNumeric: true,
              onChanged: (val) => filterValue = val,
            ),
          ],
        );

      case 'Eventi':
        return Row(
          children: [
            _buildStyledDropdown(
              hint: 'Condizione',
              value: selectedEventiCondition,
              items: [
                'Minore Di',
                'Minore o Uguale a',
                'Maggiore Di',
                'Maggiore o Uguale a',
                'Uguale A'
              ],
              onChanged: (val) => setState(() {
                selectedEventiCondition = val;
              }),
            ),
            const SizedBox(width: 8),
            _buildStyledTextField(
              controller: _eventiController,
              hint: 'Eventi',
              isNumeric: true,
              onChanged: (val) => filterValue = val,
            ),
          ],
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
                'I Ribbon Leadwire',
                'Lunghezza String Ribbon',
                'Graffio su Cella',
                'Bad Soldering',
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
                  selectedLeadwireRibbonSide = null;
                  selectedLeadwireRibbon = null;
                  selectedBadSolderingStringa = null;
                  selectedMacchieECAStringa = null;
                  selectedCelleRotteStringa = null;
                  selectedLunghezzaStringa = null;
                  selectedGraffioSuCellaStringa = null;
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

            // === I RIBBON LEADWIRE ===
            if (selectedDifettoGroup == 'I Ribbon Leadwire') ...[
              const SizedBox(width: 8),
              _buildStyledDropdown(
                hint: 'Ribbon',
                value: selectedLeadwireRibbon,
                items: leadwireRibbonOptions,
                onChanged: (val) =>
                    setState(() => selectedLeadwireRibbon = val),
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

            // === GRAFFIO SU CELLA ===
            if (selectedDifettoGroup == 'Graffio su Cella')
              _buildStyledDropdown(
                hint: 'Stringa',
                value: selectedGraffioSuCellaStringa,
                items: graffioSuCellaOptions,
                onChanged: (val) =>
                    setState(() => selectedGraffioSuCellaStringa = val),
              ),

            // === BAD SOLDERING ===
            if (selectedDifettoGroup == 'Bad Soldering')
              _buildStyledDropdown(
                hint: 'Stringa',
                value: selectedBadSolderingStringa,
                items: badSolderingOptions,
                onChanged: (val) =>
                    setState(() => selectedBadSolderingStringa = val),
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
              selectedCycleTimeCondition = null;
              selectedEventiCondition = null;
              _numericController.clear();
              _eventiController.clear();
              selectedRibbonSide = null;
            });
          },
        );

        final addButton = ElevatedButton(
          onPressed: () {
            final currentFilterType = selectedFilterType;
            final currentFilterValue = filterValue;
            _addFilter(currentFilterType, currentFilterValue);

            // Delay reset to next frame so UI can react properly
            Future.microtask(() {
              setState(() {
                selectedFilterType = null;
              });
            });
          },
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
    setState(() => searching = true);

    try {
      if (activeFilters.isEmpty) {
        await showNoFiltersDialog(context);
        return;
      }

      final data = await ApiService.fetchSearchResults(
        filters: activeFilters,
        orderBy: selectedOrderBy,
        orderDirection: selectedOrderDirection,
        limit: selectedLimit,
      );

      setState(() {
        results.addAll(data);
        searching = false;

        for (final row in results) {
          final objectId = row['object_id'];
          final productionIds =
              (row['production_ids'] as List).map((e) => e.toString()).toList();

          if (objectId != null && productionIds.isNotEmpty) {
            moduloIdToProductionIds[objectId] = productionIds;
          }
        }

        if (widget.onSearchCompleted != null) {
          widget.onSearchCompleted!();
        }
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
        leadingWidth:
            140, // ✅ Adjust width based on how many buttons you include
        leading: Row(
          children: [
            SizedBox(
              width: 8,
            ),
            IconButton(
              icon: Icon(Icons.settings, color: Colors.grey[800]),
              tooltip: 'Impostazioni',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
            SizedBox(
              width: 8,
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.blue),
              tooltip: 'Manuale',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManualSelectionPage(),
                  ),
                );
              },
            ),
          ],
        ),
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
                        selectedObjectIds.addAll(
                            results.map((g) => g['object_id'].toString()));
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
                        // Deseleziona Tutti
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
                            onConfirm: (bool exportFullHistory) async {
                              final selectedIds = selectedObjectIds.toList();

                              final allProductionIds = <String>[];

                              for (final row in results) {
                                final productionIds =
                                    (row['production_ids'] as List)
                                        .map((e) => e.toString())
                                        .toList();

                                allProductionIds.addAll(productionIds);
                              }

                              setState(() => isExporting = true);

                              final downloadUrl = await ApiService
                                  .exportSelectedObjectsAndGetDownloadUrl(
                                productionIds: allProductionIds,
                                moduloIds: selectedIds,
                                filters: activeFilters,
                                fullHistory: exportFullHistory,
                              );

                              if (downloadUrl != null) {
                                setState(
                                  () => isSelecting = false,
                                );

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
                              isExporting = false;
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
                    isSelecting ? 'Inizia Esportazione' : 'Esporta',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: Stack(
        children: [
          // A) Main content or loading overlay
          if (isExporting)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 5,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          "Esportazione in corso...",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Attendere qualche secondo...",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterRowCard(),
                  if (activeFilters.isNotEmpty)
                    _buildSectionTitle("Filtri Attivi"),
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
                              padding:
                                  const EdgeInsets.only(right: 12, bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${results.length} Moduli Visualizzati',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 20,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (isSelecting)
                                    Text(
                                      '${selectedObjectIds.length} Moduli Selezionati',
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
                            Align(
                                alignment: Alignment.centerLeft,
                                child: countLabel),
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

                  // 🧩 Cards Scrollable Area (grouped by object_id)
                  Expanded(
                    child: results.isEmpty
                        ? Center(
                            child: searching
                                ? const CircularProgressIndicator()
                                : Text(
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
                              final group = results[index];
                              final latest =
                                  group['latest_event'] as Map<String, dynamic>;
                              final history = group['history'] as List<dynamic>;
                              final count = group['event_count'] as int;
                              final objectId = group['object_id'] as String;
                              final isSelected =
                                  selectedObjectIds.contains(objectId);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: GestureDetector(
                                  onTap: () {
                                    if (isSelecting) {
                                      setState(() {
                                        if (isSelected) {
                                          selectedObjectIds.remove(objectId);
                                        } else {
                                          selectedObjectIds.add(objectId);
                                        }
                                      });
                                    } else {
                                      final history = (group['history'] as List)
                                          .cast<Map<String, dynamic>>();
                                      final latest = group['latest_event']
                                          as Map<String, dynamic>;
                                      final allEvents = [latest, ...history];

                                      if (allEvents.length == 1) {
                                        if (latest['station_name']
                                            .contains('ELL')) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  MBJDetailPage(data: latest),
                                            ),
                                          );
                                        } else {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ProductionDetailPage(
                                                      data: latest,
                                                      minCycleTimeThreshold:
                                                          _thresholdSeconds),
                                            ),
                                          );
                                        }
                                      } else {
                                        // multiple → push a new “multi” detail screen
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ObjectdetailsPage(
                                                events: allEvents,
                                                minCycleTimeThreshold:
                                                    _thresholdSeconds),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // 1) Partially show the previous (history) card in the background
                                      if (history.isNotEmpty)
                                        Positioned(
                                          top: 15,
                                          left: 8,
                                          right: 8,
                                          child: Opacity(
                                            opacity: 0.5,
                                            child: ObjectResultCard(
                                              data: history.first,
                                              isSelectable: false,
                                              isSelected: false,
                                              minCycleTimeThreshold:
                                                  _thresholdSeconds,
                                            ),
                                          ),
                                        ),

                                      // 2) The “latest” card on top
                                      ObjectResultCard(
                                        data: latest,
                                        isSelectable: isSelecting,
                                        isSelected: isSelected,
                                        productionIdsCount: count,
                                        minCycleTimeThreshold:
                                            _thresholdSeconds,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          // B) Rive button in bottom-right
          /*Positioned(
            right: 20,
            bottom: 20,
            child: MouseRegion(
              onEnter: (_) {
                _boolInput?.value = true; // Enable 'hvr ic'
              },
              onExit: (_) {
                _boolInput?.value = false; // Disable 'hvr ic'
              },
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AIHelperChat(
                      onQueryGenerated: (sqlQuery) async {
                        print('Query returned: $sqlQuery');
                        try {
                          print('Starting Query');
                          final data =
                              await ApiService.fetchDataFromQuery(sqlQuery);
                          print('Query results length: ${data.length}');
                          print('Query results: $data');

                          setState(() {
                            results.clear();
                            results.addAll(
                              data.map((row) => {
                                    'object_id': row['id_modulo'],
                                    'event_count': 1,
                                    'latest_event': row,
                                    'history': [],
                                  }),
                            );
                          });
                        } catch (e) {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Errore"),
                              content: Text(
                                  "Errore nell'esecuzione della query AI:\n$e"),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
                child: SizedBox(
                  height: 100,
                  width: 100,
                  child: _riveArtboard != null
                      ? Rive(artboard: _riveArtboard!)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),*/
        ],
      ),
    );
  }
}

class DateSelectionResult {
  final DateTime? singleDate;
  final DateTimeRange? range;

  const DateSelectionResult({this.singleDate, this.range});
}
