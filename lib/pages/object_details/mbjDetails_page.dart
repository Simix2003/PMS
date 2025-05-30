// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ix_monitor/shared/widgets/solarPanelNew.dart';
import '../../shared/services/api_service.dart';
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
        future: ApiService.fetchMBJDetails(idModulo),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text('Nessun dettaglio trovato per questo modulo.'),
            );
          }

          final mbjData = snapshot.data!;
          final glassWidth = (mbjData['glass_width'] ?? 2166).toDouble();
          final glassHeight = (mbjData['glass_height'] ?? 1297).toDouble();

          final raw = mbjData['cell_defects'];
          final parsedDefects =
              (raw as List).map((e) => Map<String, dynamic>.from(e)).toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: showDetailedView
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: the checkbox panel with Apple-style glassmorphism
                      SizedBox(
                        width: 250,
                        child: Container(
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
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Mostra Dimensioni (mm)',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black.withOpacity(0.8),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildCheckboxTile(
                                        'Interconnection Ribbon',
                                        showRibbons,
                                        (v) => setState(() => showRibbons = v!),
                                      ),
                                      _buildCheckboxTile(
                                        'Gap Orizzontali',
                                        showHorizontalGaps,
                                        (v) => setState(
                                            () => showHorizontalGaps = v!),
                                      ),
                                      _buildCheckboxTile(
                                        'Gap Verticali',
                                        showVerticalGaps,
                                        (v) => setState(
                                            () => showVerticalGaps = v!),
                                      ),
                                      _buildCheckboxTile(
                                        'Distanza Vetro ↔ Celle',
                                        showGlassCell,
                                        (v) =>
                                            setState(() => showGlassCell = v!),
                                      ),
                                      _buildCheckboxTile(
                                        'Distanza Vetro ↔ Ribbon',
                                        showGlassRibbon,
                                        (v) => setState(
                                            () => showGlassRibbon = v!),
                                      ),
                                      _buildCheckboxTile(
                                        'Misure fuori Tolleranza',
                                        showWarnings,
                                        (v) =>
                                            setState(() => showWarnings = v!),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right: the interactive SolarPanel viewer with distances
                      Expanded(
                        child: DistancesSolarPanelWidget(
                          glassWidth: glassWidth,
                          glassHeight: glassHeight,
                          interconnectionRibbon:
                              mbjData['interconnection_ribbon'],
                          interconnectionCell: mbjData['interconnection_cell'],
                          horizontalCellGaps: mbjData['horizontal_cell_mm'],
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
                    ],
                  )
                : Center(
                    child: SolarPanelWidget(
                      glassWidth: glassWidth,
                      glassHeight: glassHeight,
                      interconnectionRibbon: mbjData['interconnection_ribbon'],
                      interconnectionCell: mbjData['interconnection_cell'],
                      horizontalCellGaps: mbjData['horizontal_cell_mm'],
                      verticalCellGaps: mbjData['vertical_cell_mm'],
                      glassCellMm: mbjData['glass_cell_mm'],
                      showDimensions: true,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

// Add this helper method to your class:
Widget _buildCheckboxTile(String title, bool value, Function(bool?) onChanged) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
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
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.8),
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
