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
  final TextEditingController _scanController = TextEditingController();
  String? _errorText;
  String? _scannedCode;
  Map<String, dynamic>? _moduleData;
  bool _isReworkMode = false;
  String? _selectedStage;
  String? _selectedNewClass;

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

  Widget _bigChoice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color selectedColor = Colors.blue,
    IconData? icon,
    Color? iconColor,
  }) {
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: selected ? selectedColor : Colors.white,
      foregroundColor: selected ? Colors.white : Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 26),
      textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      side: selected
          ? BorderSide.none
          : const BorderSide(color: Colors.black54, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );

    return icon != null
        ? ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 32, color: iconColor ?? Colors.black),
            label: Text(label),
            style: buttonStyle,
          )
        : ElevatedButton(
            onPressed: onTap,
            style: buttonStyle,
            child: Text(label),
          );
  }

  Widget _buildScanView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            elevation: 18,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_scanner,
                      size: 80, color: Colors.blue),
                  const SizedBox(height: 24),
                  Text('Scansiona ID Modulo',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium!
                          .copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(
                      'Inserisci o scansiona il codice del modulo per iniziare.',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium!
                          .copyWith(color: Colors.black54),
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20)),
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
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReworkForm(Map<String, dynamic> latest) {
    final currentIdx = qcOrder.indexOf(latest['classe_qc']);
    final allowedQCs = qcOrder.sublist(currentIdx);

    _selectedStage ??= stages.first;
    _selectedNewClass ??= latest['classe_qc'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, size: 30),
          onPressed: () => setState(() => _isReworkMode = false),
        ),
        MesCard(data: latest),
        const SizedBox(height: 24),
        const Text('Seleziona zona Ingresso',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: stages
              .map((s) => _bigChoice(
                    label: s,
                    selected: _selectedStage == s,
                    onTap: () => setState(() => _selectedStage = s),
                    selectedColor: Colors.blue,
                  ))
              .toList(),
        ),
        const SizedBox(height: 40),
        const Text('Nuova Classe QC',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: qcOrder.map((c) {
            final isAllowed = allowedQCs.contains(c);
            final isSelected = _selectedNewClass == c;

            final textColor = isSelected
                ? Colors.white
                : isAllowed
                    ? Colors.black
                    : Colors.grey;

            return ElevatedButton(
              onPressed: isAllowed
                  ? () => setState(() => _selectedNewClass = c)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected
                    ? Colors.blue
                    : isAllowed
                        ? Colors.white
                        : Colors.grey.shade300,
                foregroundColor: textColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 26),
                textStyle:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(c),
            );
          }).toList(),
        ),
        const SizedBox(height: 50),
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle, color: Colors.white, size: 30),
            label: const Text('Conferma Ingresso',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 26),
              textStyle: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
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

              Navigator.of(context).pop(); // close loading dialog

              AwesomeDialog(
                context: context,
                dialogType: DialogType.success,
                width: 750,
                autoDismiss: true,
                autoHide: const Duration(seconds: 5),
                title: "Modulo Allineato",
                desc: 'Modulo pronto per il rientro in "${_selectedStage}"',
              ).show();

              setState(() {
                _isReworkMode = false;
                _scannedCode = null;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDetailView() {
    final latest = _moduleData!['latest_event'] as Map<String, dynamic>;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: _isReworkMode
          ? _buildReworkForm(latest)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 30),
                  onPressed: () => setState(() {
                    _scannedCode = null;
                    _moduleData = null;
                    _isReworkMode = false;
                  }),
                ),
                MesCard(data: latest),
                const SizedBox(height: 36),
                Center(
                  child: Wrap(
                    spacing: 40,
                    runSpacing: 20,
                    children: [
                      _bigChoice(
                        label: 'Scrap',
                        selected: false,
                        icon: Icons.delete_forever,
                        iconColor: Colors.red,
                        selectedColor: Colors.red,
                        onTap: () => _handleScrap(_scannedCode),
                      ),
                      _bigChoice(
                        label: 'ReWork',
                        selected: false,
                        icon: Icons.build,
                        iconColor: Colors.blue,
                        onTap: () => setState(() => _isReworkMode = true),
                      ),
                    ],
                  ),
                )
              ],
            ),
    );
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
          _scannedCode == null ? _buildScanView() : _buildDetailView(),
        ],
      ),
    );
  }
}
