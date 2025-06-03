// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ix_monitor/shared/widgets/solarPanelNew.dart';
import '../../shared/services/api_service.dart';
import '../../shared/widgets/shimmer_panel.dart';
import '../../shared/widgets/solarPanel.dart';
//import '../../shared/widgets/solarPanelNew.dart';

class MBJDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const MBJDetailPage({super.key, required this.data});

  @override
  State<MBJDetailPage> createState() => _MBJDetailPageState();
}

class _MBJDetailPageState extends State<MBJDetailPage> {
  bool showRibbons = false;
  bool showHorizontalGaps = false;
  bool showVerticalGaps = false;
  bool showGlassCell = false;
  bool showGlassRibbon = false;
  bool showWarnings = false;
  bool showDetailedView = true;
  late Future<Map<String, dynamic>?> mbjDataFuture;

  @override
  void initState() {
    super.initState();
    final idModulo = widget.data['id_modulo'] ?? widget.data['object_id'];
    mbjDataFuture = ApiService.fetchMBJDetails(idModulo);
  }

  @override
  Widget build(BuildContext context) {
    final idModulo = widget.data['id_modulo'] ?? widget.data['object_id'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Dettagli ELL – $idModulo'),
        actions: [
          IconButton(
            icon: Icon(
                showDetailedView ? Icons.visibility : Icons.visibility_off),
            tooltip: showDetailedView ? 'Nascondi Dettagli' : 'Mostra Dettagli',
            onPressed: () {
              setState(() => showDetailedView = !showDetailedView);
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: mbjDataFuture,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          if (isLoading) {
            // ✅ Use shimmer reveal on a fake placeholder panel
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 16),
                  // Right: shimmer reveal effect while loading
                  Expanded(
                    child: ShimmerPanelReveal(
                      panel: DistancesSolarPanelWidget(
                        cellDefects: [],
                        showDimensions: false,
                        showRibbons: false,
                        showHorizontalGaps: false,
                        showVerticalGaps: false,
                        showGlassCell: false,
                        showGlassRibbon: false,
                        showWarnings: false,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_off_rounded,
                        size: 72, color: Colors.grey[500]),
                    const SizedBox(height: 16),
                    Text(
                      'File XML non trovato 😕',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Il file XML con i dettagli tecnici non è più presente nel sistema.\nTuttavia, i dati dell’evento sono ancora visibili nella cronologia.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          // 🟢 Normal behavior here (real panel)
          final mbjData = snapshot.data!;
          final glassWidth = (mbjData['glass_width'] ?? 2166).toDouble();
          final glassHeight = (mbjData['glass_height'] ?? 1297).toDouble();

          final raw = mbjData['cell_defects'];
          final parsedDefects =
              (raw as List).map((e) => Map<String, dynamic>.from(e)).toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1300),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: showDetailedView
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ⬆️ Top ribbon-style checkbox panel
                          Container(
                            constraints: const BoxConstraints(maxHeight: 150),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _buildCheckboxTile(
                                            'Interconnection Ribbon',
                                            showRibbons,
                                            (v) => setState(
                                                () => showRibbons = v!)),
                                        _buildCheckboxTile(
                                            'Gap Orizzontali',
                                            showHorizontalGaps,
                                            (v) => setState(
                                                () => showHorizontalGaps = v!)),
                                        _buildCheckboxTile(
                                            'Gap Verticali',
                                            showVerticalGaps,
                                            (v) => setState(
                                                () => showVerticalGaps = v!)),
                                        _buildCheckboxTile(
                                            'Distanza Vetro ↔ Celle',
                                            showGlassCell,
                                            (v) => setState(
                                                () => showGlassCell = v!)),
                                        _buildCheckboxTile(
                                            'Distanza Vetro ↔ Ribbon',
                                            showGlassRibbon,
                                            (v) => setState(
                                                () => showGlassRibbon = v!)),
                                        _buildCheckboxTile(
                                            'Misure fuori Tolleranza',
                                            showWarnings,
                                            (v) => setState(
                                                () => showWarnings = v!)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ⬇️ Bottom: the interactive SolarPanel widget
                          SizedBox(
                            width: double.infinity,
                            child: ShimmerPanelReveal(
                              panel: DistancesSolarPanelWidget(
                                glassWidth: glassWidth,
                                glassHeight: glassHeight,
                                interconnectionRibbon:
                                    mbjData['interconnection_ribbon'],
                                interconnectionCell:
                                    mbjData['interconnection_cell'],
                                horizontalCellGaps:
                                    mbjData['horizontal_cell_mm'],
                                verticalCellGaps: mbjData['vertical_cell_mm'],
                                glassCellMm: mbjData['glass_cell_mm'],
                                showDimensions: true,
                                showRibbons: showRibbons,
                                showHorizontalGaps: showHorizontalGaps,
                                showVerticalGaps: showVerticalGaps,
                                showGlassCell: showGlassCell,
                                showGlassRibbon: showGlassRibbon,
                                showWarnings: showWarnings,
                                cellDefects: parsedDefects,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: SolarPanelWidget(
                          glassWidth: glassWidth,
                          glassHeight: glassHeight,
                          interconnectionRibbon:
                              mbjData['interconnection_ribbon'],
                          interconnectionCell: mbjData['interconnection_cell'],
                          horizontalCellGaps: mbjData['horizontal_cell_mm'],
                          verticalCellGaps: mbjData['vertical_cell_mm'],
                          glassCellMm: mbjData['glass_cell_mm'],
                          showDimensions: true,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _buildCheckboxTile(String title, bool value, Function(bool?) onChanged) {
  return Container(
    margin:
        const EdgeInsets.only(right: 12), // horizontal spacing between tiles
    child: InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFF007AFF).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // <– prevents horizontal expansion
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: value ? const Color(0xFF007AFF) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value
                      ? const Color(0xFF007AFF)
                      : Colors.black.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.8),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
