// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:ui';

import '../shared/services/api_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _sogliaSecondi = 3;
  int _macchieEcaThreshold = 5; // default value for UI
  bool _caricamento = true;

  @override
  void initState() {
    super.initState();
    _loadThreshold();
  }

  Future<void> _loadThreshold() async {
    try {
      final valore = await ApiService.getProductionThreshold();
      setState(() {
        _sogliaSecondi = valore;
        _caricamento = false;
      });
    } catch (e) {
      setState(() => _caricamento = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nel caricamento della soglia: $e')),
      );
    }
  }

  Future<void> _saveThreshold() async {
    try {
      await ApiService.setProductionThreshold(_sogliaSecondi);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Soglia salvata')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nel salvataggio della soglia: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_caricamento) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Impostazioni',
          style: TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.blue),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.8),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// -------------------------
                        /// Soglia tempo controllato
                        /// -------------------------
                        Text(
                          'Tempo min. per considerare un oggetto "Controllato":',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  activeTrackColor: Colors.blue.shade500,
                                  inactiveTrackColor: Colors.blue.shade200,
                                  thumbColor: Colors.blue.shade600,
                                  overlayColor: Colors.blue.withOpacity(0.2),
                                  valueIndicatorColor: Colors.blue.shade500,
                                  valueIndicatorTextStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                child: Slider(
                                  value: _sogliaSecondi,
                                  min: 1,
                                  max: 30,
                                  divisions: 29,
                                  label: '${_sogliaSecondi.round()}s',
                                  onChanged: (value) {
                                    setState(() => _sogliaSecondi = value);
                                  },
                                ),
                              ),
                            ),
                            Text(
                              '${_sogliaSecondi.round()}s',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        /// -------------------------------
                        /// Soglia Macchie ECA da Avvisare
                        /// -------------------------------
                        Text(
                          'Avvisa se la stessa Stringatrice produce troppe "Macchie ECA":',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          initialValue: _macchieEcaThreshold.toString(),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Numero soglia Macchie ECA',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            if (parsed != null && parsed > 0) {
                              setState(() => _macchieEcaThreshold = parsed);
                            }
                          },
                        ),

                        const SizedBox(height: 40),

                        /// -------------------------------
                        /// Save Button
                        /// -------------------------------
                        Center(
                          child: ElevatedButton(
                            onPressed:
                                _saveThreshold, // Only saves _sogliaSecondi for now
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                              backgroundColor: Colors.blue.shade500,
                              foregroundColor: Colors.white,
                              elevation: 3,
                              shadowColor: Colors.blue.withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: Colors.blue.shade300,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.save, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Salva',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
