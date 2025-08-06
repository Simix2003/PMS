import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/services/api_service.dart';

class BufferPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: BufferPageContent(
        plcIp: plcIp,
        db: db,
        byte: byte,
        length: length,
      ),
    );
  }
}

class BufferPageContent extends StatefulWidget {
  final String plcIp;
  final int db;
  final int byte;
  final int length;
  final bool visuals;

  const BufferPageContent({
    required this.plcIp,
    required this.db,
    required this.byte,
    required this.length,
    this.visuals = false,
    super.key,
  });

  @override
  State<BufferPageContent> createState() => _BufferPageState();
}

class _BufferPageState extends State<BufferPageContent>
    with TickerProviderStateMixin {
  bool isLoading = true;
  List<Map<String, dynamic>> bufferDefects = [];
  final Map<String, String> etaByObjectId = {};
  final Set<String> loadingETAs = {};
  final ScrollController _scrollController = ScrollController();
  late AnimationController _refreshController;
  late Animation<double> _refreshAnimation;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _refreshAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _refreshController, curve: Curves.easeInOut),
    );
    _loadBufferData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  String get totalEtaSummary {
    final etaValues = etaByObjectId.values
        .map((e) => int.tryParse(e.replaceAll('min', '').trim()))
        .whereType<int>()
        .toList();

    if (etaValues.isEmpty) return "Calculating...";

    final totalMin = etaValues.fold(0, (sum, e) => sum + e);
    final hours = totalMin ~/ 60;
    final minutes = totalMin % 60;

    if (hours > 0) {
      return "${hours}h ${minutes}m remaining";
    } else {
      return "${minutes}m remaining";
    }
  }

  Future<void> _loadBufferData() async {
    _refreshController.forward();
    HapticFeedback.lightImpact();

    try {
      final result = await ApiService.fetchBufferDefectSummary(
        plcIp: widget.plcIp,
        db: widget.db,
        byte: widget.byte,
        length: widget.length,
      );

      final bufferIds = List<String>.from(result['bufferIds'] ?? []);
      final rawDefects =
          List<Map<String, dynamic>>.from(result['bufferDefects'] ?? []);

      // Build fixed list of 21 items (plane + 20 buffer slots)
      final fullDefects = List.generate(21, (i) {
        final id = i < bufferIds.length ? bufferIds[i].trim() : '';
        if (id.isEmpty) {
          return {
            'object_id': '',
            'production_id': 0,
            'rework_count': 0,
            'defects': [],
          };
        }

        final existing = rawDefects.firstWhere(
          (d) => d['object_id'] == id,
          orElse: () => {
            'object_id': id,
            'production_id': 0,
            'rework_count': 0,
            'defects': [],
          },
        );
        return existing;
      });

      // Order: plane at bottom, buffer reversed
      final displayList = [
        fullDefects[0], // plane
        ...fullDefects.sublist(1).reversed, // buffer 21–2
      ];

      setState(() {
        bufferDefects = displayList;
        isLoading = false;
      });

      // Scroll to bottom after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
          );
        }
      });

      for (final item in displayList) {
        final objectId = item['object_id']?.toString();
        if (objectId != null &&
            objectId.isNotEmpty &&
            !etaByObjectId.containsKey(objectId)) {
          _fetchETA(objectId);
        }
      }
    } catch (e) {
      print("❌ Error loading buffer data: $e");
      setState(() => isLoading = false);
    } finally {
      _refreshController.reset();
    }
  }

  Future<void> _fetchETA(String objectId) async {
    loadingETAs.add(objectId);
    final result = await ApiService.predictReworkETAByObject(objectId);

    if (!mounted) return;

    final etaMin = result['etaInfo']?['eta_min'];
    final noDefects = result['noDefectsFound'] ?? false;

    final etaString = etaMin != null
        ? "${etaMin.round()} min"
        : (noDefects ? "Complete" : "N/A");

    setState(() {
      etaByObjectId[objectId] = etaString;
    });
  }

  Color _etaColor(String eta) {
    if (eta == "Complete") return const Color(0xFF34C759); // iOS Green
    if (eta == "N/A") return const Color(0xFF8E8E93); // iOS Gray

    final min = int.tryParse(eta.replaceAll('min', '').trim());
    if (min == null) return const Color(0xFF8E8E93);
    if (min < 5) return const Color(0xFF34C759); // Green
    if (min < 15) return const Color(0xFFFF9F0A); // Orange
    return const Color(0xFFFF3B30); // Red
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // iOS Background
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: !widget.visuals,
            leading:
                widget.visuals ? null : const BackButton(color: Colors.black),
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: const Color(0xFFF2F2F7),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            actions: [
              AnimatedBuilder(
                animation: _refreshAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _refreshAnimation.value * 2 * 3.14159,
                    child: IconButton(
                      onPressed: isLoading ? null : _loadBufferData,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF007AFF),
                        size: 22,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Buffer RMI01',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalEtaSummary,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: isLoading
                ? Container(
                    height: MediaQuery.of(context).size.height * 0.6,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          child: const CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Loading buffer data...',
                          style: TextStyle(
                            fontSize: 17,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: bufferDefects.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = bufferDefects[index];
                      final objectId = item['object_id'] ?? '';
                      final eta = objectId.isNotEmpty
                          ? (etaByObjectId[objectId] ?? 'Loading...')
                          : '-';

                      // Calculate slot number: Position 21 (top) to 1 (bottom)
                      final slotNumber = bufferDefects.length - index;

                      final isEmpty = (objectId == null || objectId.isEmpty);
                      final isNG = (item['defects'] as List).any((d) {
                        final type = d['defect_type']?.toString().trim();
                        return type != null &&
                            type.isNotEmpty &&
                            type != 'OK' &&
                            type != 'Sconosciuto';
                      });
                      final rawDefects = item['defects'] as List;

                      final validTypes = rawDefects
                          .map((d) => d['defect_type']?.toString().trim())
                          .where((t) => t != null && t.isNotEmpty)
                          .cast<String>()
                          .toList();

                      final defectTypes = isEmpty
                          ? <String>[] // no defects shown for empty slots
                          : (validTypes.isNotEmpty ? validTypes : ['Unknown']);

                      return AnimatedContainer(
                        duration: Duration(milliseconds: 300 + (index * 50)),
                        curve: Curves.easeOut,
                        child: _AppleDefectCard(
                          number: slotNumber,
                          name: objectId.isNotEmpty ? objectId : 'Empty Slot',
                          eta: eta,
                          etaColor: _etaColor(eta),
                          rework: item['rework_count'] ?? 0,
                          defectTypes: defectTypes,
                          isEmpty: isEmpty,
                          isNG: isNG,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AppleDefectCard extends StatelessWidget {
  final int number;
  final String name;
  final String eta;
  final Color etaColor;
  final int rework;
  final List<String> defectTypes;
  final bool isEmpty;
  final bool isNG;

  const _AppleDefectCard({
    required this.number,
    required this.name,
    required this.eta,
    required this.etaColor,
    required this.rework,
    required this.defectTypes,
    required this.isEmpty,
    required this.isNG,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isEmpty
        ? Colors.white.withOpacity(0.6)
        : isNG
            ? const Color(0xFFFF3B30).withOpacity(0.05)
            : Colors.white;

    final borderColor = isEmpty
        ? const Color(0xFFE5E5EA)
        : isNG
            ? const Color(0xFFFF3B30).withOpacity(0.2)
            : const Color(0xFFE5E5EA);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => HapticFeedback.lightImpact(),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isEmpty
                            ? const Color(0xFF8E8E93).withOpacity(0.1)
                            : isNG
                                ? const Color(0xFFFF3B30).withOpacity(0.1)
                                : const Color(0xFF34C759).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$number',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isEmpty
                                ? const Color(0xFF8E8E93)
                                : isNG
                                    ? const Color(0xFFFF3B30)
                                    : const Color(0xFF34C759),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: etaColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: etaColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            eta,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: etaColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Name
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isEmpty ? const Color(0xFF8E8E93) : Colors.black,
                    letterSpacing: -0.2,
                  ),
                ),

                if (!isEmpty) ...[
                  const SizedBox(height: 12),

                  // Rework and Defects Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rework Count
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.refresh,
                              size: 16,
                              color: Color(0xFF8E8E93),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$rework',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (defectTypes.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: defectTypes.map((type) {
                              final isOK = type == 'OK';
                              final isUnknown =
                                  type == 'Unknown' || type == 'Sconosciuto';

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isOK
                                      ? const Color(0xFF34C759).withOpacity(0.1)
                                      : isUnknown
                                          ? const Color(0xFF8E8E93)
                                              .withOpacity(0.1)
                                          : const Color(0xFFFF9F0A)
                                              .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isOK
                                        ? const Color(0xFF34C759)
                                            .withOpacity(0.3)
                                        : isUnknown
                                            ? const Color(0xFF8E8E93)
                                                .withOpacity(0.3)
                                            : const Color(0xFFFF9F0A)
                                                .withOpacity(0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isOK
                                        ? const Color(0xFF34C759)
                                        : isUnknown
                                            ? const Color(0xFF8E8E93)
                                            : const Color(0xFFFF9F0A),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
