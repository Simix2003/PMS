// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:ix_monitor/shared/widgets/mes_card.dart';

class SingleModulePage extends StatefulWidget {
  const SingleModulePage({super.key});

  @override
  State<SingleModulePage> createState() => _SingleModulePageState();
}

class _SingleModulePageState extends State<SingleModulePage> {
  static const double maxContentWidth = 900;
  static const double mesCardHeight = 250;

  final TextEditingController _scanController = TextEditingController();
  String? _errorText;
  String? _scannedCode;
  Map<String, dynamic>? _moduleData;
  String? _reworkStep;
  String? _selectedStage;
  String? _selectedNewClass;
  String? _selectedLine;

  final stages = ['PRE VPF', 'PRE FRAMING', 'PRE JBX', 'POST CURING'];
  final qcOrder = ['A', 'B', 'C'];
  final _userName = 'Simone Paparo';

  void _handleScan() {
    final code = _scanController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorText = 'Inserisci o scansiona un codice valido');
      return;
    }
    final randomNG = 'NG${2 + (DateTime.now().millisecond % 9)}';
    final randomQC = ['A', 'B', 'C'][DateTime.now().second % 3];

    setState(() {
      _scannedCode = code;
      _moduleData = {
        'latest_event': {
          'id_modulo': code,
          'esito': 6,
          'defect_categories': randomNG,
          'classe_qc': randomQC,
        }
      };
      _scanController.clear();
      _errorText = null;
    });
  }

  void _handleScrap(String? moduleId) {
    if (moduleId == null) return;
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.bottomSlide,
      width: 750,
      title: 'Conferma SCRAP',
      desc: 'Marcare "$moduleId" come SCRAP?\nAzione irreversibile.',
      btnCancelText: 'Annulla',
      btnOkText: 'Conferma',
      btnOkColor: Colors.red.shade700,
      btnCancelColor: Colors.grey.shade700,
      btnCancelOnPress: () {},
      btnOkOnPress: () {
        setState(() => _scannedCode = null);
      },
    ).show();
  }

  void _handleBack() {
    setState(() {
      if (_reworkStep == 'stage') {
        _reworkStep = 'line';
      } else {
        _reworkStep = null;
        _selectedLine = null;
        _scannedCode = null;
      }
    });
  }

  Widget _bigChoice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color selectedColor = Colors.blue,
    IconData? icon,
    Color? iconColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: icon != null
          ? Icon(icon, size: 24, color: iconColor ?? Colors.black)
          : const SizedBox.shrink(),
      label: Text(label, textAlign: TextAlign.center),
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? selectedColor : Colors.white,
        foregroundColor: selected ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildDetailViewWrapper({required Widget child}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      ),
    );
  }

  Widget _buildScanView() {
    return _buildDetailViewWrapper(
      child: Column(
        children: [
          const Icon(Icons.qr_code_scanner, size: 80, color: Colors.blue),
          const SizedBox(height: 24),
          Text('Scansiona ID Modulo',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text('Inserisci o scansiona il codice del modulo per iniziare.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.black54),
              textAlign: TextAlign.center),
          const SizedBox(height: 36),
          TextField(
            controller: _scanController,
            onSubmitted: (_) => _handleScan(),
            decoration: InputDecoration(
              labelText: 'Codice modulo',
              prefixIcon: const Icon(Icons.qr_code),
              errorText: _errorText,
              filled: true,
              fillColor: const Color(0xFFF7F9FC),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _handleScan,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text(
                'Conferma',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActions(Map<String, dynamic> latest) {
    return _buildDetailViewWrapper(
      child: Column(
        children: [
          SizedBox(height: mesCardHeight, child: MesCard(data: latest)),
          const SizedBox(height: 36),
          const Text('Seleziona Azione',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                  child: _bigChoice(
                      label: 'Scrap',
                      selected: false,
                      onTap: () => _handleScrap(_scannedCode),
                      icon: Icons.delete_forever,
                      iconColor: Colors.red)),
              const SizedBox(width: 24),
              Expanded(
                  child: _bigChoice(
                      label: 'ReWork',
                      selected: false,
                      onTap: () => setState(() => _reworkStep = 'line'),
                      icon: Icons.build,
                      iconColor: Colors.blue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReworkLineSelection(Map<String, dynamic> latest) {
    return _buildDetailViewWrapper(
      child: Column(
        children: [
          SizedBox(height: mesCardHeight, child: MesCard(data: latest)),
          const SizedBox(height: 36),
          const Text('Seleziona Linea per il rientro',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['A', 'B', 'C'].map((line) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _bigChoice(
                    label: 'Linea $line',
                    selected: _selectedLine == line,
                    onTap: () => setState(() {
                      _selectedLine = line;
                      _reworkStep = 'stage';
                    }),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReworkForm(Map<String, dynamic> latest) {
    _selectedStage ??= stages.first;
    _selectedNewClass ??= latest['classe_qc'];

    return _buildDetailViewWrapper(
      child: Column(
        children: [
          SizedBox(height: mesCardHeight, child: MesCard(data: latest)),
          const SizedBox(height: 24),
          Text('Linea selezionata: $_selectedLine\nSeleziona zona di rientro',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(
            children: stages.map((s) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _bigChoice(
                    label: s,
                    selected: _selectedStage == s,
                    onTap: () => setState(() => _selectedStage = s),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              icon:
                  const Icon(Icons.check_circle, color: Colors.white, size: 30),
              label: const Text(
                'Conferma Ingresso',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                textStyle:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () async {
                AwesomeDialog(
                  context: context,
                  dialogType: DialogType.noHeader,
                  dismissOnTouchOutside: false,
                  dismissOnBackKeyPress: false,
                  width: 750,
                  animType: AnimType.scale,
                  title: "Comunicazione con il MES...",
                  desc: "Allineamento in corso...",
                ).show();

                await Future.delayed(const Duration(seconds: 2));
                Navigator.of(context).pop();

                AwesomeDialog(
                  context: context,
                  dialogType: DialogType.success,
                  width: 750,
                  autoDismiss: true,
                  autoHide: const Duration(seconds: 5),
                  title: "Modulo Allineato",
                  desc: 'Modulo pronto per il rientro in "\$_selectedStage"',
                ).show();

                setState(() {
                  _reworkStep = null;
                  _scannedCode = null;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailView() {
    final latest = _moduleData!['latest_event'] as Map<String, dynamic>;
    if (_reworkStep == 'line') return _buildReworkLineSelection(latest);
    if (_reworkStep == 'stage') return _buildReworkForm(latest);
    return _buildMainActions(latest);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FB),
      body: Stack(
        children: [
          Positioned(
            top: 30,
            right: 40,
            child: Row(
              children: [
                const Icon(Icons.account_circle, size: 34, color: Colors.grey),
                const SizedBox(width: 12),
                Text(_userName, style: const TextStyle(fontSize: 24)),
              ],
            ),
          ),
          if (_scannedCode != null)
            Positioned(
              top: 30,
              left: 40,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, size: 30),
                onPressed: _handleBack,
              ),
            ),
          Positioned.fill(
            top: 80,
            child: _scannedCode == null ? _buildScanView() : _buildDetailView(),
          ),
        ],
      ),
    );
  }
}
