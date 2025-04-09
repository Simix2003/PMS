// ignore_for_file: deprecated_member_use, non_constant_identifier_names, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/services/api_service.dart';
import '../../shared/widgets/object_result_card.dart';

class FindPage extends StatefulWidget {
  const FindPage({super.key});

  @override
  _FindPageState createState() => _FindPageState();
}

class _FindPageState extends State<FindPage> {
  String? selectedFilterType;
  String filterValue = '';
  DateTimeRange? selectedRange;
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
    'Intervallo Date',
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

      case 'Intervallo Date':
        return TextButton.icon(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(DateTime.now().year - 1),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                selectedRange = picked;
                filterValue =
                    '${DateFormat('dd MMM y').format(picked.start)} → ${DateFormat('dd MMM y').format(picked.end)}';
              });
            }
          },
          icon: const Icon(Icons.date_range_rounded),
          label: Text(
            filterValue.isEmpty ? 'Seleziona Intervallo' : filterValue,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF007AFF),
            ),
          ),
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
                          return AlertDialog(
                            title: const Text('Conferma Esportazione'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hai selezionato ${selectedObjectIds.length} elementi da esportare.',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 16),
                                if (activeFilters.isNotEmpty) ...[
                                  const Text(
                                    'Filtri Attivi:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  ...activeFilters.map((f) =>
                                      Text("• ${f['type']}: ${f['value']}")),
                                ],
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Annulla'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  print(
                                      '📤 Exporting IDs: ${selectedObjectIds.toList()}');
                                  setState(() => isSelecting = false);
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF007AFF)),
                                child: const Text('Conferma'),
                              ),
                            ],
                          );
                        },
                      );
                    } else {
                      setState(() => isSelecting = true);
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
