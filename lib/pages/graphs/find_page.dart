// ignore_for_file: deprecated_member_use

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

  final List<Map<String, String>> activeFilters = [];

  final List<String> filterOptions = [
    'Linea',
    'Stazione',
    'Esito',
    'Categoria Difetto',
    'ID Modulo',
    'Intervallo Date',
    'Turno',
    "Stringatrice",
    'Operatore',
    'Tipo Difetto (Generali)',
    'Stringa',
    'Ribbon',
    'S-Ribbon',
    'Dati Extra',
  ];

  final List<String> esitoOptions = [
    'OK',
    'KO',
    'In Produzione',
  ];

  final List<String> ribbonSides = ['F', 'M', 'B'];

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
    if (selectedFilterType != null && filterValue.isNotEmpty) {
      setState(() {
        activeFilters.add({
          'type': selectedFilterType!,
          'value': filterValue,
        });
        _textController.clear();
        _numericController.clear();
        filterValue = '';
        selectedFilterType = null;
        selectedRange = null;
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
      case 'Esito':
        return _buildStyledDropdown(
          hint: 'Esito',
          value: filterValue.isNotEmpty ? filterValue : null,
          items: esitoOptions,
          onChanged: (val) => setState(() => filterValue = val ?? ''),
        );

      case 'Linea':
        return _buildStyledDropdown(
          hint: 'Linea',
          value: filterValue.isNotEmpty ? filterValue : null,
          items: ['Linea A', 'Linea B'],
          onChanged: (val) => setState(() => filterValue = val ?? ''),
        );

      case 'Stringatrice':
        return _buildStyledDropdown(
          hint: 'Stringatrice',
          value: filterValue.isNotEmpty ? filterValue : null,
          items: ['1', '2', '3', '4', '5'],
          onChanged: (val) => setState(() => filterValue = val ?? ''),
        );

      case 'Stazione':
        return _buildStyledDropdown(
          hint: 'Stazione',
          value: filterValue.isNotEmpty ? filterValue : null,
          items: ['M308', 'M309', 'M326'],
          onChanged: (val) => setState(() => filterValue = val ?? ''),
        );

      case 'Turno':
        return _buildStyledDropdown(
          hint: 'Turno',
          value: filterValue.isNotEmpty ? filterValue : null,
          items: ['1', '2', '3'],
          onChanged: (val) => setState(() => filterValue = val ?? ''),
        );

      case 'Categoria Difetto':
        return _buildStyledDropdown(
          hint: 'Categoria',
          value: filterValue.isNotEmpty ? filterValue : null,
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
          onChanged: (val) => setState(() => filterValue = val ?? ''),
        );

      case 'ID Modulo':
      case 'Operatore':
      case 'Tipo Difetto (Generali)':
      case 'Dati Extra':
        return _buildStyledTextField(
          controller: _textController,
          hint: 'Testo',
          onChanged: (val) => filterValue = val,
        );

      case 'Stringa':
      case 'S-Ribbon':
        return _buildStyledTextField(
          controller: _numericController,
          hint: 'Numero',
          isNumeric: true,
          width: 100,
          onChanged: (val) => filterValue = val,
        );

      case 'Ribbon':
        return Row(
          children: [
            _buildStyledTextField(
              controller: _numericController,
              hint: 'N°',
              isNumeric: true,
              width: 70,
              onChanged: (val) {
                if (selectedRibbonSide != null) {
                  filterValue = '$val (${selectedRibbonSide!})';
                }
              },
            ),
            const SizedBox(width: 8),
            _buildStyledDropdown(
              hint: 'Lato',
              value: selectedRibbonSide,
              items: ribbonSides,
              onChanged: (val) {
                setState(() {
                  selectedRibbonSide = val;
                  if (_numericController.text.isNotEmpty) {
                    filterValue = '${_numericController.text} ($val)';
                  }
                });
              },
            ),
          ],
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
                        child: Text(
                          '${results.length} Elementi Visualizzati',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 24,
                            color: Colors.black87,
                          ),
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
                          child: ObjectResultCard(data: results[index]),
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
