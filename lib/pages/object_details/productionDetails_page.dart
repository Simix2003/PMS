import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ix_monitor/shared/utils/helpers.dart';

import '../../shared/services/api_service.dart';

class ProductionDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const ProductionDetailPage({super.key, required this.data});

  @override
  State<ProductionDetailPage> createState() => _ProductionDetailPageState();
}

class _ProductionDetailPageState extends State<ProductionDetailPage> {
  List<String> _issuePaths = [];
  List<Map<String, String>> _pictures = [];

  @override
  void initState() {
    super.initState();
    _fetchDefects();
  }

  Future<void> _fetchDefects() async {
    final idModulo = widget.data['id_modulo'];
    final productionId = widget.data['production_id'];

    final result = await ApiService.fetchInitialIssuesForObject(
      idModulo,
      productionId: productionId.toString(),
    );

    setState(() {
      _issuePaths = result['issue_paths'];
      _pictures = List<Map<String, String>>.from(result['pictures']);
    });
  }

  String _formatDefectPath(String path) {
    // Remove the leading parts
    final parts =
        path.replaceFirst('Dati.Esito.Esito_Scarto.Difetti.', '').split('.');

    if (parts.isEmpty) return path;

    final category = parts[0];

    switch (category) {
      case 'Generali':
        return 'Generale: ${parts.length > 1 ? parts[1] : 'N/A'}';

      case 'Altro':
        return 'Altro: ${path.split(':').last.trim()}';

      case 'Saldatura':
        final stringa = RegExp(r'Stringa\[(\d+)\]').firstMatch(path)?.group(1);
        final pin = RegExp(r'Pin\[(\d+)\]').firstMatch(path)?.group(1);
        final lato = parts.last;
        return 'Saldatura: Stringa $stringa, Pin $pin, Lato $lato';

      case 'Disallineamento':
        if (path.contains('Stringa')) {
          final stringa =
              RegExp(r'Stringa\[(\d+)\]').firstMatch(path)?.group(1);
          return 'Disallineamento: Stringa $stringa';
        } else {
          final ribbon = RegExp(r'Ribbon\[(\d+)\]').firstMatch(path)?.group(1);
          final lato = parts.last;
          return 'Disallineamento: Ribbon $ribbon, Lato $lato';
        }

      case 'Mancanza Ribbon':
        final ribbon = RegExp(r'Ribbon\[(\d+)\]').firstMatch(path)?.group(1);
        final lato = parts.last;
        return 'Mancanza Ribbon: $ribbon, Lato $lato';

      case 'I_Ribbon Leadwire':
        final ribbon = RegExp(r'Ribbon\[(\d+)\]').firstMatch(path)?.group(1);
        final lato = parts.last;
        return 'I_Ribbon Leadwire: Ribbon $ribbon, Lato $lato';

      case 'Macchie ECA':
      case 'Celle Rotte':
      case 'Lunghezza String Ribbon':
      case 'Graffio su Cella':
        final stringa = RegExp(r'Stringa\[(\d+)\]').firstMatch(path)?.group(1);
        return '$category: Stringa $stringa';

      default:
        return category;
    }
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return 'N/A';
    try {
      return DateFormat('dd MMM yyyy – HH:mm').format(DateTime.parse(value));
    } catch (_) {
      return value.toString();
    }
  }

  String _formatCycleTime(dynamic value) {
    if (value == null) return '-';
    if (value is int) {
      final duration = Duration(seconds: value);
      return duration.toString().split('.').first.padLeft(8, "0");
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final esito = widget.data['esito'] as int?;
    final statusColor = getStatusColor(esito);

    return Scaffold(
      appBar: AppBar(
        title: Text('ID Modulo: ${widget.data['id_modulo']}'),
        foregroundColor: Colors.white,
        backgroundColor: statusColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // STATUS CARD
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: statusColor.withOpacity(0.9),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Esito Produzione',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        getStatusLabel(esito),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // GENERAL INFO
          _buildSectionTitle('Informazioni Generali'),
          _buildInfoTile(
              Icons.factory, 'Linea', widget.data['line_display_name']),
          _buildInfoTile(Icons.precision_manufacturing, 'Stazione',
              widget.data['station_name']),
          _buildInfoTile(Icons.person, 'Operatore', widget.data['operator_id']),
          _buildInfoTile(Icons.timer_outlined, 'Tempo ciclo',
              _formatCycleTime(widget.data['cycle_time'])),
          const SizedBox(height: 20),

          // TIMINGS
          _buildSectionTitle('Tempi'),
          _buildInfoTile(Icons.login, 'Ingresso',
              _formatDateTime(widget.data['start_time'])),
          _buildInfoTile(
              Icons.logout, 'Uscita', _formatDateTime(widget.data['end_time'])),
          const SizedBox(height: 20),

          // DEFECTS
          _buildSectionTitle('Difetti Rilevati'),
          if (_issuePaths.isEmpty)
            Text('Nessun difetto rilevato.',
                style: TextStyle(color: Colors.green.shade700, fontSize: 16))
          else
            Column(
              children: _issuePaths.map((defect) {
                final photo = _pictures.firstWhere(
                  (p) => p['defect'] == defect,
                  orElse: () => {},
                );

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.warning,
                        color: Colors.red,
                        size: 24,
                      ),
                      title: Text(_formatDefectPath(defect)),
                      trailing: photo.isNotEmpty
                          ? ElevatedButton.icon(
                              icon: const Icon(
                                Icons.image,
                                size: 32,
                                color: Colors.white,
                              ),
                              label: const Text("Visualizza Immagine"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    appBar: AppBar(
                                        title: const Text("Foto Difetto")),
                                    body: Center(
                                      child: Image.memory(
                                        base64Decode(
                                            photo['image']!.split(',').last),
                                      ),
                                    ),
                                  ),
                                ));
                              },
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String? value) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(value ?? '-', style: const TextStyle(fontSize: 16)),
    );
  }
}
