import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';

class SingleModulePage extends StatefulWidget {
  const SingleModulePage({super.key});

  @override
  State<SingleModulePage> createState() => _SingleModulePageState();
}

class _SingleModulePageState extends State<SingleModulePage> {
  final TextEditingController _scanController = TextEditingController();
  String? _errorText;
  String? _scannedCode;

  // Mock user name

  void _handleScan() {
    final code = _scanController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorText = 'Inserisci o scansiona un codice valido');
      return;
    }

    debugPrint('Scanned code: $code');

    setState(() {
      _scannedCode = code;
      _scanController.clear();
      _errorText = null;
    });
  }

  void _handleScrap(String? moduleId) {
    if (moduleId == null) return;

    AwesomeDialog(
      context: context,
      width: 600,
      dialogType: DialogType.warning,
      animType: AnimType.bottomSlide,
      title: 'Conferma eliminazione',
      desc:
          'Sei sicuro di voler marcare il modulo "$moduleId" come SCRAP?\n\nQuesta azione è irreversibile.',
      btnCancelText: 'Annulla',
      btnCancelOnPress: () {},
      btnOkText: 'Conferma',
      btnOkOnPress: () {
        debugPrint('Modulo $moduleId marcato come SCRAP');
        // TODO: call API or update DB here
        setState(() {
          _scannedCode = null;
        });
      },
      btnCancelColor: Colors.grey.shade400,
      btnOkColor: Colors.red.shade700,
      buttonsBorderRadius: const BorderRadius.all(Radius.circular(12)),
    ).show();
  }

  Widget _buildScanInput(BuildContext context) {
    final theme = Theme.of(context);
    const primaryColor = Colors.blue;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            elevation: 18,
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_scanner,
                      size: 80, color: primaryColor),
                  const SizedBox(height: 24),
                  Text(
                    'Scansiona ID Modulo',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Inserisci o scansiona il codice del modulo per iniziare.',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
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
                        borderRadius: BorderRadius.circular(20),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            const BorderSide(color: primaryColor, width: 2),
                      ),
                    ),
                    style: const TextStyle(fontSize: 18),
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
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          /// Top Row: Back + ID
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 30),
                onPressed: () {
                  setState(() {
                    _scannedCode = null; // Return to scan view
                  });
                },
              ),
              const SizedBox(width: 8),
              const Icon(Icons.memory_rounded, size: 30),
              const SizedBox(width: 8),
              Text(
                _scannedCode ?? '',
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 38),

          /// Action buttons
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 40,
              runSpacing: 20,
              children: [
                /// ReWork
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: handle ReWork
                  },
                  icon: const Icon(Icons.build, size: 36, color: Colors.blue),
                  label: const Text(
                    'ReWork',
                    style: TextStyle(color: Colors.blue),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 32),
                    textStyle: const TextStyle(fontSize: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),

                /// Scrap
                ElevatedButton.icon(
                  onPressed: () => _handleScrap(_scannedCode),
                  icon: const Icon(Icons.delete_forever,
                      size: 36, color: Colors.white),
                  label: const Text(
                    'Scrap',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 32),
                    textStyle: const TextStyle(fontSize: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FB),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Modulo Singolo'),
      ),
      body: Stack(
        children: [
          /// Main content
          _scannedCode == null
              ? _buildScanInput(context)
              : _buildDetailView(context),
        ],
      ),
    );
  }
}
