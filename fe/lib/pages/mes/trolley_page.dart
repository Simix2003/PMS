import 'package:flutter/material.dart';

class TrolleyPage extends StatefulWidget {
  const TrolleyPage({super.key});

  @override
  State<TrolleyPage> createState() => _TrolleyPageState();
}

class _TrolleyPageState extends State<TrolleyPage> {
  final TextEditingController _scanController = TextEditingController();
  final List<String> _acceptedModules = [];
  String? _selectedZone;
  String? _errorText;

  final List<String> _availableZones = ['ELL', 'VPF', 'QG2'];

  bool isValidInZone(String moduleId, String zone) {
    // Simulazione validazione (mock)
    return moduleId.startsWith(zone);
  }

  void _handleAddModule() {
    final moduleId = _scanController.text.trim().toUpperCase();
    if (moduleId.isEmpty || _selectedZone == null) {
      setState(() {
        _errorText = 'Inserisci un modulo valido e seleziona una zona';
      });
      return;
    }

    if (!isValidInZone(moduleId, _selectedZone!)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '❌ Il modulo "$moduleId" non può essere rilavorato in zona $_selectedZone',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.red.shade600,
      ));
      return;
    }

    if (_acceptedModules.contains(moduleId)) {
      _scanController.clear();
      return;
    }

    setState(() {
      _acceptedModules.add(moduleId);
      _scanController.clear();
      _errorText = null;
    });
  }

  void _removeModule(String moduleId) {
    setState(() {
      _acceptedModules.remove(moduleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.blue;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FB),
      appBar: AppBar(
        title: const Text('Modalità Trolley'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Selezione zona
            const Text(
              'Zona di rilavorazione',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedZone,
              items: _availableZones
                  .map((zone) => DropdownMenuItem(
                        value: zone,
                        child: Text(zone),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedZone = value;
                });
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),

            /// Inserimento modulo
            TextField(
              controller: _scanController,
              onSubmitted: (_) => _handleAddModule(),
              decoration: InputDecoration(
                labelText: 'ID Modulo',
                errorText: _errorText,
                prefixIcon: const Icon(Icons.qr_code),
                filled: true,
                fillColor: Colors.white,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi Modulo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _handleAddModule,
              ),
            ),
            const SizedBox(height: 32),

            /// Lista moduli accettati
            const Text(
              'Moduli accettati:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _acceptedModules.isEmpty
                  ? const Center(
                      child: Text('Nessun modulo ancora aggiunto.'),
                    )
                  : ListView.builder(
                      itemCount: _acceptedModules.length,
                      itemBuilder: (context, index) {
                        final moduleId = _acceptedModules[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.memory),
                            title: Text(moduleId),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeModule(moduleId),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            /// (Opzionale) Pulsante finale
            if (_acceptedModules.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Conferma Carrello'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      textStyle: const TextStyle(fontSize: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      // TODO: invio finale se serve
                      debugPrint('Carrello confermato con: $_acceptedModules');
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Carrello confermato ✅'),
                        backgroundColor: Colors.green.shade600,
                      ));
                      setState(() {
                        _acceptedModules.clear();
                      });
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
