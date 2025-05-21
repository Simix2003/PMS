// ignore_for_file: file_names, library_private_types_in_public_api

import 'package:flutter/material.dart';
import '../../shared/widgets/object_result_card.dart';
import 'mbjDetails_page.dart';
import 'productionDetails_page.dart';

class ObjectdetailsPage extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  const ObjectdetailsPage({super.key, required this.events});

  @override
  _ObjectdetailsPageState createState() => _ObjectdetailsPageState();
}

class _ObjectdetailsPageState extends State<ObjectdetailsPage> {
  final orderDirections = ['Crescente', 'Decrescente']; // A-Z / Z-A
  String? selectedOrderDirection = 'Decrescente';

  Widget _buildStyledDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String description = '',
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (description.isNotEmpty) ...[
          Text(
            "$description:",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButton<String>(
            value: value,
            hint: Text(hint),
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF007AFF)),
            underline: Container(),
            borderRadius: BorderRadius.circular(16),
            items: items
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sort events by end_time
    final ascending = selectedOrderDirection == 'Crescente';
    widget.events.sort((a, b) {
      final da = DateTime.parse(a['end_time']);
      final db = DateTime.parse(b['end_time']);
      return ascending ? da.compareTo(db) : db.compareTo(da);
    });

    // Group events by station
    final Map<String, List<Map<String, dynamic>>> byStation = {};
    for (var e in widget.events) {
      final station = e['station_name'] ?? 'Unknown';
      byStation.putIfAbsent(station, () => []).add(e);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Modulo ${widget.events[0]['id_modulo']} – ${widget.events.length} eventi'),
        actions: [
          _buildStyledDropdown(
            hint: '↑ ↓',
            value: selectedOrderDirection,
            items: orderDirections,
            onChanged: (val) {
              setState(() {
                selectedOrderDirection = val;
              });
            },
          ),
        ],
      ),
      body: ListView(
        children: byStation.entries.map((entry) {
          return _buildStationSection(entry.key, entry.value);
        }).toList(),
      ),
    );
  }

  Widget _buildStationSection(
      String station, List<Map<String, dynamic>> events) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$station (${events.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...events.map((e) => _buildEventCard(e)).toList(),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ObjectResultCard(
        data: event,
        isSelectable: false,
        productionIdsCount: 1,
        onTap: () {
          if (event['station_name'] == 'MBJ') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MBJDetailPage(data: event),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductionDetailPage(data: event),
              ),
            );
          }
        },
      ),
    );
  }
}
