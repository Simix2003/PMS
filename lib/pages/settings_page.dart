// ignore_for_file: deprecated_member_use, use_build_context_synchronously

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

  // Stringatrice settings
  final List<String> _stringaDefects = [
    "Macchie ECA",
    "Lunghezza String-Ribbon",
    "Celle Rotte",
    "No Good da Bussing"
  ];
  final Map<String, int> _thresholds = {};
  final Map<String, int> _moduliWindow = {};
  final Map<String, bool> _enableConsecutiveKO = {};
  final Map<String, int> _consecutiveKOLimit = {};

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
        _minCycleSeconds =
            (settings['min_cycle_threshold'] as num?)?.toDouble() ?? 3;
        _includeNCInYield = settings['include_nc_in_yield'] as bool? ?? true;
        _excludeSaldaturaDefects =
            settings['exclude_saldatura_from_yield'] as bool? ?? false;

        for (final defect in _stringaDefects) {
          _thresholds[defect] = settings['thresholds']?[defect] ?? 3;
          _moduliWindow[defect] = settings['moduli_window']?[defect] ?? 10;
          _enableConsecutiveKO[defect] =
              settings['enable_consecutive_ko']?[defect] ?? false;
          _consecutiveKOLimit[defect] =
              settings['consecutive_ko_limit']?[defect] ?? 2;
        }

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
      'include_nc_in_yield': _includeNCInYield,
      'exclude_saldatura_from_yield': _excludeSaldaturaDefects,
      'thresholds': _thresholds,
      'moduli_window': _moduliWindow,
      'enable_consecutive_ko': _enableConsecutiveKO,
      'consecutive_ko_limit': _consecutiveKOLimit,
    };

    try {
      await ApiService.setAllSettings(settings);
      await ApiService.refreshBackendSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impostazioni salvate e aggiornate')),
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
                        color: Colors.white.withOpacity(0.8), width: 1.5),
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
                      // 🔶 Tempo Ciclo Minimo Card
                      Card(
                        color: Colors.orange.shade50,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildGroupTitle("Tempo Ciclo Minimo",
                                  Icons.timer, Colors.orange),
                              const SizedBox(height: 12),
                              Text(
                                'Minimo tempo (in secondi) per considerare un ciclo come "Controllato":',
                                style: TextStyle(color: Colors.orange.shade700),
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
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 🟦 Stringatrice Card
                      Card(
                        color: Colors.teal.shade50,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildGroupTitle("Stringatrice",
                                  Icons.warning_amber_rounded, Colors.teal),
                              const SizedBox(height: 8),
                              const Text(
                                  "Configura soglie per allarmi specifici a difetto:"),
                              const SizedBox(height: 12),
                              ..._stringaDefects.map((defect) => Container(
                                    margin: const EdgeInsets.only(bottom: 20),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.teal.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(defect,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.teal)),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                initialValue:
                                                    _moduliWindow[defect]
                                                        ?.toString(),
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    const InputDecoration(
                                                        labelText:
                                                            "Numero Moduli"),
                                                onChanged: (val) {
                                                  final parsed =
                                                      int.tryParse(val);
                                                  if (parsed != null) {
                                                    setState(() =>
                                                        _moduliWindow[defect] =
                                                            parsed);
                                                  }
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: TextFormField(
                                                initialValue:
                                                    _thresholds[defect]
                                                        ?.toString(),
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    const InputDecoration(
                                                        labelText: "Soglia KO"),
                                                onChanged: (val) {
                                                  final parsed =
                                                      int.tryParse(val);
                                                  if (parsed != null) {
                                                    setState(() =>
                                                        _thresholds[defect] =
                                                            parsed);
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        SwitchListTile(
                                          title: const Text(
                                              "Abilita avviso su KO consecutivi"),
                                          value: _enableConsecutiveKO[defect] ??
                                              false,
                                          activeColor: Colors.teal,
                                          onChanged: (val) {
                                            setState(() =>
                                                _enableConsecutiveKO[defect] =
                                                    val);
                                          },
                                        ),
                                        if (_enableConsecutiveKO[defect] ==
                                            true)
                                          TextFormField(
                                            initialValue:
                                                _consecutiveKOLimit[defect]
                                                    ?.toString(),
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                                labelText:
                                                    "Numero KO consecutivi"),
                                            onChanged: (val) {
                                              final parsed = int.tryParse(val);
                                              if (parsed != null) {
                                                setState(() =>
                                                    _consecutiveKOLimit[
                                                        defect] = parsed);
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 🟢 Yield Card
                      Card(
                        color: Colors.green.shade50,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildGroupTitle("Calcolo Yield (TPY)",
                                  Icons.percent, Colors.green),
                              const SizedBox(height: 16),
                              SwitchListTile(
                                title: const Text(
                                    'Includi "NC" nel calcolo dello Yield'),
                                value: _includeNCInYield,
                                activeColor: Colors.green,
                                onChanged: (val) {
                                  setState(() => _includeNCInYield = val);
                                },
                              ),
                              SwitchListTile(
                                title: const Text(
                                    'Escludi difetti di Saldatura dallo Yield'),
                                value: _excludeSaldaturaDefects,
                                activeColor: Colors.green,
                                onChanged: (val) {
                                  setState(
                                      () => _excludeSaldaturaDefects = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 💾 Save Button
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _saveSettings,
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: const Text('Salva Impostazioni',
                              style: TextStyle(fontWeight: FontWeight.bold)),
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
