// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
    "No Good da Bussing",
    "Bad Soldering"
  ];
  final Map<String, int> _thresholds = {};
  final Map<String, int> _moduliWindow = {};
  final Map<String, bool> _enableConsecutiveKO = {};
  final Map<String, int> _consecutiveKOLimit = {};

  bool _alwaysExportHistory = true;
  bool _exportMBJImage = true;

// MBJ fields toggle map (feel free to customize names)
  final Map<String, bool> _mbjFields = {
    "Mostra Ribbon": false, // showRibbons
    "Gap Orizzontali tra Celle": false, // showHorizontalGaps
    "Gap Verticali tra Celle": false, // showVerticalGaps
    "Distanza Vetro-Cella": false, // showGlassCell
    "Distanza Vetro-Ribbon": false, // showGlassRibbon
    "Mostra Warnings": false, // showWarnings
  };

  // Yield Settings
  bool _includeNCInYield = true;
  bool _excludeSaldaturaDefects = false;

  bool _loading = true;
  bool _isSaving = false;

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

        _alwaysExportHistory =
            settings['always_export_history'] as bool? ?? true;
        _exportMBJImage = settings['export_mbj_image'] as bool? ?? true;

        final mbjExportFields =
            settings['mbj_fields'] as Map<String, dynamic>? ?? {};
        for (final entry in _mbjFields.entries) {
          _mbjFields[entry.key] = mbjExportFields[entry.key] ?? entry.value;
        }

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
    setState(() => _isSaving = true);

    final settings = {
      'min_cycle_threshold': _minCycleSeconds,
      'include_nc_in_yield': _includeNCInYield,
      'exclude_saldatura_from_yield': _excludeSaldaturaDefects,
      'thresholds': _thresholds,
      'moduli_window': _moduliWindow,
      'enable_consecutive_ko': _enableConsecutiveKO,
      'consecutive_ko_limit': _consecutiveKOLimit,
      'always_export_history': _alwaysExportHistory,
      'export_mbj_image': _exportMBJImage,
      'mbj_fields': _mbjFields,
    };

    try {
      await ApiService.setAllSettings(settings);
      await ApiService.refreshBackendSettings();

      // ✅ Success Snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Impostazioni salvate correttamente'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // ❌ Error Snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore durante il salvataggio:\n$e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildCard(Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F7), // Apple background color
        body: const Center(
          child: CupertinoActivityIndicator(radius: 16),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Apple background color
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Impostazioni',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        elevation: 0.5,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF007AFF)), // Apple blue
      ),
      body: SafeArea(
        child: ListView(
          children: [
            // Cycle Time Section
            ExpansionTile(
              initiallyExpanded: false,
              title: Row(
                children: const [
                  Icon(CupertinoIcons.timer,
                      size: 20, color: CupertinoColors.systemGrey),
                  SizedBox(width: 8),
                  Text(
                    'TEMPO CICLO',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
              children: [
                _buildCard(
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tempo Ciclo Minimo',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Minimo tempo (in secondi) per considerare un ciclo come "Controllato"',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CupertinoSlider(
                                value: _minCycleSeconds,
                                min: 1,
                                max: 60,
                                divisions: 59,
                                onChanged: (val) {
                                  setState(() => _minCycleSeconds = val);
                                },
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9E9EB),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_minCycleSeconds.round()}s',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Stringatrice Section
            ExpansionTile(
              initiallyExpanded: false,
              title: Row(
                children: const [
                  Icon(CupertinoIcons.exclamationmark_triangle,
                      size: 20, color: CupertinoColors.systemGrey),
                  SizedBox(width: 8),
                  Text(
                    'STRINGATRICE',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
              children: [
                _buildCard(
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Configurazione Difetti',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configura soglie per allarmi specifici a difetto',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._stringaDefects.map((defect) => Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9F9FB),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFE5E5EA)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    defect,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Range di Moduli',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            CupertinoTextField(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 12),
                                              placeholder: 'Moduli',
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: BoxDecoration(
                                                color: CupertinoColors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFFD1D1D6)),
                                              ),
                                              controller: TextEditingController(
                                                  text: _moduliWindow[defect]
                                                      ?.toString()),
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
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Numero NG',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            CupertinoTextField(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 12),
                                              placeholder: 'Soglia',
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: BoxDecoration(
                                                color: CupertinoColors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFFD1D1D6)),
                                              ),
                                              controller: TextEditingController(
                                                  text: _thresholds[defect]
                                                      ?.toString()),
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
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Text(
                                        'Abilita avviso su NG consecutivi',
                                        style: TextStyle(fontSize: 15),
                                      ),
                                      CupertinoSwitch(
                                        value: _enableConsecutiveKO[defect] ??
                                            false,
                                        activeColor: const Color(0xFF007AFF),
                                        onChanged: (val) {
                                          setState(() =>
                                              _enableConsecutiveKO[defect] =
                                                  val);
                                        },
                                      ),
                                    ],
                                  ),
                                  if (_enableConsecutiveKO[defect] == true) ...[
                                    const SizedBox(height: 16),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Numero NG Consecutivi',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        CupertinoTextField(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 12),
                                          placeholder: 'NG Consecutivi',
                                          keyboardType: TextInputType.number,
                                          decoration: BoxDecoration(
                                            color: CupertinoColors.white,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: const Color(0xFFD1D1D6)),
                                          ),
                                          controller: TextEditingController(
                                              text: _consecutiveKOLimit[defect]
                                                  ?.toString()),
                                          onChanged: (val) {
                                            final parsed = int.tryParse(val);
                                            if (parsed != null) {
                                              setState(() =>
                                                  _consecutiveKOLimit[defect] =
                                                      parsed);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            ExpansionTile(
              initiallyExpanded: false,
              title: Row(
                children: const [
                  Icon(Icons.download,
                      size: 20, color: CupertinoColors.systemGrey),
                  SizedBox(width: 8),
                  Text(
                    'ESPORTAZIONE',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
              children: [
                // 📦 GENERALI
                _buildCard(
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Generali',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Impostazioni generali di esportazione',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Esporta sempre tutta la storia del Modulo',
                              style: TextStyle(fontSize: 15),
                            ),
                            CupertinoSwitch(
                              value: _alwaysExportHistory,
                              activeColor: const Color(0xFF007AFF),
                              onChanged: (val) {
                                setState(() => _alwaysExportHistory = val);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 📷 MBJ
                _buildCard(
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MBJ',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Seleziona cosa esportare per l'MBJ",
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Esporta immagine',
                                style: TextStyle(fontSize: 15)),
                            CupertinoSwitch(
                              value: _exportMBJImage,
                              activeColor: const Color(0xFF007AFF),
                              onChanged: (val) {
                                setState(() => _exportMBJImage = val);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'Misure da esportare',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),

                        // Loop over all MBJ fields
                        ..._mbjFields.keys.map((field) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                field,
                                style: const TextStyle(fontSize: 15),
                              ),
                              CupertinoSwitch(
                                value: _mbjFields[field]!,
                                activeColor: const Color(0xFF007AFF),
                                onChanged: (val) {
                                  setState(() => _mbjFields[field] = val);
                                },
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Yield Calculation Section
            /*_buildSectionHeader('Calcolo Yield', CupertinoIcons.chart_bar),
            _buildCard(
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Calcolo TPY',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configurazione parametri per il calcolo dello yield',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9FB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            title: const Text(
                                'Includi "NC" nel calcolo dello Yield'),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            trailing: CupertinoSwitch(
                              value: _includeNCInYield,
                              activeColor: const Color(0xFF007AFF),
                              onChanged: (val) {
                                setState(() => _includeNCInYield = val);
                              },
                            ),
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          ListTile(
                            title: const Text(
                                'Escludi difetti di Saldatura dallo Yield'),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            trailing: CupertinoSwitch(
                              value: _excludeSaldaturaDefects,
                              activeColor: const Color(0xFF007AFF),
                              onChanged: (val) {
                                setState(() => _excludeSaldaturaDefects = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),*/
            const SizedBox(height: 32),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSaving ? null : _saveSettings,
        backgroundColor: const Color(0xFF007AFF),
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Icon(Icons.save, color: Colors.white),
      ),
    );
  }
}
