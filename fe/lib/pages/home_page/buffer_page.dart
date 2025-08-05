import 'package:flutter/material.dart';
import '../../shared/services/api_service.dart'; // update path accordingly

class BufferPage extends StatefulWidget {
  final String plcIp;
  final int db;
  final int byte;
  final int length;

  const BufferPage({
    required this.plcIp,
    required this.db,
    required this.byte,
    required this.length,
    super.key,
  });

  @override
  State<BufferPage> createState() => _BufferPageState();
}

class _BufferPageState extends State<BufferPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> bufferDefects = [];
  final Map<String, String> etaByObjectId = {};
  final Set<String> loadingETAs = {};

  @override
  void initState() {
    super.initState();
    _loadBufferData();
  }

  String get totalEtaSummary {
    final etaValues = etaByObjectId.values
        .map((e) => int.tryParse(e.replaceAll('min', '').trim()))
        .whereType<int>()
        .toList();

    if (etaValues.isEmpty) return "ETA: ⏳...";

    final totalMin = etaValues.fold(0, (sum, e) => sum + e);
    return "ETA: $totalMin min";
  }

  Future<void> _loadBufferData() async {
    try {
      final result = await ApiService.fetchBufferDefectSummary(
        plcIp: widget.plcIp,
        db: widget.db,
        byte: widget.byte,
        length: widget.length,
      );

      final defects = result['bufferDefects'] ?? [];

      setState(() {
        bufferDefects = defects;
        isLoading = false;
      });

      // Fetch ETA for each object
      for (final item in defects) {
        final objectId = item['object_id']?.toString();
        if (objectId != null && !etaByObjectId.containsKey(objectId)) {
          _fetchETA(objectId);
        }
      }
    } catch (e) {
      print("❌ Error loading buffer data: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchETA(String objectId) async {
    loadingETAs.add(objectId);
    final result = await ApiService.predictReworkETAByObject(objectId);

    if (!mounted) return;

    final etaMin = result['etaInfo']?['eta_min'];
    final noDefects = result['noDefectsFound'] ?? false;

    final etaString =
        etaMin != null ? "${etaMin.round()} min" : (noDefects ? "✅" : "N/A");

    setState(() {
      etaByObjectId[objectId] = etaString;
    });
  }

  Color _etaColor(String eta) {
    final min = int.tryParse(eta.replaceAll('min', '').trim());
    if (min == null) return Colors.grey.shade500;
    if (min < 5) return Colors.green;
    if (min < 15) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              "Buffer RMI01",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Text(
              totalEtaSummary,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : bufferDefects.isEmpty
                ? const Center(child: Text("✅ Nessun modulo in buffer difetti"))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: bufferDefects.length,
                    itemBuilder: (context, index) {
                      final item = bufferDefects[index];
                      final objectId = item['object_id'] ?? '';
                      final eta = etaByObjectId[objectId] ?? '⏳...';

                      final bgColor = index.isEven
                          ? Colors.grey.shade100
                          : Colors.grey.shade200;

                      return Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(6),
                        child: _DefectCard(
                          number: index + 1,
                          name: objectId,
                          eta: eta,
                          etaColor: _etaColor(eta),
                          rework: item['rework_count'],
                          defectTypes: List<String>.from(
                            (item['defects'] as List)
                                .map((d) => d['defect_type'] ?? 'Unknown'),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _DefectCard extends StatelessWidget {
  final int number;
  final String name;
  final String eta;
  final Color etaColor;
  final int rework;
  final List<String> defectTypes;

  const _DefectCard({
    required this.number,
    required this.name,
    required this.eta,
    required this.etaColor,
    required this.rework,
    required this.defectTypes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "#$number",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: etaColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "ETA: $eta",
                  style: TextStyle(
                    fontSize: 12,
                    color: etaColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.autorenew, size: 16),
              const SizedBox(width: 6),
              Text("x$rework"),
              const SizedBox(width: 10),
              if (defectTypes.isNotEmpty)
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: defectTypes
                        .map(
                          (type) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              type,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
