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
    "STR01": 4,
    "STR02": 5,
    "STR03": 6,
    "STR04": 7,
    "STR05": 8,
  };

  final stopTypes = ["ESCALATION"];
  static const List<String> statusCreation = [
    "OPEN",
    "SHIFT_MANAGER",
    "HEAD_OF_PRODUCTION",
  ];
  static const List<String> statusFull = [...statusCreation, "CLOSED"];

  final String _defaultStation = "STR01";
  final String _defaultType = "ESCALATION";

  String? _newStation;
  String? _newType;
  String? _newStatus;
  final TextEditingController _reasonCtrl = TextEditingController();

  bool _editingReason = false;
  final TextEditingController _editReasonCtrl = TextEditingController();

  DateTime _dt(dynamic value, {DateTime? fallback}) {
    if (value == null) return fallback ?? DateTime.now();
    return value is DateTime ? value : DateTime.parse(value.toString());
  }

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

    final List<Map<String, dynamic>> newEsc = []; // build a fresh list
    for (final entry in stationNameToId.entries) {
      final res = await _api.getStopsForStation(entry.value,
          shiftsBack: widget.last_n_shifts);
      if (res != null && res['status'] == 'ok' && res['stops'] != null) {
        for (final stop in res['stops']) {
          newEsc.add(normalizeStop(stop, station: entry.key));
        }
      }
    }
    newEsc.sort((a, b) => b['id'].compareTo(a['id']));

    // restore selection (use newEsc, not the global list)
    if (keepSelectedId != null) {
      final act = newEsc.where((e) => e['status'] != 'CLOSED').toList();
      final idx = act.indexWhere((e) => e['id'] == keepSelectedId);
      _selectedIndex = idx >= 0 ? idx : null;
    }

    escalations.value = newEsc; // 🔥 this notifies every listener
    setState(() => _busy = false);
    widget.onEscalationsUpdated?.call(); // still works for legacy callers
  }

  Future<void> _createNewEscalation() async {
    // FAKING THEM BECAUSE OF RICHARD
    //ToDo: FIX THIS
    _newStation = _defaultStation;
    _newType = _defaultType;

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

  Map<String, dynamic> normalizeStop(Map<String, dynamic> stop,
      {String? station}) {
    return {
      'id': stop['id'],
      'title': stop['reason'] ?? stop['title'],
      'status': stop['status'],
      'station': station ?? stop['station'],
      'start_time': stop['start_time'] is DateTime
          ? stop['start_time']
          : DateTime.tryParse(stop['start_time'].toString()),
      'end_time': stop['end_time'] == null
          ? null
          : (stop['end_time'] is DateTime
              ? stop['end_time']
              : DateTime.tryParse(stop['end_time'].toString())),
    };
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

    if (res != null && res['stop'] != null) {
      final updated = normalizeStop(res['stop']);
      // replace old item with updated one (prevents rebuild with raw String)
      final list = List<Map<String, dynamic>>.from(escalations.value);
      final idx = list.indexWhere((e) => e['id'] == updated['id']);
      if (idx >= 0) list[idx] = updated;
      escalations.value = list;
    }
    await _fetchExistingStops(keepSelectedId: id);
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
        escalations.value.where((e) => e['status'] != 'CLOSED').toList();
    final closedEscalations =
        escalations.value.where((e) => e['status'] == 'CLOSED').toList();

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
                    _buildModernSidebar(activeEscalations),
                    Expanded(
                      child: _showClosed
                          ? _buildModernClosedView(closedEscalations)
                          : (_selectedIndex == null ||
                                  _selectedIndex! >= activeEscalations.length)
                              ? _buildModernCreateForm()
                              : _buildModernDetail(
                                  activeEscalations[_selectedIndex!]),
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

  Widget _buildModernSidebar(List activeEscalations) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFE5E5E7), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E5E7), width: 1),
              ),
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
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Escalations',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
          ),

          // Create New Button
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
                      'Nuova Escalation',
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

          // Active Escalations List
          Expanded(
            child: activeEscalations.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Color(0xFFAEAEB2),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Nessuna escalation attiva',
                          style: TextStyle(
                            color: Color(0xFFAEAEB2),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: activeEscalations.length,
                    itemBuilder: (_, i) {
                      final e = activeEscalations[i];
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
                                  ? Border.all(
                                      color: const Color(0xFF007AFF),
                                      width: 1,
                                    )
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
                                  child: Icon(
                                    _statusIcon(e['status']),
                                    color: _statusColor(e['status']),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
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
                                      const SizedBox(height: 2),
                                      Text(
                                        e['status'],
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF8E8E93),
                                        ),
                                      ),
                                    ],
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

          // Closed Items Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFE5E5E7), width: 1),
              ),
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
                    Icon(
                      Icons.history,
                      color:
                          _showClosed ? Colors.white : const Color(0xFF8E8E93),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Fermi Chiusi',
                      style: TextStyle(
                        color: _showClosed
                            ? Colors.white
                            : const Color(0xFF8E8E93),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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

  Widget _buildModernCreateForm() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nuova Escalation',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crea una nuova escalation del sistema',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 40),

          // Status Selector
          const Text(
            'Stato',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E5E7)),
            ),
            child: DropdownButtonFormField<String>(
              value: _newStatus,
              hint: const Text('Seleziona stato'),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
              items: statusCreation
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _newStatus = v),
            ),
          ),

          const SizedBox(height: 24),

          // Reason Field
          const Text(
            'Motivo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E5E7)),
            ),
            child: TextField(
              controller: _reasonCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Descrivi il motivo dell\'escalation...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),

          const Spacer(),

          // Save Button
          Container(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _createNewEscalation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Salva Escalation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernClosedView(List closed) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _showClosed = false),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios,
                    size: 16,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Fermi Chiusi',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1C1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: closed.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: Color(0xFFAEAEB2),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Nessun fermo chiuso',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFFAEAEB2),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: closed.length,
                    itemBuilder: (_, i) {
                      final e = closed[i];
                      final start = _dt(e['start_time']);
                      final end = _dt(e['end_time'], fallback: start);
                      final duration = end.difference(start);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                              color: const Color(0xFF34C759).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: Color(0xFF34C759),
                              size: 24,
                            ),
                          ),
                          title: Text(
                            e['title'],
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
                                onTap: () => _showClosedDetail(e),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF007AFF)
                                        .withOpacity(0.1),
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
                                onTap: () => _handleDelete(e),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF3B30)
                                        .withOpacity(0.1),
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
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDetail(Map<String, dynamic> esc) {
    final start = _dt(esc['start_time']);
    final end = _dt(esc['end_time'], fallback: DateTime.now());
    final duration = end.difference(start);

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _editingReason
                    ? Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF007AFF)),
                        ),
                        child: TextField(
                          controller: _editReasonCtrl,
                          maxLines: 2,
                          autofocus: true,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1C1C1E),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                            hintText: 'Titolo escalation...',
                          ),
                        ),
                      )
                    : Text(
                        esc['title'],
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  if (_editingReason) {
                    _updateReason(esc['id']);
                  } else {
                    setState(() {
                      _editingReason = true;
                      _editReasonCtrl.text = esc['title'];
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
                    size: 20,
                    color: const Color(0xFF007AFF),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Status Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E5E7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _statusColor(esc['status']).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        _statusIcon(esc['status']),
                        color: _statusColor(esc['status']),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _statusColor(esc['status']),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        esc['status'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Status Update Dropdown
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: esc['status'],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                      hintText: 'Aggiorna stato...',
                    ),
                    items: statusFull
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) => _updateStatus(esc['id'], val!),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Info Cards
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  Icons.play_circle_outline,
                  'Inizio',
                  DateFormat('HH:mm:ss').format(_dt(esc['start_time'])),
                  const Color(0xFF007AFF),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  Icons.timer_outlined,
                  'Durata',
                  _formatDuration(duration),
                  const Color(0xFF34C759),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF8E8E93),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
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

  void _handleDelete(Map<String, dynamic> item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text(
          "Conferma Eliminazione",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Sei sicuro di voler eliminare definitivamente questa escalation?",
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "'${item['title']}'",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1C1C1E),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Annulla",
              style: TextStyle(
                color: Color(0xFF007AFF),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              setState(() => _busy = true);

              final res = await ApiService().deleteStop(item['id']);
              if (res != null && res['status'] == 'ok') {
                await _fetchExistingStops();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("Escalation eliminata con successo"),
                    backgroundColor: const Color(0xFF34C759),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("Errore durante l'eliminazione"),
                    backgroundColor: const Color(0xFFFF3B30),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }

              setState(() => _busy = false);
            },
            child: const Text(
              "Elimina",
              style: TextStyle(
                color: Color(0xFFFF3B30),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClosedDetail(Map<String, dynamic> esc) async {
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

    // Call API
    final res = await ApiService().getStopDetails(esc['id']);

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

    final List history = res['stop']['levels'];

    showDialog(
      context: context,
      builder: (_) {
        final start = _dt(esc['start_time']);
        final end = _dt(esc['end_time'], fallback: start);
        final duration = end.difference(start);

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
                          color: const Color(0xFF34C759).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Color(0xFF34C759),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          "Dettagli Fermo Chiuso",
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
                              esc['title'],
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

                      // Info Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailInfoCard(
                              "Stazione",
                              esc['station'],
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

                      // Status History
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

  Widget _buildDetailInfoCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
}
