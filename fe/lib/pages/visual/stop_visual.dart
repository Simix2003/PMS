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
        backgroundColor: Colors.orangeAccent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 10,
      ),
      icon: const Icon(Icons.timer, color: Colors.white),
      label: const Text(
        'Nuovo Fermo',
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
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
  final Map<String, int> _stationNameToId = const {
    'AIN01': 29,
    'AIN02': 30,
    'STR01': 4,
    'STR02': 5,
    'STR03': 6,
    'STR04': 7,
    'STR05': 8,
  };

  String? _selectedStation;
  bool _running = false;
  Timer? _timer;
  DateTime? _start;
  Duration _elapsed = Duration.zero;
  int? _stopId;

  @override
  void dispose() {
    _timer?.cancel();
    _reasonCtrl.dispose();
    super.dispose();
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
    if (res != null && res['stop'] != null) {
      _stopId = res['stop']['id'];
      _start = now;
      _running = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _elapsed = DateTime.now().difference(_start!);
        });
      });
      widget.onStopStarted?.call({
        'id': _stopId,
        'station': _selectedStation,
        'reason': _reasonCtrl.text,
        'start': _start,
      });
      setState(() {});
    }
  }

  Future<void> _stopStop() async {
    _timer?.cancel();
    if (_stopId != null) {
      await _api.updateStopStatus(
        stopId: _stopId!,
        newStatus: 'CLOSED',
        changedAt: DateTime.now().toIso8601String().split('.').first,
        operatorId: 'NO OPERATOR',
      );
    }
    widget.onStopsUpdated?.call();
    if (mounted) Navigator.pop(context);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuovo Fermo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Stazione'),
            value: _selectedStation,
            items: _stationNameToId.keys
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: _running ? null : (v) => setState(() => _selectedStation = v),
          ),
          TextField(
            controller: _reasonCtrl,
            decoration: const InputDecoration(labelText: 'Motivo'),
            enabled: !_running,
          ),
          if (_running) Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _formatDuration(_elapsed),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Chiudi'),
        ),
        ElevatedButton(
          onPressed: _running ? _stopStop : _startStop,
          child: Text(_running ? 'Ferma Timer' : 'Avvia Timer'),
        ),
      ],
    );
  }
}
