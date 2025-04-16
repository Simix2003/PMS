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
  double _minCycleSeconds = 3;
  int _ecaThreshold = 5;

  // Yield Settings
  bool _includeNCInYield = true;
  bool _excludeSaldaturaDefects = false;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await ApiService.getAllSettings();
      setState(() {
        _minCycleSeconds = (settings['min_cycle_threshold'] as num).toDouble();
        _ecaThreshold = settings['eca_threshold'] as int;
        _includeNCInYield = settings['include_nc_in_yield'] as bool;
        _excludeSaldaturaDefects =
            settings['exclude_saldatura_from_yield'] as bool;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Errore nel caricamento delle impostazioni: $e')),
      );
    }
  }

  Future<void> _saveSettings() async {
    final settings = {
      'min_cycle_threshold': _minCycleSeconds,
      'eca_threshold': _ecaThreshold,
      'include_nc_in_yield': _includeNCInYield,
      'exclude_saldatura_from_yield': _excludeSaldaturaDefects,
    };

    try {
      await ApiService.setAllSettings(settings);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impostazioni salvate')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nel salvataggio: $e')),
      );
    }
  }

  Widget _buildGroupTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.blue),
        foregroundColor: Colors.blue,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.purple.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.75),
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
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // --- Min Cycle Time ---
                      _buildGroupTitle(
                          'Tempo Ciclo Minimo', Icons.timer, Colors.blue),
                      const SizedBox(height: 16),
                      Text(
                        'Minimo tempo (in secondi) per considerare un ciclo come "Controllato":',
                        style: TextStyle(color: Colors.blue.shade700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _minCycleSeconds,
                              min: 1,
                              max: 30,
                              divisions: 29,
                              label: '${_minCycleSeconds.round()}s',
                              onChanged: (val) {
                                setState(() => _minCycleSeconds = val);
                              },
                            ),
                          ),
                          Text(
                            '${_minCycleSeconds.round()}s',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // --- Yield Calculation ---
                      _buildGroupTitle(
                          'Calcolo Yield (TPY)', Icons.percent, Colors.green),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title:
                            const Text('Includi "NC" nel calcolo dello Yield'),
                        value: _includeNCInYield,
                        activeColor: Colors.green,
                        onChanged: (val) {
                          setState(() => _includeNCInYield = val);
                        },
                      ),
                      SwitchListTile(
                        title: const Text(
                            'Escludi moduli con difetti di Saldatura dallo Yield'),
                        value: _excludeSaldaturaDefects,
                        activeColor: Colors.green,
                        onChanged: (val) {
                          setState(() => _excludeSaldaturaDefects = val);
                        },
                      ),

                      const SizedBox(height: 32),

                      // --- ECA Alert ---
                      _buildGroupTitle('Allarme Macchie ECA',
                          Icons.warning_amber_rounded, Colors.deepPurple),
                      const SizedBox(height: 16),
                      Text(
                        'Avvisa se una stringatrice produce più di questo numero di "Macchie ECA":',
                        style: TextStyle(color: Colors.deepPurple.shade700),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _ecaThreshold.toString(),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Soglia Macchie ECA',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && parsed > 0) {
                            setState(() => _ecaThreshold = parsed);
                          }
                        },
                      ),

                      const SizedBox(height: 40),

                      // Save Button
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _saveSettings,
                          icon: const Icon(
                            Icons.save,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Salva Impostazioni',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
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
    );
  }
}
