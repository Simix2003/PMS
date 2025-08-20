// stop_visual.dart
// ignore_for_file: use_build_context_synchronously, non_constant_identifier_names, deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../shared/services/api_service.dart';
import '../../shared/widgets/password.dart';

class StopButton extends StatelessWidget {
  final int lastNShifts;
  final int? linkedProductionId;
  final VoidCallback? onStopsUpdated;
  final ValueChanged<Map<String, dynamic>>? onStopStarted;
  final String zone;

  const StopButton({
    super.key,
    required this.lastNShifts,
    this.linkedProductionId,
    this.onStopsUpdated,
    this.onStopStarted,
    required this.zone,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange.withOpacity(0.85),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            zone: zone,
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
  final String zone;

  const _StopDialog({
    required this.lastNShifts,
    this.linkedProductionId,
    this.onStopsUpdated,
    this.onStopStarted,
    required this.zone,
  });

  @override
  State<_StopDialog> createState() => _StopDialogState();
}

class _StopDialogState extends State<_StopDialog> {
  final ApiService _api = ApiService();

  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _editReasonCtrl = TextEditingController();
  late final Map<String, int> _stationNameToId;

  bool _busy = false;
  int? _selectedIndex;
  String? _selectedStation;
  bool _editingReason = false;

  List<Map<String, dynamic>> _stopsLive = [];
  List<Map<String, dynamic>> _stopsHistory = [];

  late TabController _tabController;

  bool alreadyClosed = false;
  int minutes = 0;
  final TextEditingController _minutesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.zone == 'AIN') {
      _stationNameToId = const {
        'AIN01': 29,
        'AIN02': 30,
      };
    } else if (widget.zone == 'STR') {
      _stationNameToId = const {
        'STR01': 4,
        'STR02': 5,
        'STR03': 6,
        'STR04': 7,
        'STR05': 8,
      };
    } else if (widget.zone == 'LMN') {
      _stationNameToId = const {
        'LMN01': 93,
        'LMN02': 47,
      };
    } else {
      _stationNameToId = const {}; // fallback, or throw an error
    }

    _fetchStops();

    // Rebuild every minute to refresh durations
    Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });

    Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;

      final controller = DefaultTabController.of(context);
      if (controller.index == 0) {
        await _fetchStops(
          keepSelectedId:
              _selectedIndex != null ? _stopsLive[_selectedIndex!]['id'] : null,
        );
      }
    });
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _editReasonCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStops({int? keepSelectedId}) async {
    setState(() => _busy = true);
    final List<Map<String, dynamic>> newList = [];

    for (final entry in _stationNameToId.entries) {
      final res = await _api.getMachineStopsForStation(
        entry.value,
        shiftsBack: widget.lastNShifts,
        includeOpen: true, // Ensure OPEN stops are included
      );
      if (res != null && res['status'] == 'ok' && res['stops'] != null) {
        for (final s in res['stops']) {
          if (s['type'] == 'STOP') {
            newList.add(_normalizeStop(s, station: entry.key));
          }
        }
      }
    }

    newList.sort((a, b) {
      final aOpen = a['end_time'] == null;
      final bOpen = b['end_time'] == null;
      if (aOpen && !bOpen) return -1;
      if (!aOpen && bOpen) return 1;
      return b['id'].compareTo(a['id']);
    });

    if (keepSelectedId != null) {
      final idx = newList.indexWhere((e) => e['id'] == keepSelectedId);
      _selectedIndex = idx >= 0 ? idx : null;
    }

    setState(() {
      _stopsLive = newList;
      _busy = false;
    });
  }

  Future<void> _loadStopHistory() async {
    setState(() => _busy = true);
    final List<Map<String, dynamic>> newList = [];

    for (final entry in _stationNameToId.entries) {
      final res = await _api.getMachineStopsForStation(
        entry.value,
        shiftsBack: 21, // ≈ 7 days (3 shifts per day)
        includeOpen: true,
      );
      if (res != null && res['status'] == 'ok' && res['stops'] != null) {
        for (final s in res['stops']) {
          if (s['type'] == 'STOP') {
            newList.add(_normalizeStop(s, station: entry.key));
          }
        }
      }
    }

    newList.sort((a, b) => b['start_time'].compareTo(a['start_time']));

    setState(() {
      _stopsHistory = newList;
      _busy = false;
    });
  }

  Map<String, dynamic> _normalizeStop(Map<String, dynamic> s,
      {String? station}) {
    final start = s['start_time'] is DateTime
        ? s['start_time'] as DateTime
        : DateTime.tryParse(s['start_time'].toString());
    final end = s['end_time'] == null
        ? null
        : (s['end_time'] is DateTime
            ? s['end_time'] as DateTime
            : DateTime.tryParse(s['end_time'].toString()));

    final statusRaw = (s['status'] ?? '').toString().toUpperCase().trim();
    // If end exists, treat as CLOSED regardless of server status string.
    final status =
        end != null ? 'CLOSED' : (statusRaw.isEmpty ? 'OPEN' : statusRaw);

    return {
      'id': s['id'],
      'title': s['reason'] ?? s['title'] ?? 'Fermo',
      'status': status,
      'station': station ?? s['station'],
      'start_time': start,
      'end_time': end,
    };
  }

  Future<bool> _requirePassword() async {
    return await showPasswordGate(
      context,
      title: 'Operazione protetta',
      subtitle: 'Inserisci la password per procedere',
      verify: (pwd) async {
        // TODO: replace with your API call, e.g. await Api.verifyPassword(pwd)
        return pwd == 'PMS2025'; // placeholder
      },
    );
  }

  Future<void> _startStop() async {
    if (_busy) return;

    // Validations
    final station = _selectedStation;
    final reason = _reasonCtrl.text.trim();
    if (station == null || reason.isEmpty) return;
    if (alreadyClosed && minutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci i minuti di fermo (> 0)')),
      );
      return;
    }

    // 🔒 Ask every time
    final ok = await _requirePassword();
    if (!ok) return;

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final start =
          alreadyClosed ? now.subtract(Duration(minutes: minutes)) : now;
      final startIso = start.toIso8601String().split('.').first;
      final endIso =
          alreadyClosed ? now.toIso8601String().split('.').first : null;

      final createRes = await _api.createStop(
        stationId: _stationNameToId[station]!,
        startTime: startIso,
        endTime: endIso, // ⬅️ pass when alreadyClosed
        operatorId: 'TOTEM',
        stopType: 'STOP',
        reason: reason,
        status: alreadyClosed ? 'CLOSED' : 'OPEN', // ⬅️ CLOSED if backfilled
        linkedProductionId: widget.linkedProductionId,
      );

      if (createRes == null || createRes['status'] != 'ok') {
        throw 'createStop failed';
      }

      final createdId = createRes['stop_id'];

      // 2) If alreadyClosed, close it *now* (so duration = minutes)
      if (alreadyClosed) {
        final endIso = now.toIso8601String().split('.').first;
        final closeRes = await _api.updateStopStatus(
          stopId: createdId,
          newStatus: 'CLOSED',
          changedAt: endIso, // backend should set end_time = changedAt
          operatorId: 'TOTEM',
        );
        if (closeRes == null || closeRes['status'] != 'ok') {
          // If backend returns a different shape, show hint
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Attenzione: chiusura non confermata')),
          );
        }
        // tiny delay to let DB commit before reloading
        await Future.delayed(const Duration(milliseconds: 120));
      }

      // Callback for UI (use the intended start time)
      widget.onStopStarted?.call({
        'id': createdId,
        'station': station,
        'reason': reason,
        'start': start,
      });

      // 3) Force a clean refresh (avoid stale OPEN row)
      _selectedIndex = null; // don’t stick to possibly stale selection
      await _fetchStops(keepSelectedId: createdId);

      if (mounted) Navigator.of(context).pop(); // close dialog
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore inserimento fermo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopStop() async {
    if (_busy) return;
    if (_selectedIndex == null) return;

    // 🔒 Ask every time
    final ok = await _requirePassword();
    if (!ok) return;

    setState(() => _busy = true);
    try {
      final id = _stopsLive[_selectedIndex!]['id'];
      await _api.updateStopStatus(
        stopId: id,
        newStatus: 'CLOSED',
        changedAt: DateTime.now().toIso8601String().split('.').first,
        operatorId: 'NO OPERATOR',
      );
      await _fetchStops();
      widget.onStopsUpdated?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore chiusura fermo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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

  Widget _buildDetailInfoCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(Map<String, dynamic> stop) async {
    // Show loading state
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
        ),
      ),
    );

    // Call API to fetch detailed stop info (e.g., history)
    final res = await ApiService().getStopDetails(stop['id']);

    // Close loading dialog
    Navigator.of(context).pop();

    if (res == null || res['status'] != 'ok') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Errore durante il caricamento dei dettagli'),
          backgroundColor: const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final List history = res['stop']['levels'] ?? [];

    final start = stop['start_time'] ?? DateTime.now();
    final end = stop['end_time'] ?? DateTime.now();
    final duration = end.difference(start);

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 500,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E5E7), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _statusColor(stop['status']).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          _statusIcon(stop['status']),
                          color: _statusColor(stop['status']),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          "Dettagli Fermo",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Motivo",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stop['title'] ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1C1C1E),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Info cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailInfoCard(
                              "Stazione",
                              stop['station'] ?? '',
                              Icons.precision_manufacturing,
                              const Color(0xFF007AFF),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailInfoCard(
                              "Durata",
                              _formatDuration(duration),
                              Icons.timer,
                              const Color(0xFF34C759),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailInfoCard(
                              "Inizio",
                              DateFormat('dd/MM HH:mm:ss', 'it_IT')
                                  .format(start),
                              Icons.play_circle,
                              const Color(0xFFFF9500),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailInfoCard(
                              "Fine",
                              DateFormat('dd/MM HH:mm:ss', 'it_IT').format(end),
                              Icons.stop_circle,
                              const Color(0xFFFF3B30),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // History section
                      const Text(
                        "Storico Stati",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: _buildModernStatusHistory(history),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernStatusHistory(List history) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        shrinkWrap: true,
        itemCount: history.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final entry = history[i];
          final status = entry['status'];
          final ts = DateTime.parse(entry['changed_at']);

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _statusIcon(status),
                    color: _statusColor(status),
                    size: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                ),
                Text(
                  DateFormat('dd/MM HH:mm:ss', 'it_IT').format(ts),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteStop(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina Fermo'),
        content: const Text('Sei sicuro di voler eliminare questo fermo?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Elimina')),
        ],
      ),
    );

    if (confirmed == true) {
      await _api.deleteStop(id); // or updateStopStatus(..., "DELETED")
      await _loadStopHistory();
    }
  }

  Widget _buildStopHistoryView() {
    final Map<String, Map<String, List<Map<String, dynamic>>>>
        groupedByDayAndShift = {};

    for (var stop in _stopsHistory) {
      final dt = stop['start_time'] ?? DateTime.now();
      final dayStr =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

      final shift = dt.hour < 6
          ? 'S3'
          : dt.hour < 14
              ? 'S1'
              : 'S2';

      groupedByDayAndShift.putIfAbsent(dayStr, () => {});
      groupedByDayAndShift[dayStr]!.putIfAbsent(shift, () => []);
      groupedByDayAndShift[dayStr]![shift]!.add(stop);
    }

    final sortedDays = groupedByDayAndShift.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: sortedDays.map((day) {
        final shifts = groupedByDayAndShift[day]!;
        final sortedShifts =
            ['S1', 'S2', 'S3'].where((s) => shifts.containsKey(s)).toList();

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ExpansionTile(
            title:
                Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
            children: sortedShifts.map((shift) {
              final stops = shifts[shift]!;
              final totalDuration = stops.fold<Duration>(
                Duration.zero,
                (sum, s) {
                  final start = s['start_time'] as DateTime?;
                  final end = s['end_time'] as DateTime? ?? DateTime.now();
                  return sum +
                      (start != null ? end.difference(start) : Duration.zero);
                },
              );

              return ExpansionTile(
                title: Text('Turno $shift'),
                subtitle:
                    Text('Durata totale: ${_formatDuration(totalDuration)}'),
                children: stops.map((s) {
                  final start = s['start_time'] ?? DateTime.now();
                  final end = s['end_time'] ?? DateTime.now();
                  final duration = end.difference(start);

                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E5E7)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _statusColor(s['status']).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          _statusIcon(s['status']),
                          color: _statusColor(s['status']),
                          size: 24,
                        ),
                      ),
                      title: Text(
                        s['title'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "${DateFormat('dd/MM HH:mm', 'it_IT').format(start)} - ${DateFormat('dd/MM HH:mm', 'it_IT').format(end)} • ${_formatDuration(duration)}",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _showDetailDialog(s),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _deleteStop(s['id']),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B30).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Color(0xFFFF3B30),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            child: DefaultTabController(
              length: 2,
              child: Builder(
                builder: (context) {
                  _tabController = DefaultTabController.of(context);

                  _tabController.addListener(() {
                    if (_tabController.index == 1 &&
                        !_tabController.indexIsChanging) {
                      _loadStopHistory(); // Only when switching to "Storico Fermi"
                    }
                  });

                  return Stack(
                    children: [
                      // ─── Tabs Content ───────────────────────────────
                      Positioned.fill(
                        child: Column(
                          children: [
                            const TabBar(
                              indicatorColor: Color(0xFF007AFF),
                              labelColor: Color(0xFF007AFF),
                              unselectedLabelColor: Colors.black54,
                              tabs: [
                                Tab(text: 'Nuovo Fermo'),
                                Tab(text: 'Storico Fermi'),
                              ],
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  (_selectedIndex == null ||
                                          _selectedIndex! >= _stopsLive.length)
                                      ? _buildCreateForm()
                                      : _buildDetail(
                                          _stopsLive[_selectedIndex!]),
                                  _buildStopHistoryView(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_busy) _buildLoadingOverlay(),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
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
                  );
                },
              ),
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
          const SizedBox(height: 24),
          CheckboxListTile(
            value: alreadyClosed,
            onChanged: (v) {
              setState(() {
                alreadyClosed = v ?? false;
                if (!alreadyClosed) {
                  minutes = 0;
                  _minutesCtrl.clear();
                }
              });
            },
            title: const Text('Il fermo è già stato chiuso'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: alreadyClosed
                ? Padding(
                    key: const ValueKey('minutesField'),
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextField(
                      controller: _minutesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minuti di fermo',
                        border: OutlineInputBorder(),
                        helperText: 'Inserisci la durata totale (in minuti)',
                      ),
                      onChanged: (v) => minutes = int.tryParse(v) ?? 0,
                      inputFormatters: const [], // add FilteringTextInputFormatter.digitsOnly if you import services.dart
                    ),
                  )
                : const SizedBox.shrink(),
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
              child: alreadyClosed
                  ? const Text('Inserisci Fermo',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600))
                  : const Text('Avvia Fermo',
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
    final DateTime? end = stop['end_time']; // ← may be null

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

                // ✅ Duration uses end when present
                Text('Durata: ${_formatDuration(duration)}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),

                // ✅ Only show STOP button if still open (end_time == null)
                if (end == null)
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
