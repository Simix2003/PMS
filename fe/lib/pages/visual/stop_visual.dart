// stop_visual.dart
// ignore_for_file: use_build_context_synchronously, non_constant_identifier_names, deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/services/api_service.dart';

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
  int? _selectedIndex;
  String? _selectedStation;
  bool _editingReason = false;

  List<Map<String, dynamic>> _stops = [];

  @override
  void initState() {
    super.initState();
    _fetchStops();

    // Rebuild every minute to refresh durations
    Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });

    // Refresh stop list every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (_) async {
      if (mounted) {
        await _fetchStops(
          keepSelectedId:
              _selectedIndex != null ? _stops[_selectedIndex!]['id'] : null,
        );
      }
    });
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _editReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStops({int? keepSelectedId}) async {
    setState(() => _busy = true);
    final List<Map<String, dynamic>> newList = [];

    for (final entry in _stationNameToId.entries) {
      final res = await _api.getStopsForStation(
        entry.value,
        shiftsBack: widget.lastNShifts,
        includeOpen: true, // Ensure OPEN stops are included
      );
      if (res != null && res['status'] == 'ok' && res['stops'] != null) {
        for (final s in res['stops']) {
          if (s['stop_type'] == 'STOP') {
            newList.add(_normalizeStop(s, station: entry.key));
          }
        }
      }
    }

    newList.sort((a, b) {
      if (a['status'] == 'OPEN' && b['status'] != 'OPEN') return -1;
      if (a['status'] != 'OPEN' && b['status'] == 'OPEN') return 1;
      return b['id'].compareTo(a['id']);
    });

    if (keepSelectedId != null) {
      final idx = newList.indexWhere((e) => e['id'] == keepSelectedId);
      _selectedIndex = idx >= 0 ? idx : null;
    }

    setState(() {
      _stops = newList;
      _busy = false;
    });
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
    setState(() => _busy = true); // show spinner
    final now = DateTime.now();

    final res = await _api.createStop(
      stationId: _stationNameToId[_selectedStation!]!,
      startTime: now.toIso8601String().split('.').first,
      operatorId: 'TOTEM',
      stopType: 'STOP',
      reason: _reasonCtrl.text,
      status: 'OPEN',
      linkedProductionId: widget.linkedProductionId,
    );

    if (res != null && res['status'] == 'ok') {
      widget.onStopStarted?.call({
        'id': res['stop_id'],
        'station': _selectedStation,
        'reason': _reasonCtrl.text,
        'start': now,
      });

      await _fetchStops(keepSelectedId: res['stop_id']);
    }

    setState(() => _busy = false); // hide spinner

    // Automatically close the dialog after starting
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _stopStop() async {
    if (_selectedIndex == null) return;
    final id = _stops[_selectedIndex!]['id'];

    await _api.updateStopStatus(
      stopId: id,
      newStatus: 'CLOSED',
      changedAt: DateTime.now().toIso8601String().split('.').first,
      operatorId: 'NO OPERATOR',
    );
    await _fetchStops();
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
                Positioned.fill(
                  child: (_selectedIndex == null ||
                          _selectedIndex! >= activeStops.length)
                      ? _buildCreateForm()
                      : _buildDetail(activeStops[_selectedIndex!]),
                ),
                if (_busy) _buildLoadingOverlay(),

                // ─── Close Button ──────────────────────────
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(), // closes dialog
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  Widget _buildDetail(Map<String, dynamic> stop) {
    final DateTime start = stop['start_time'] ?? DateTime.now();
    final Duration duration = DateTime.now().difference(start);

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
