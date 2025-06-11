// escalation_visual_page.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import '../../shared/services/api_service.dart';

class EscalationButton extends StatelessWidget {
  final int? linkedProductionId;
  const EscalationButton({super.key, this.linkedProductionId});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.withOpacity(0.85),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 10,
      ),
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
      label: const Text(
        'Escalation',
        style: TextStyle(
            fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (_) =>
              _EscalationDialog(linkedProductionId: linkedProductionId),
        );
      },
    );
  }
}

class _EscalationDialog extends StatefulWidget {
  final int? linkedProductionId;

  const _EscalationDialog({this.linkedProductionId});

  @override
  State<_EscalationDialog> createState() => _EscalationDialogState();
}

class _EscalationDialogState extends State<_EscalationDialog> {
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _operatorCtrl = TextEditingController();
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _escalations = [];
  int? _selectedIndex; // null = creating new
  String? _selectedStation;
  String? _selectedType;
  String? _selectedStatus;
  bool _showClosed = false;
  bool _busy = false;

  final Map<String, int> stationNameToId = {
    "MIN01": 1,
    "MIN02": 2,
    "AIN01": 29,
    "AIN02": 30,
  };

  final List<String> stationNames = ["MIN01", "MIN02", "AIN01", "AIN02"];
  final List<String> stopTypes = [
    "ESCALATION",
    "STOP",
    "MAINTENANCE",
    "QUALITY"
  ];
  final List<String> statusCreation = [
    "OPEN",
    "SHIFT_MANAGER",
    "HEAD_OF_PRODUCTION",
    "MAINTENANCE_TEAM"
  ];
  final List<String> statusFull = [
    "OPEN",
    "SHIFT_MANAGER",
    "HEAD_OF_PRODUCTION",
    "MAINTENANCE_TEAM",
    "CLOSED"
  ];

  int convertStationNameToId(String name) {
    return stationNameToId[name] ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _fetchExistingStops();
  }

  Future<void> _fetchExistingStops() async {
    setState(() => _busy = true);
    _escalations.clear();

    for (final entry in stationNameToId.entries) {
      final stationId = entry.value;

      final res = await _api.getStopsForStation(stationId);
      if (res != null && res['status'] == 'ok' && res['stops'] != null) {
        for (final stop in res['stops']) {
          _escalations.add({
            'id': stop['id'],
            'title': '${stop['reason']}',
            'status': stop['status'],
          });
        }
      }
      _escalations.sort((a, b) => b['id'].compareTo(a['id']));
    }

    setState(() => _busy = false);
  }

  Future<void> _save() async {
    if (_selectedIndex == null) {
      final reason = _reasonCtrl.text.trim();

      if (reason.isEmpty ||
          _selectedStation == null ||
          _selectedType == null ||
          _selectedStatus == null) return;

      final int operatorId = 0;
      String chosenText = reason;
      final payloadSuccess = await _callCreateStop(chosenText, operatorId);
      if (!payloadSuccess) print("❌ Failed payloadSuccess");
    } else {
      final esc = _escalations[_selectedIndex!];
      if (esc['status'] == _selectedStatus) {
        return;
      }
      final success = await _callUpdateStatus(esc['id']);
      if (!success) print("❌ Failed success");
    }
  }

  Future<bool> _callCreateStop(String reason, int operatorId) async {
    setState(() => _busy = true);
    final nowIso = DateTime.now().toIso8601String();
    final res = await _api.createStop(
      stationId: convertStationNameToId(_selectedStation!),
      startTime: nowIso,
      operatorId: operatorId,
      stopType: _selectedType!,
      reason: reason,
      status: _selectedStatus!,
      linkedProductionId: widget.linkedProductionId,
    );
    setState(() => _busy = false);

    if (res != null && res['stop_id'] != null) {
      _escalations.add({
        'id': res['stop_id'],
        'title':
            '🟠 ${reason.length > 20 ? '${reason.substring(0, 20)}…' : reason}',
        'status': _selectedStatus,
      });
      _reasonCtrl.clear();
      _operatorCtrl.clear();
      _selectedStation = null;
      _selectedType = null;
      _selectedStatus = null;
      return true;
    } else {
      _snack('Creazione fallita, riprova.');
      return false;
    }
  }

  Future<bool> _callUpdateStatus(int stopId) async {
    setState(() => _busy = true);
    final nowIso = DateTime.now().toIso8601String();
    final res = await _api.updateStopStatus(
      stopId: stopId,
      newStatus: _selectedStatus!,
      changedAt: nowIso,
      operatorId: 0,
    );
    setState(() => _busy = false);

    if (res != null) {
      _escalations[_selectedIndex!]['status'] = _selectedStatus;
      return true;
    } else {
      _snack('Aggiornamento fallito, riprova.');
      return false;
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Dialog(
          backgroundColor: Colors.white,
          child: SizedBox(
            width: 1000,
            height: 700,
            child: Row(
              children: [
                Container(
                  width: 240,
                  color: Colors.grey[100],
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: _escalations.length + 1,
                          itemBuilder: (_, i) {
                            final isNew = i == _escalations.length;
                            final isSel = isNew
                                ? _selectedIndex == null
                                : _selectedIndex == i;
                            return _buildListItem(i, isNew, isSel);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade800,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.history, color: Colors.white),
                          label: const Text('Visualizza Chiuse',
                              style: TextStyle(color: Colors.white)),
                          onPressed: () {
                            setState(() {
                              _showClosed = true;
                              _selectedIndex = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _showClosed
                        ? _ClosedView(
                            stops: _escalations
                                .where((e) => e['status'] == 'Closed')
                                .toList(),
                            onBack: () => setState(() => _showClosed = false),
                          )
                        : _buildEditor(),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_busy)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildEditor() {
    final statuses = _selectedIndex == null ? statusCreation : statusFull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            _selectedIndex == null
                ? 'Crea Nuova Escalation'
                : 'Modifica Escalation',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        if (_selectedIndex == null) ...[
          DropdownButtonFormField<String>(
            value: _selectedStation,
            hint: const Text("Seleziona Stazione"),
            items: stationNames
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _selectedStation = v),
          ),
          const SizedBox(height: 16),
          /*TextField(
            controller: _operatorCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Operator ID', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),*/
          DropdownButtonFormField<String>(
            value: _selectedType,
            hint: const Text("Seleziona Tipo"),
            items: stopTypes
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _selectedType = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Motivo del blocco', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
        ],
        DropdownButtonFormField<String>(
          value: _selectedStatus,
          hint: const Text("Seleziona Stato"),
          items: statuses
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _selectedStatus = v),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _save, child: const Text('Salva')),
          ],
        ),
      ],
    );
  }

  Color statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return Colors.orange.shade300;
      case 'SHIFT_MANAGER':
        return Colors.amber.shade600;
      case 'HEAD_OF_PRODUCTION':
        return Colors.red.shade400;
      case 'MAINTENANCE_TEAM':
        return Colors.teal.shade400;
      case 'CLOSED':
        return Colors.green.shade400;
      default:
        return Colors.grey.shade300;
    }
  }

  Widget _buildListItem(int i, bool isNew, bool isSel) {
    final esc = isNew ? null : _escalations[i];
    final cardColor = isNew ? Colors.white : statusColor(esc!['status']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Card(
        color: isSel ? cardColor.withOpacity(0.4) : cardColor.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSel ? Colors.blue : Colors.grey.shade300,
            width: 2,
          ),
        ),
        elevation: isSel ? 4 : 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              if (isNew) {
                _selectedIndex = null;
                _selectedStatus = null;
              } else {
                _selectedIndex = i;
                _selectedStatus = esc!['status'];
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reason (title)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isNew
                          ? Icons.add_circle_outline
                          : Icons.warning_amber_rounded,
                      size: 28,
                      color: isSel ? Colors.blue : Colors.black54,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isNew ? 'Nuova Escalation' : esc!['title']!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Status & eventual station/type
                Row(
                  children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor(esc?['status'] ?? ''),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: isNew
                            ? const SizedBox()
                            : Text(
                                esc?['status'] ?? '',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              )),
                    const SizedBox(width: 10),
                    // You could also add station/type here later
                    // Text("MIN01", style: TextStyle(fontSize: 12, color: Colors.black54))
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClosedView extends StatelessWidget {
  final List<Map<String, dynamic>> stops;
  final VoidCallback onBack;
  const _ClosedView({required this.stops, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Escalation Chiuse',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: stops
                .map((e) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading:
                            const Icon(Icons.check_circle, color: Colors.green),
                        title: Text(e['title']),
                        subtitle: const Text('Stato: Closed'),
                      ),
                    ))
                .toList(),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('Torna'),
            onPressed: onBack,
          ),
        ),
      ],
    );
  }
}
