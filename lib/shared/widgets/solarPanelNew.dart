// lib/shared/widgets/solarPanelNew.dart
import 'package:flutter/material.dart';

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
  final List<Map<String, dynamic>>? cellDefects;

  const DistancesSolarPanelWidget({
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
    required this.cellDefects,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final maxW = screenW - 32;
    final aspect = glassWidth / glassHeight;
    final maxH = screenH * 0.75;
    final height = (maxW / aspect < maxH) ? maxW / aspect : maxH;
    final width = height * aspect;

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
                      final r0 = realWidth - em - rw - rc;

                      double left;
                      if (y < colsPerSide) {
                        left = l0 + y * (cw + gh);
                      } else {
                        final colIndex = y - colsPerSide;
                        left = r0 - (colIndex + 1) * (cw + gh) + gh;
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
                          ),
                        ),
                      );
                    }),
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

                  // Labels aligned to actual painter size
                  if (showDimensions)
                    ..._buildOverlayLabels(realWidth, realHeight),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOverlayLabels(double width, double height) {
    final labels = <Widget>[];
    final colW = width / 20;
    final rowH = height / 6;

    final style = TextStyle(
      fontSize: 10,
      color: Colors.black,
      // ignore: deprecated_member_use
      backgroundColor: Colors.white.withOpacity(0.8),
    );

    if (showGlassCell && glassCellMm != null) {
      final top = List<double>.from(glassCellMm!['top'] ?? []);
      final bot = List<double>.from(glassCellMm!['bottom'] ?? []);

      // Use same values as painter
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
      final r0 = width - em - rw - rc;

      for (int i = 0; i < top.length; i++) {
        double x;
        if (i < colsPerSide) {
          // left side
          x = l0 + i * (cw + gh);
        } else {
          // right side
          final ci = i - colsPerSide;
          x = r0 - (ci + 1) * (cw + gh) + gh;
        }

        labels.add(Positioned(
          left: x + cw / 4, // Center text within cell
          top: 2,
          child: Text('${top[i].toStringAsFixed(1)}', style: style),
        ));
      }

      for (int i = 0; i < bot.length; i++) {
        double x;
        if (i < colsPerSide) {
          x = l0 + i * (cw + gh);
        } else {
          final ci = i - colsPerSide;
          x = r0 - (ci + 1) * (cw + gh) + gh;
        }

        labels.add(Positioned(
          left: x + cw / 4,
          top: height - 14,
          // text should also include ' mm' in the Text
          child: Text('${bot[i].toStringAsFixed(1)}', style: style),
        ));
      }
    }

    // 2) Glass ↔ Ribbon distances
    if (showGlassRibbon && interconnectionRibbon != null) {
      // top-of-block and bottom-of-block values for each side-ribbon block
      for (int block = 0; block < 3; block++) {
        final r0 = block * 2, r1 = r0 + 1;
        final d0 = interconnectionRibbon!['$r0'];
        final d1 = interconnectionRibbon!['$r1'];
        if (d0 == null || d1 == null) continue;

        final y0 = rowH * r0 + 4;
        final y1 = rowH * (r1 + 1) - 16;
        final lt = d0['left']['top']?.toStringAsFixed(1);
        final lb = d1['left']['bottom']?.toStringAsFixed(1);
        final rt = d0['right']['top']?.toStringAsFixed(1);
        final rb = d1['right']['bottom']?.toStringAsFixed(1);

        if (lt != null) {
          labels.add(
              Positioned(left: 4, top: y0, child: Text('$lt', style: style)));
        }
        if (lb != null) {
          labels.add(
              Positioned(left: 4, top: y1, child: Text('$lb', style: style)));
        }
        if (rt != null) {
          labels.add(
              Positioned(right: 4, top: y0, child: Text('$rt', style: style)));
        }
        if (rb != null) {
          labels.add(
              Positioned(right: 4, top: y1, child: Text('$rb', style: style)));
        }
      }
    }

    if (showRibbons && interconnectionCell != null) {
      for (int row = 0; row < 6; row++) {
        final data = interconnectionCell!['$row'];
        if (data == null) continue;

        final topY = rowH * row + 25; // was +2, now +6 to move it downward
        final bottomY =
            rowH * (row + 1) - 30; // was -14, now -18 to move it upward

        final rowKeys = ['y0', 'y9', 'y10', 'y19'];
        for (final key in rowKeys) {
          final d = data[key];
          if (d == null) continue;

          final topVal = d['top']?.toStringAsFixed(1);
          final bottomVal = d['bottom']?.toStringAsFixed(1);
          if (topVal == null || bottomVal == null) continue;

          double x;
          switch (key) {
            case 'y0':
              x = colW / 3; // Left ribbon
              break;
            case 'y9':
              x = colW * 10 - 25; // Just to the left of the middle ribbon
              break;
            case 'y10':
              x = colW * 10 + 10; // Just to the right of the middle ribbon
              break;
            case 'y19':
              x = width - colW; // Right ribbon
              break;
            default:
              continue;
          }

          // Add top value
          labels.add(Positioned(
            left: x,
            top: topY,
            child: Text(topVal, style: style),
          ));

          // Add bottom value
          labels.add(Positioned(
            left: x,
            top: bottomY,
            child: Text(bottomVal, style: style),
          ));
        }
      }
    }

    if (showHorizontalGaps && horizontalCellGaps != null) {
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
      final r0 = width - em - rw - rc;

      horizontalCellGaps!.forEach((r, list) {
        final row = int.tryParse(r);
        if (row == null) return;
        final y = rowH * row + rowH / 2;

        for (int i = 1; i < list.length; i++) {
          final v = list[i];
          if (v == null) continue;

          double xEdge, xGap;

          if (i < colsPerSide) {
            xEdge = l0 + i * (cw + gh);
          } else {
            final ri = i - colsPerSide;
            xEdge = r0 - ri * (cw + gh);
          }

          xGap = xEdge - gh / 2;

          labels.add(Positioned(
            left: xGap - 6,
            top: y,
            child: Text('${v.toStringAsFixed(1)}', style: style),
          ));
        }
      });
    }

    if (showVerticalGaps && verticalCellGaps != null) {
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
      final r0 = width - em - rw - rc;

      verticalCellGaps!.forEach((c, list) {
        final col = int.tryParse(c);
        if (col == null) return;

        double x;
        if (col < colsPerSide) {
          // left side
          x = l0 + col * (cw + gh) + cw / 2;
        } else {
          // right side
          final ci = col - colsPerSide;
          x = r0 - (ci + 1) * (cw + gh) + gh + cw / 2;
        }

        for (int r = 0; r < list.length; r++) {
          final v = list[r];
          if (v == null) continue;

          //final y = rowH * (r + 1) - rowH / 4;
          final y = rowH * (r + 1) - rowH / 10;

          labels.add(Positioned(
            left: x - 8, // shift text left to center over cell
            top: y,
            child: Text('${v.toStringAsFixed(1)}', style: style),
          ));
        }
      });
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
    final mPaint = Paint()..color = Colors.green;

    final cw = size.width * cellWFrac;
    final ch = size.height * cellHFrac;
    final gv = size.height / rows;
    final gh = size.width * hSpacingFrac;
    final rw = size.width * ribbonWFrac;
    final em = size.width * sideRibbonMargin;
    final rc = size.width * ribbonToCellGap;
    final vb = size.height * verticalRibbonGap;

    final l0 = em + rw + rc;
    final r0 = size.width - em - rw - rc;

    // cells
    for (int row = 0; row < rows; row++) {
      final y = row * gv + (gv - ch) / 2;
      for (int c = 0; c < colsPerSide; c++) {
        final xL = l0 + c * (cw + gh);
        canvas.drawRect(Rect.fromLTWH(xL, y, cw, ch), cPaint);
        final xR = r0 - (c + 1) * (cw + gh) + gh;
        canvas.drawRect(Rect.fromLTWH(xR, y, cw, ch), cPaint);
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
