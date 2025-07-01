// lib/shared/widgets/solarPanelNew.dart
// ignore_for_file: must_be_immutable, deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:math' as math;

class DistancesSolarPanelWidget extends StatelessWidget {
  final double glassWidth;
  final double glassHeight;
  final Map<String, dynamic>? interconnectionRibbon;
  final Map<String, dynamic>? interconnectionCell;
  final Map<String, dynamic>? horizontalCellGaps;
  final Map<String, dynamic>? verticalCellGaps;
  final Map<String, dynamic>? glassCellMm;
  final bool showDimensions;
  final bool showRibbons;
  final bool showHorizontalGaps;
  final bool showVerticalGaps;
  final bool showGlassCell;
  final bool showGlassRibbon;
  final bool showWarnings;
  final List<Map<String, dynamic>>? cellDefects;

  DistancesSolarPanelWidget({
    super.key,
    this.glassWidth = 2166,
    this.glassHeight = 1297,
    this.interconnectionRibbon,
    this.interconnectionCell,
    this.horizontalCellGaps,
    this.verticalCellGaps,
    this.glassCellMm,
    this.showDimensions = false,
    this.showRibbons = false,
    this.showHorizontalGaps = false,
    this.showVerticalGaps = false,
    this.showGlassCell = false,
    this.showGlassRibbon = false,
    this.showWarnings = false,
    required this.cellDefects,
  });

  Map<String, (double, double)> groupTolerances = {
    'GlassRibbon': (11.99, 99.0), // > 12mm Glass to Ribbon

    'RibbonCellSide': (0.99, 99.0), // 2 mm Side Ribbon to Cell
    'RibbonCellMiddle': (0.99, 99.0), // 3 mm Middle Ribbon to Cell

    'HorizontalGap': (0, 99.0), // Still don't know this Measure

    'VerticalGap': (0.99, 99.0), // 2.1mm gaps between Stringhe

    'GlassCellTopLeft': (11.99, 99.0), // 13.65 mm Top Glass to Cell
    'GlassCellTopRight': (11.99, 99.0), // 12.85 mm Top Glass to Cell
    'GlassCellBottomLeft': (11.99, 99.0), // 12.85 mm Bottom Glass to Cell
    'GlassCellBottomRight': (11.99, 99.0), // 13.65 mm Bottom Glass to Cell
  };

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final maxW = screenW - 32;
    final aspect = glassWidth / glassHeight;
    final maxH = screenH * 0.75;
    final height = (maxW / aspect < maxH) ? maxW / aspect : maxH;
    final width = height * aspect;

    String formatDefectId(int id) {
      switch (id) {
        case 7:
          return "Crack";
        case 81:
          return "Bad\nSoldering";
        default:
          return "$id";
      }
    }

    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: InteractiveViewer(
          maxScale: 5,
          minScale: 0.5,
          boundaryMargin: const EdgeInsets.all(32),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final realWidth = constraints.maxWidth;
              final realHeight = constraints.maxHeight;

              return Stack(
                children: [
                  // Panel background and painter
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade700, width: 2),
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFCFD8DC), Color(0xFFECEFF1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CustomPaint(
                      painter: _StylisedPanelPainter(),
                      child: Container(), // force layout
                    ),
                  ),
                  if (cellDefects != null)
                    ...cellDefects!.map((defect) {
                      final int x = defect['x'];
                      final int y = defect['y'];
                      final List<dynamic> defectIds = defect['defects'];

                      // Layout logic
                      const colsPerSide = _StylisedPanelPainter.colsPerSide;
                      const cellWFrac = _StylisedPanelPainter.cellWFrac;
                      const cellHFrac = _StylisedPanelPainter.cellHFrac;
                      const hSpacingFrac = _StylisedPanelPainter.hSpacingFrac;
                      const sideRibbonMargin =
                          _StylisedPanelPainter.sideRibbonMargin;
                      const ribbonWFrac = _StylisedPanelPainter.ribbonWFrac;
                      const ribbonToCellGap =
                          _StylisedPanelPainter.ribbonToCellGap;

                      final cw = realWidth * cellWFrac;
                      final ch = realHeight * cellHFrac;
                      final gh = realWidth * hSpacingFrac;
                      final em = realWidth * sideRibbonMargin;
                      final rw = realWidth * ribbonWFrac;
                      final rc = realWidth * ribbonToCellGap;

                      final l0 = em + rw + rc;
                      final r0 =
                          realWidth - em - rw - rc - (cw + gh) * colsPerSide;

                      double left;
                      if (y < colsPerSide) {
                        // Left side (0–9)
                        left = l0 + y * (cw + gh);
                      } else {
                        // Right side (10–19)
                        final colIndex = y - colsPerSide;
                        left = r0 + colIndex * (cw + gh);
                      }

                      final top =
                          x * realHeight / 6 + (realHeight / 6 - ch) / 2;

                      return Positioned(
                        left: left,
                        top: top,
                        width: cw,
                        height: ch,
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("Defecti nella cella"),
                                content: Text(
                                    "Posizione ($x,$y)\nDefect IDs: ${defectIds.join(", ")}"),
                                actions: [
                                  TextButton(
                                    child: const Text("Chiudi"),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.4),
                              border: Border.all(color: Colors.red, width: 1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            alignment: Alignment.center,
                            // Inside your Positioned widget
                            child: Text(
                              defectIds
                                  .toSet() // Remove duplicates
                                  .map((id) => formatDefectId(id))
                                  .toSet() // In case the mapped text duplicates (e.g., multiple 7s)
                                  .join("\n"),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                shadows: [
                                  Shadow(blurRadius: 1, color: Colors.black),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  // Labels aligned to actual painter size
                  Positioned(
                    bottom: 8,
                    left: 2,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Container(
                        color: Colors.yellow,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 1),
                        child: const Text(
                          'Label',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showDimensions)
                    ..._buildOverlayLabels(
                        realWidth, realHeight, groupTolerances),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOverlayLabels(
    double width,
    double height,
    Map<String, (double, double)> groupTolerances,
  ) {
    final labels = <Widget>[];
    final colW = width / 20;
    final rowH = height / 6;

    final baseStyle = TextStyle(
      fontSize: 10,
      color: Colors.black,
      backgroundColor: Colors.white.withOpacity(0.8),
    );
    final warnStyle = baseStyle.copyWith(color: Colors.red);

    double roundTo(double value, int places) {
      final mod = math.pow(10.0, places);
      return (value * mod).round() / mod;
    }

    bool isOutOfTol(double v, String group) {
      final (min, max) =
          groupTolerances[group] ?? (double.negativeInfinity, double.infinity);
      final rounded = roundTo(v, 1); // Match .toStringAsFixed(1)
      return rounded < min || rounded > max;
    }

    bool shouldShow(double? v, bool groupFlag, String group) {
      if (v == null) return false;
      if (groupFlag) return true; // group explicitly ON
      return showWarnings && isOutOfTol(v, group); // group OFF → only red
    }

    TextStyle styleFor(double v, String group) => isOutOfTol(v, group)
        ? showWarnings
            ? warnStyle
            : baseStyle
        : baseStyle;

    // ───────────────────── 1) Glass ↔ Ribbon (side‑ribbons) ─────────────────────
    if (interconnectionRibbon != null) {
      for (int block = 0; block < 3; block++) {
        final r0 = block * 2, r1 = r0 + 1;
        final d0 = interconnectionRibbon!['$r0'];
        final d1 = interconnectionRibbon!['$r1'];
        if (d0 == null || d1 == null) continue;

        final y0 = rowH * r0 + 4;
        final y1 = rowH * (r1 + 1) - 16;
        const grp = 'GlassRibbon';
        final flag = showGlassRibbon;

        double? v(dynamic m, String side) =>
            (m?[side]) is num ? (m[side] as num).toDouble() : null;

        final lt = v(d0, 'left');
        final lb = v(d1, 'left');
        final rt = v(d0, 'right');
        final rb = v(d1, 'right');

        if (shouldShow(lt, flag, grp)) {
          labels.add(Positioned(
              left: 4,
              top: y0,
              child: Text(lt!.toStringAsFixed(1), style: styleFor(lt, grp))));
        }
        if (shouldShow(lb, flag, grp)) {
          labels.add(Positioned(
              left: 4,
              top: y1,
              child: Text(lb!.toStringAsFixed(1), style: styleFor(lb, grp))));
        }
        if (shouldShow(rt, flag, grp)) {
          labels.add(Positioned(
              right: 4,
              top: y0,
              child: Text(rt!.toStringAsFixed(1), style: styleFor(rt, grp))));
        }
        if (shouldShow(rb, flag, grp)) {
          labels.add(Positioned(
              right: 4,
              top: y1,
              child: Text(rb!.toStringAsFixed(1), style: styleFor(rb, grp))));
        }
      }
    }

    // ───────────────────── 2) Ribbon ↔ Cell distances ───────────────────────────
    if (interconnectionCell != null) {
      for (int row = 0; row < 6; row++) {
        final data = interconnectionCell!['$row'];
        if (data == null) continue;
        final topY = rowH * row + 25;
        final bottomY = rowH * (row + 1) - 30;

        for (final key in ['y0', 'y9', 'y10', 'y19']) {
          final d = data[key];
          if (d == null) continue;

          final val = (d['avg'] as num?)?.toDouble();
          if (val == null) continue;

          final grp = (key == 'y0' || key == 'y19')
              ? 'RibbonCellSide'
              : 'RibbonCellMiddle';
          final flag = showRibbons;

          double x;
          switch (key) {
            case 'y0':
              x = colW / 3;
              break;
            case 'y9':
              x = colW * 10 - 25;
              break;
            case 'y10':
              x = colW * 10 + 10;
              break;
            case 'y19':
              x = width - colW;
              break;
            default:
              continue;
          }

          if (shouldShow(val, flag, grp)) {
            labels.add(Positioned(
                left: x,
                top: (topY + bottomY) / 2,
                child:
                    Text(val.toStringAsFixed(1), style: styleFor(val, grp))));
          }
        }
      }
    }

    // ───────────────────── 3) Horizontal cell gaps ─────────────────────────────
    if (horizontalCellGaps != null) {
      const grp = 'HorizontalGap';
      final flag = showHorizontalGaps;
      const colsPerSide = _StylisedPanelPainter.colsPerSide;
      const ribbonWFrac = _StylisedPanelPainter.ribbonWFrac;
      const sideRibbonMargin = _StylisedPanelPainter.sideRibbonMargin;
      const ribbonToCellGap = _StylisedPanelPainter.ribbonToCellGap;
      const hSpacingFrac = _StylisedPanelPainter.hSpacingFrac;
      const cellWFrac = _StylisedPanelPainter.cellWFrac;

      final rw = width * ribbonWFrac;
      final em = width * sideRibbonMargin;
      final rc = width * ribbonToCellGap;
      final gh = width * hSpacingFrac;
      final cw = width * cellWFrac;
      final l0 = em + rw + rc;
      final r0 = width - em - rw - rc - (cw + gh) * colsPerSide;

      horizontalCellGaps!.forEach((r, list) {
        final rowIdx = int.tryParse(r);
        if (rowIdx == null) return;
        final y = rowH * rowIdx + rowH / 2;

        for (int i = 1; i < list.length; i++) {
          final v = (list[i] as num?)?.toDouble();
          if (v == null || !shouldShow(v, flag, grp)) continue;

          final xEdge = (i < colsPerSide)
              ? l0 + i * (cw + gh)
              : r0 + (i - colsPerSide) * (cw + gh);

          final xGap = xEdge - gh / 2;
          labels.add(Positioned(
            left: xGap - 6,
            top: y,
            child: Text(v.toStringAsFixed(1), style: styleFor(v, grp)),
          ));
        }
      });
    }

    // ───────────────────── 4) Vertical cell gaps ───────────────────────────────
    if (verticalCellGaps != null) {
      const grp = 'VerticalGap';
      final flag = showVerticalGaps;
      const ribbonWFrac = _StylisedPanelPainter.ribbonWFrac;
      const sideRibbonMargin = _StylisedPanelPainter.sideRibbonMargin;
      const ribbonToCellGap = _StylisedPanelPainter.ribbonToCellGap;
      const hSpacingFrac = _StylisedPanelPainter.hSpacingFrac;
      const cellWFrac = _StylisedPanelPainter.cellWFrac;

      final rw = width * ribbonWFrac;
      final em = width * sideRibbonMargin;
      final rc = width * ribbonToCellGap;
      final gh = width * hSpacingFrac;
      final cw = width * cellWFrac;

      final l0 = em + rw + rc;
      final r0 = width - em - rw - rc - (cw + gh) * 10;

      for (int row = 0; row < 5; row++) {
        final rowData = verticalCellGaps!['$row'];
        if (rowData == null) continue;

        final y = rowH * (row + 1) - rowH / 10;

        for (final entry in (rowData['left'] as Map).entries) {
          final col = int.tryParse(entry.key.substring(1));
          final v = (entry.value as num?)?.toDouble();
          if (col == null || v == null || !shouldShow(v, flag, grp)) continue;

          final x = l0 + col * (cw + gh) + cw / 2;
          labels.add(Positioned(
              left: x - 8,
              top: y,
              child: Text(v.toStringAsFixed(1), style: styleFor(v, grp))));
        }

        for (final entry in (rowData['right'] as Map).entries) {
          final col = int.tryParse(entry.key.substring(1));
          final v = (entry.value as num?)?.toDouble();
          if (col == null || v == null || !shouldShow(v, flag, grp)) continue;

          final x = r0 + (col - 10) * (cw + gh) + cw / 2;
          labels.add(Positioned(
              left: x - 8,
              top: y,
              child: Text(v.toStringAsFixed(1), style: styleFor(v, grp))));
        }
      }
    }

    // ───────────────────── 5) Glass ↔ Cell distances (Top/Bottom each cell) ─────
    if (glassCellMm != null) {
      final topList = (glassCellMm!['top'] as List<dynamic>).cast<num?>();
      final botList = (glassCellMm!['bottom'] as List<dynamic>).cast<num?>();
      const colsPerSide = _StylisedPanelPainter.colsPerSide;
      const ribbonWFrac = _StylisedPanelPainter.ribbonWFrac;
      const sideRibbonMargin = _StylisedPanelPainter.sideRibbonMargin;
      const ribbonToCellGap = _StylisedPanelPainter.ribbonToCellGap;
      const hSpacingFrac = _StylisedPanelPainter.hSpacingFrac;
      const cellWFrac = _StylisedPanelPainter.cellWFrac;

      final rw = width * ribbonWFrac;
      final em = width * sideRibbonMargin;
      final rc = width * ribbonToCellGap;
      final gh = width * hSpacingFrac;
      final cw = width * cellWFrac;
      final l0 = em + rw + rc;
      final r0 = width - em - rw - rc - (cw + gh) * colsPerSide;

      for (int i = 0; i < topList.length; i++) {
        final topVal = topList[i]?.toDouble();
        if (topVal != null) {
          final grp =
              (i < colsPerSide) ? 'GlassCellTopLeft' : 'GlassCellTopRight';
          final flag = showGlassCell;
          if (shouldShow(topVal, flag, grp)) {
            final x = (i < colsPerSide)
                ? l0 + i * (cw + gh) + cw / 4
                : r0 + (i - colsPerSide) * (cw + gh) + cw / 4;
            labels.add(Positioned(
                left: x,
                top: 2,
                child: Text(topVal.toStringAsFixed(1),
                    style: styleFor(topVal, grp))));
          }
        }
      }

      for (int i = 0; i < botList.length; i++) {
        final botVal = botList[i]?.toDouble();
        if (botVal != null) {
          final grp = (i < colsPerSide)
              ? 'GlassCellBottomLeft'
              : 'GlassCellBottomRight';
          final flag = showGlassCell;
          if (shouldShow(botVal, flag, grp)) {
            final x = (i < colsPerSide)
                ? l0 + i * (cw + gh) + cw / 4
                : r0 + (i - colsPerSide) * (cw + gh) + cw / 4;
            labels.add(Positioned(
                left: x,
                top: height - 14,
                child: Text(botVal.toStringAsFixed(1),
                    style: styleFor(botVal, grp))));
          }
        }
      }
    }

    return labels;
  }
}

class _StylisedPanelPainter extends CustomPainter {
  static const rows = 6, colsPerSide = 10;
  static const ribbonWFrac = 0.012;
  static const cellWFrac = 0.04;
  static const cellHFrac = 0.115;
  static const hSpacingFrac = 0.005;
  static const sideRibbonMargin = 0.01;
  static const ribbonToCellGap = 0.005;
  static const verticalRibbonGap = 0.008;

  @override
  void paint(Canvas canvas, Size size) {
    final cPaint = Paint()..color = Colors.white;
    final sPaint = Paint()..color = Colors.blueGrey;
    final mPaint = Paint()..color = Colors.blueGrey;

    final cw = size.width * cellWFrac;
    final ch = size.height * cellHFrac;
    final gv = size.height / rows;
    final gh = size.width * hSpacingFrac;
    final rw = size.width * ribbonWFrac;
    final em = size.width * sideRibbonMargin;
    final rc = size.width * ribbonToCellGap;
    final vb = size.height * verticalRibbonGap;

    final l0 = em + rw + rc;
    //final r0 = size.width - em - rw - rc;
    final r0 = size.width - em - rw - rc - (cw + gh) * colsPerSide;

    // cells
    /*for (int row = 0; row < rows; row++) {
      final y = row * gv + (gv - ch) / 2;
      for (int c = 0; c < colsPerSide; c++) {
        final xL = l0 + c * (cw + gh);
        canvas.drawRect(Rect.fromLTWH(xL, y, cw, ch), cPaint);
        final xR = r0 - (c + 1) * (cw + gh) + gh;
        canvas.drawRect(Rect.fromLTWH(xR, y, cw, ch), cPaint);
      }
    }*/

    for (int row = 0; row < rows; row++) {
      final y = row * gv + (gv - ch) / 2;
      for (int c = 0; c < colsPerSide; c++) {
        // Left cells (y = 0–9)
        final xL = l0 + c * (cw + gh);
        canvas.drawRect(Rect.fromLTWH(xL, y, cw, ch), cPaint);
        _drawCellLabel(canvas, Offset(xL, y), cw, ch, row, c);

        // Right cells (y = 10–19)
        final xR = r0 + c * (cw + gh);
        canvas.drawRect(Rect.fromLTWH(xR, y, cw, ch), cPaint);
        _drawCellLabel(canvas, Offset(xR, y), cw, ch, row, 10 + c);
      }
    }

    // side ribbons
    for (int b = 0; b < 3; b++) {
      final h = 2 * gv - vb;
      final y = b * 2 * gv + vb / 2;
      canvas.drawRect(Rect.fromLTWH(em, y, rw, h), sPaint);
      canvas.drawRect(Rect.fromLTWH(size.width - em - rw, y, rw, h), sPaint);
    }

    // middle ribbons (1-2-2-1)
    const spans = [
      [0],
      [1, 2],
      [3, 4],
      [5]
    ];
    final mx = (size.width - rw) / 2;
    for (var span in spans) {
      final top = span.first * gv + vb / 2;
      final bot = (span.last + 1) * gv - vb / 2;
      canvas.drawRect(Rect.fromLTWH(mx, top, rw, bot - top), mPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

void _drawCellLabel(
    Canvas canvas, Offset offset, double w, double h, int row, int col) {
  final textSpan = TextSpan(
    text: "($row,$col)",
    style: const TextStyle(
      color: Colors.black,
      fontSize: 10,
    ),
  );
  final tp = TextPainter(
    text: textSpan,
    textDirection: TextDirection.ltr,
  );
  tp.layout();
  tp.paint(canvas, offset + Offset(2, 2)); // Top-left of cell
}
