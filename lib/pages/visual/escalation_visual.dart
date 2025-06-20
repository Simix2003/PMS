// escalation_visual_page.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, non_constant_identifier_names

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../shared/models/globals.dart';
import '../../shared/services/api_service.dart';

class EscalationButton extends StatelessWidget {
  final int? linkedProductionId;
  final int last_n_shifts;
  final VoidCallback? onEscalationsUpdated;

  const EscalationButton({
    super.key,
    this.linkedProductionId,
    required this.last_n_shifts,
    required this.onEscalationsUpdated,
  });

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
          builder: (_) => _EscalationDialog(
            last_n_shifts: last_n_shifts,
            linkedProductionId: linkedProductionId,
            onEscalationsUpdated: onEscalationsUpdated,
          ),
        );
      },
    );
  }
}

class _EscalationDialog extends StatefulWidget {
  final int last_n_shifts;
  final int? linkedProductionId;
  final VoidCallback? onEscalationsUpdated;

  const _EscalationDialog(
      {required this.last_n_shifts,
      this.linkedProductionId,
      this.onEscalationsUpdated});

  @override
  State<_EscalationDialog> createState() => _EscalationDialogState();
}

class _EscalationDialogState extends State<_EscalationDialog> {
  final ApiService _api = ApiService();
  final String operatorId = 'NO OPERATOR';
  Timer? _timer;
  bool _busy = false;
  bool _showClosed = false;
  int? _selectedIndex;

  final stationNameToId = {
    "AIN01": 29,
    "AIN02": 30,
  };

  final stopTypes = ["ESCALATION"];
  static const List<String> statusCreation = [
    "OPEN",
    "SHIFT_MANAGER",
    "HEAD_OF_PRODUCTION",
  ];
  static const List<String> statusFull = [...statusCreation, "CLOSED"];

  String? _newStation;
  String? _newType;
  String? _newStatus;
  final TextEditingController _reasonCtrl = TextEditingController();

  bool _editingReason = false;
  final TextEditingController _editReasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchExistingStops();
    _timer = Timer.periodic(Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _editReasonCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchExistingStops({int? keepSelectedId}) async {
    setState(() => _busy = true);
    escalations.clear();
    for (final entry in stationNameToId.entries) {
      final res = await _api.getStopsForStation(entry.value,
          shiftsBack: widget.last_n_shifts);
      if (res != null && res['status'] == 'ok' && res['stops'] != null) {
        for (final stop in res['stops']) {
          escalations.add({
            'id': stop['id'],
            'title': stop['reason'],
            'status': stop['status'],
            'station': entry.key,
            'start_time': DateTime.parse(stop['start_time']),
            'end_time': stop['end_time'] != null
                ? DateTime.parse(stop['end_time'])
                : null,
          });
        }
      }
    }
    escalations.sort((a, b) => b['id'].compareTo(a['id']));

    // After data fully loaded → restore selection
    if (keepSelectedId != null) {
      final activeEscalations =
          escalations.where((e) => e['status'] != 'CLOSED').toList();
      final newIndex =
          activeEscalations.indexWhere((e) => e['id'] == keepSelectedId);
      _selectedIndex = newIndex >= 0 ? newIndex : null;
    }

    setState(() => _busy = false);
    widget.onEscalationsUpdated?.call();
  }

  Future<void> _createNewEscalation() async {
    if (_newStation == null ||
        _newType == null ||
        _newStatus == null ||
        _reasonCtrl.text.isEmpty) return;
    setState(() => _busy = true);
    final nowIso = DateTime.now().toIso8601String().split('.').first;

    await _api.createStop(
      stationId: stationNameToId[_newStation!]!,
      startTime: nowIso,
      operatorId: operatorId,
      stopType: _newType!,
      reason: _reasonCtrl.text,
      status: _newStatus!,
      linkedProductionId: widget.linkedProductionId,
    );
    await _fetchExistingStops();
    setState(() {
      _busy = false;
      _reasonCtrl.clear();
      _newStation = null;
      _newType = null;
      _newStatus = null;
    });
  }

  Future<void> _updateStatus(int id, String newStatus) async {
    setState(() => _busy = true);
    final nowIso = DateTime.now().toIso8601String().split('.').first;
    final res = await _api.updateStopStatus(
      stopId: id,
      newStatus: newStatus,
      changedAt: nowIso,
      operatorId: 'NO OPERATOR',
    );

    if (res != null) {
      await _fetchExistingStops(keepSelectedId: id);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed')));
    }
    setState(() => _busy = false);
  }

  Future<void> _updateReason(int id) async {
    if (_editReasonCtrl.text.isEmpty) return;
    setState(() => _busy = true);
    final res = await _api.updateStopReason(
      stopId: id,
      reason: _editReasonCtrl.text,
    );
    if (res != null) {
      await _fetchExistingStops(keepSelectedId: id);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed')));
    }
    setState(() {
      _busy = false;
      _editingReason = false;
    });
  }

  String _formatDuration(Duration duration) {
    return "${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return Colors.orange;
      case 'SHIFT_MANAGER':
        return Colors.amber;
      case 'HEAD_OF_PRODUCTION':
        return Colors.red;
      case 'MAINTENANCE_TEAM':
        return Colors.teal;
      case 'CLOSED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'OPEN':
        return Icons.timelapse;
      case 'SHIFT_MANAGER':
        return Icons.manage_accounts;
      case 'HEAD_OF_PRODUCTION':
        return Icons.warning_amber;
      case 'MAINTENANCE_TEAM':
        return Icons.build;
      case 'CLOSED':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeEscalations =
        escalations.where((e) => e['status'] != 'CLOSED').toList();
    final closedEscalations =
        escalations.where((e) => e['status'] == 'CLOSED').toList();

    return Stack(
      children: [
        Dialog(
          backgroundColor: Colors.white,
          child: SizedBox(
            width: 1000,
            height: 700,
            child: Row(
              children: [
                _buildSidebar(activeEscalations),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _showClosed
                        ? _buildClosedView(closedEscalations)
                        : (_selectedIndex == null ||
                                _selectedIndex! >= activeEscalations.length)
                            ? _buildCreateNewForm()
                            : _buildDetail(activeEscalations[_selectedIndex!]),
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

  Widget _buildSidebar(List activeEscalations) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.grey.shade200, Colors.white]),
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12.0),
            child: Row(
              children: [
                IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
                Text('ESCALATIONS',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text("Crea Nuovo"),
              onPressed: () => setState(() => _selectedIndex = null),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: activeEscalations.length,
              itemBuilder: (_, i) {
                final e = activeEscalations[i];
                final isSel = _selectedIndex == i;
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Card(
                    elevation: isSel ? 8 : 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    color: Colors.white.withOpacity(0.75),
                    child: ListTile(
                      leading: Icon(_statusIcon(e['status']),
                          color: _statusColor(e['status']), size: 30),
                      title: Text(e['title'],
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => setState(() => _selectedIndex = i),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _showClosed ? Colors.blueAccent : Colors.grey.shade800,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.history, color: Colors.white),
              label: const Text('Fermi Chiusi',
                  style: TextStyle(color: Colors.white)),
              onPressed: () => setState(() => _showClosed = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateNewForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Nuova Escalation",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          value: _newStation,
          hint: const Text("Seleziona Stazione"),
          items: stationNameToId.keys
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _newStation = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _newType,
          hint: const Text("Seleziona Tipo"),
          items: stopTypes
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _newType = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _newStatus,
          hint: const Text("Seleziona Stato"),
          items: statusCreation
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _newStatus = v),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Motivo', border: OutlineInputBorder()),
        ),
        const Spacer(),
        ElevatedButton(
            onPressed: _createNewEscalation, child: const Text("Salva"))
      ],
    );
  }

  Widget _buildClosedView(List closed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fermi Chiusi',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Expanded(
          child: closed.isEmpty
              ? const Center(child: Text("Nessun fermo chiuso"))
              : ListView(
                  children: closed.map((e) {
                    final duration = e['end_time'].difference(e['start_time']);
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading:
                            const Icon(Icons.check_circle, color: Colors.green),
                        title: Text(e['title']),
                        subtitle: Text(
                          "${DateFormat('HH:mm').format(e['start_time'])} - ${DateFormat('HH:mm').format(e['end_time'])}  (${_formatDuration(duration)})",
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              _handleDelete(e), // <-- implement this
                        ),
                        onTap: () => _showClosedDetail(e),
                      ),
                    );
                  }).toList(),
                ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('Torna'),
            onPressed: () => setState(() => _showClosed = false),
          ),
        ),
      ],
    );
  }

  void _handleDelete(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Sei sicuro?"),
        content: Text("Vuoi eliminare: '${item['title']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Annulla"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              setState(() => _busy = true);

              final res = await ApiService().deleteStop(item['id']);
              if (res != null && res['status'] == 'ok') {
                await _fetchExistingStops();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Errore durante l'eliminazione")),
                );
              }

              setState(() => _busy = false);
            },
            child: const Text("Elimina", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClosedDetail(Map<String, dynamic> esc) async {
    // Call your API when the card is clicked
    final res = await ApiService().getStopDetails(esc['id']);

    if (res == null || res['status'] != 'ok') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore durante il caricamento dei dettagli')));
      return;
    }

    final List history = res['stop']['levels'];

    showDialog(
      context: context,
      builder: (_) {
        final duration = esc['end_time'].difference(esc['start_time']);
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Dettagli Fermo"),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Motivo: ${esc['title']}", style: TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                Text("Stazione: ${esc['station']}"),
                const SizedBox(height: 12),
                Text(
                    "Inizio: ${DateFormat('HH:mm:ss').format(esc['start_time'])}"),
                const SizedBox(height: 12),
                Text("Fine: ${DateFormat('HH:mm:ss').format(esc['end_time'])}"),
                const SizedBox(height: 12),
                Text("Durata: ${_formatDuration(duration)}"),
                const SizedBox(height: 12),
                Divider(),
                Text("Storico Status:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildStatusHistoryFromApi(history),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Chiudi"))
          ],
        );
      },
    );
  }

  Widget _buildStatusHistoryFromApi(List history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: history.map<Widget>((entry) {
        final status = entry['status'];
        final ts = DateTime.parse(entry['changed_at']);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(_statusIcon(status), color: _statusColor(status), size: 20),
              SizedBox(width: 8),
              Text("$status @ ${DateFormat('HH:mm:ss').format(ts)}")
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetail(Map<String, dynamic> esc) {
    final now = DateTime.now();
    final end = esc['end_time'] ?? now;
    final duration = end.difference(esc['start_time']);

    return Center(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with edit
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _editingReason
                      ? TextField(
                          controller: _editReasonCtrl,
                          maxLines: 2,
                          autofocus: true,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(), hintText: 'Motivo'),
                        )
                      : Text(
                          esc['title'],
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                ),
                IconButton(
                  icon: Icon(_editingReason ? Icons.check : Icons.edit),
                  onPressed: () {
                    if (_editingReason) {
                      _updateReason(esc['id']);
                    } else {
                      setState(() {
                        _editingReason = true;
                        _editReasonCtrl.text = esc['title'];
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Status with icon + chip
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      _statusColor(esc['status']).withOpacity(0.15),
                  child: Icon(
                    _statusIcon(esc['status']),
                    size: 28,
                    color: _statusColor(esc['status']),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _statusColor(esc['status']),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    esc['status'],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Status update dropdown
            DropdownButtonFormField<String>(
              value: esc['status'],
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade100,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              items: statusFull
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) => _updateStatus(esc['id'], val!),
            ),
            const SizedBox(height: 24),

            // Additional info fields (station, start, duration)
            Row(
              children: [
                Icon(Icons.precision_manufacturing, color: Colors.black54),
                const SizedBox(width: 8),
                Text("Stazione: ${esc['station']}",
                    style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.play_circle, color: Colors.black54),
                const SizedBox(width: 8),
                Text(
                    "Inizio: ${DateFormat('HH:mm:ss').format(esc['start_time'])}",
                    style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.timer, color: Colors.black54),
                const SizedBox(width: 8),
                Text("Durata: ${_formatDuration(duration)}",
                    style: const TextStyle(fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
