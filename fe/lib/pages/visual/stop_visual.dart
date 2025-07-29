// stop_visual.dart
// ignore_for_file: use_build_context_synchronously, non_constant_identifier_names, deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/services/api_service.dart';
import 'package:intl/intl.dart';

class StopButton extends StatelessWidget {
  final int lastNShifts;
  final int? linkedProductionId;
  final VoidCallback? onStopsUpdated;
  final ValueChanged<Map<String, dynamic>>? onStopStarted;

  const StopButton({
    super.key,
    required this.lastNShifts,
    this.linkedProductionId,
    this.onStopsUpdated,
    this.onStopStarted,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange.withOpacity(0.85),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 10,
      ),
      icon: const Icon(Icons.timer, color: Colors.white),
      label: const Text(
        'Fermi',
        style: TextStyle(fontSize: 18, color: Colors.white),
      ),
      onPressed: () {
        showDialog(
          context: context,
          builder: (_) => _StopDialog(
            lastNShifts: lastNShifts,
            linkedProductionId: linkedProductionId,
            onStopsUpdated: onStopsUpdated,
            onStopStarted: onStopStarted,
          ),
        );
      },
    );
  }
}

class _StopDialog extends StatefulWidget {
  final int lastNShifts;
  final int? linkedProductionId;
  final VoidCallback? onStopsUpdated;
  final ValueChanged<Map<String, dynamic>>? onStopStarted;

  const _StopDialog({
    required this.lastNShifts,
    this.linkedProductionId,
    this.onStopsUpdated,
    this.onStopStarted,
  });

  @override
  State<_StopDialog> createState() => _StopDialogState();
}

class _StopDialogState extends State<_StopDialog> {
  final ApiService _api = ApiService();

  // UI + Data state
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _editReasonCtrl = TextEditingController();
  final Map<String, int> _stationNameToId = const {
    'AIN01': 29,
    'AIN02': 30,
    'STR01': 4,
    'STR02': 5,
    'STR03': 6,
    'STR04': 7,
    'STR05': 8,
  };

  bool _busy = false;
  bool _showClosed = false;
  int? _selectedIndex;
  String? _selectedStation;
  int? _stopId;

  Timer? _timer;
  DateTime? _start;
  Duration _elapsed = Duration.zero;
  bool _editingReason = false;

  List<Map<String, dynamic>> _stops = [];

  @override
  void initState() {
    super.initState();
    _fetchStops();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_start != null && mounted) {
        setState(() => _elapsed = DateTime.now().difference(_start!));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reasonCtrl.dispose();
    _editReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStops({int? keepSelectedId}) async {
    setState(() => _busy = true);
    final List<Map<String, dynamic>> newList = [];

    for (final entry in _stationNameToId.entries) {
      final res = await _api.getStopsForStation(entry.value,
          shiftsBack: widget.lastNShifts);
      if (res != null && res['status'] == 'ok' && res['stops'] != null) {
        for (final s in res['stops']) {
          if (s['stop_type'] == 'STOP') {
            newList.add(_normalizeStop(s, station: entry.key));
          }
        }
      }
    }

    // --- Ensure current running stop stays in the list ---
    if (_stopId != null && newList.every((e) => e['id'] != _stopId)) {
      newList.add({
        'id': _stopId,
        'title': _reasonCtrl.text,
        'status': 'OPEN',
        'station': _selectedStation,
        'start_time': _start,
        'end_time': null,
      });
    }

    newList.sort((a, b) => b['id'].compareTo(a['id']));

    if (keepSelectedId != null) {
      final active = newList.where((e) => e['status'] != 'CLOSED').toList();
      final idx = active.indexWhere((e) => e['id'] == keepSelectedId);
      _selectedIndex = idx >= 0 ? idx : null;
    }

    setState(() {
      _stops = newList;
      _busy = false;
    });
    if (_stopId == null || _stops.every((s) => s['status'] != 'OPEN')) {
      widget.onStopsUpdated?.call();
    }
  }

  Map<String, dynamic> _normalizeStop(Map<String, dynamic> s,
      {String? station}) {
    return {
      'id': s['id'],
      'title': s['reason'] ?? s['title'] ?? 'Fermo',
      'status': s['status'],
      'station': station ?? s['station'],
      'start_time': s['start_time'] is DateTime
          ? s['start_time']
          : DateTime.tryParse(s['start_time'].toString()),
      'end_time': s['end_time'] == null
          ? null
          : (s['end_time'] is DateTime
              ? s['end_time']
              : DateTime.tryParse(s['end_time'].toString())),
    };
  }

  Future<void> _startStop() async {
    if (_selectedStation == null || _reasonCtrl.text.isEmpty) return;
    final now = DateTime.now();

    final res = await _api.createStop(
      stationId: _stationNameToId[_selectedStation!]!,
      startTime: now.toIso8601String().split('.').first,
      operatorId: 'NO OPERATOR',
      stopType: 'STOP',
      reason: _reasonCtrl.text,
      status: 'OPEN',
      linkedProductionId: widget.linkedProductionId,
    );

    if (res != null && res['status'] == 'ok') {
      _stopId = res['stop_id'];
      _start = now;
      _elapsed = Duration.zero;
      widget.onStopStarted?.call({
        'id': _stopId,
        'station': _selectedStation,
        'reason': _reasonCtrl.text,
        'start': _start,
      });
      await _fetchStops(keepSelectedId: _stopId);
    }
  }

  Future<void> _stopStop() async {
    if (_stopId != null) {
      await _api.updateStopStatus(
        stopId: _stopId!,
        newStatus: 'CLOSED',
        changedAt: DateTime.now().toIso8601String().split('.').first,
        operatorId: 'NO OPERATOR',
      );
      await _fetchStops();
    }
  }

  Future<void> _updateReason(int id) async {
    if (_editReasonCtrl.text.isEmpty) return;
    setState(() => _busy = true);
    final res =
        await _api.updateStopReason(stopId: id, reason: _editReasonCtrl.text);
    if (res != null) {
      await _fetchStops(keepSelectedId: id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update failed')),
      );
    }
    setState(() {
      _busy = false;
      _editingReason = false;
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return Colors.orange;
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
      case 'CLOSED':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeStops = _stops.where((e) => e['status'] != 'CLOSED').toList();
    final closedStops = _stops.where((e) => e['status'] == 'CLOSED').toList();

    return Material(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: 1100,
          height: 750,
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Row(
                  children: [
                    _buildSidebar(activeStops),
                    Expanded(
                      child: _showClosed
                          ? _buildClosedView(closedStops)
                          : (_selectedIndex == null ||
                                  _selectedIndex! >= activeStops.length)
                              ? _buildCreateForm()
                              : _buildDetail(activeStops[_selectedIndex!]),
                    ),
                  ],
                ),
                if (_busy) _buildLoadingOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Sidebar ----
  Widget _buildSidebar(List activeStops) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE5E5E7), width: 1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E5E7))),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.close,
                        size: 18, color: Color(0xFF8E8E93)),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Fermi',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = null),
              child: Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF007AFF).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Nuovo Fermo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: activeStops.isEmpty
                ? const Center(child: Text('Nessun fermo attivo'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: activeStops.length,
                    itemBuilder: (_, i) {
                      final e = activeStops[i];
                      final isSelected = _selectedIndex == i;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedIndex = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF007AFF).withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(color: const Color(0xFF007AFF))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: _statusColor(e['status'])
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(_statusIcon(e['status']),
                                      color: _statusColor(e['status']),
                                      size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    e['title'],
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF007AFF)
                                          : const Color(0xFF1C1C1E),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE5E5E7))),
            ),
            child: GestureDetector(
              onTap: () => setState(() => _showClosed = true),
              child: Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  color: _showClosed
                      ? const Color(0xFF34C759)
                      : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history,
                        color: _showClosed
                            ? Colors.white
                            : const Color(0xFF8E8E93)),
                    const SizedBox(width: 8),
                    Text(
                      'Fermi Chiusi',
                      style: TextStyle(
                        color: _showClosed
                            ? Colors.white
                            : const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Create Form ----
  Widget _buildCreateForm() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nuovo Fermo',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crea un nuovo fermo macchina',
            style: TextStyle(fontSize: 16, color: Color(0xFF8E8E93)),
          ),
          const SizedBox(height: 40),
          const Text('Stazione', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedStation,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: _stationNameToId.keys
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _selectedStation = v),
          ),
          const SizedBox(height: 24),
          const Text('Motivo', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Descrivi il motivo del fermo...',
              border: OutlineInputBorder(),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _startStop,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Avvia Fermo',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Detail (running or open stop) ----
  Widget _buildDetail(Map<String, dynamic> stop) {
    final start = stop['start_time'] ?? DateTime.now();
    final duration = DateTime.now().difference(start);

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: _editingReason
                  ? TextField(
                      controller: _editReasonCtrl,
                      maxLines: 2,
                      autofocus: true,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                          hintText: 'Titolo fermo...',
                          border: InputBorder.none),
                    )
                  : Text(stop['title'],
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () {
                if (_editingReason) {
                  _updateReason(stop['id']);
                } else {
                  setState(() {
                    _editingReason = true;
                    _editReasonCtrl.text = stop['title'];
                  });
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _editingReason ? Icons.check : Icons.edit_outlined,
                  color: const Color(0xFF007AFF),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E5E7)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _statusColor(stop['status']).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      _statusIcon(stop['status']),
                      color: _statusColor(stop['status']),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _statusColor(stop['status']),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(stop['status'],
                        style: const TextStyle(color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 20),
                Text('Durata: ${_formatDuration(duration)}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                if (stop['status'] == 'OPEN')
                  ElevatedButton(
                    onPressed: _stopStop,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Ferma Timer',
                        style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Closed list ----
  Widget _buildClosedView(List closed) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: closed.isEmpty
          ? const Center(child: Text('Nessun fermo chiuso'))
          : ListView.builder(
              itemCount: closed.length,
              itemBuilder: (_, i) {
                final e = closed[i];
                final start = e['start_time'] ?? DateTime.now();
                final end = e['end_time'] ?? start;
                final duration = end.difference(start);
                return ListTile(
                  title: Text(e['title']),
                  subtitle: Text(
                      "${DateFormat('dd/MM HH:mm').format(start)} - ${DateFormat('dd/MM HH:mm').format(end)} • ${_formatDuration(duration)}"),
                  trailing: Icon(Icons.check_circle, color: Colors.green),
                );
              }),
    );
  }

  // ---- Busy Overlay ----
  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
          ),
        ),
      ),
    );
  }
}
