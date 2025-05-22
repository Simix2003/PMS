import 'package:flutter/material.dart';

class SolarPanelWidget extends StatelessWidget {
  final double glassWidth;
  final double glassHeight;
  final Map<String, dynamic>? interconnectionRibbon;
  final Map<String, dynamic>? interconnectionCell;
  final Map<String, dynamic>? horizontalCellGaps;
  final Map<String, dynamic>? verticalCellGaps;
  final Map<String, dynamic>? glassCellMm;
  final bool showDimensions;

  const SolarPanelWidget({
    super.key,
    required this.glassWidth,
    required this.glassHeight,
    this.interconnectionRibbon,
    this.interconnectionCell,
    this.horizontalCellGaps,
    this.verticalCellGaps,
    this.glassCellMm,
    this.showDimensions = false,
  });

  /// Debug scaling factor: multiplies *everything* (dimensions, distances, gaps)
  static const double debugScale = 20.0;

  @override
  Widget build(BuildContext context) {
    // All millimeters are scaled here
    final scaledGlassWidth = glassWidth * debugScale;
    final scaledGlassHeight = glassHeight * debugScale;

    final double aspectRatio = scaledGlassWidth / scaledGlassHeight;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final maxPanelWidth = screenWidth - 16;
    final maxPanelHeight = screenHeight * 0.75;

    final widthBasedHeight = maxPanelWidth / aspectRatio;
    final panelHeight =
        widthBasedHeight <= maxPanelHeight ? widthBasedHeight : maxPanelHeight;
    final panelWidth = panelHeight * aspectRatio;

    return Center(
      child: InteractiveViewer(
        maxScale: 5.0,
        minScale: 0.5,
        boundaryMargin: const EdgeInsets.all(50),
        child: SizedBox(
          width: panelWidth,
          height: panelHeight,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade700, width: 2),
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                colors: [Color(0xFFCFD8DC), Color(0xFFECEFF1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    'Pannello Solare',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 1,
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
                ..._buildAllCells(panelWidth, panelHeight, scaledGlassWidth,
                    scaledGlassHeight),
                ..._buildSidesRibbons(
                    panelWidth, panelHeight, scaledGlassWidth),
                ..._buildMiddleRibbons(
                    panelWidth, panelHeight, scaledGlassWidth),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSidesRibbons(
      double panelWidth, double panelHeight, double scaledGlassWidth) {
    if (interconnectionRibbon == null) return [];

    const ribbonCount = 3;
    const ribbonHeightMm = 422.0;
    const ribbonWidthMm = 4.0;

    // all millimeter units are scaled
    final mmToPx = panelWidth / scaledGlassWidth;
    final rowHeightPx = panelHeight / 6;
    final ribbonWidthPx = ribbonWidthMm * debugScale * mmToPx;
    final ribbonHeightPx = ribbonHeightMm * debugScale * mmToPx;

    final List<Widget> ribbons = [];

    for (int i = 0; i < ribbonCount; i++) {
      final topRow = i * 2;
      final bottomRow = topRow + 1;

      final topData = interconnectionRibbon!["$topRow"];
      final bottomData = interconnectionRibbon!["$bottomRow"];
      if (topData == null || bottomData == null) continue;

      final centerOfRibbonPx = ((topRow + bottomRow + 1) / 2) * rowHeightPx;
      final topOffsetPx = centerOfRibbonPx - ribbonHeightPx / 2;

      final leftTop = topData["left"]["top"]?.toDouble();
      final leftBottom = bottomData["left"]["bottom"]?.toDouble();
      final rightTop = topData["right"]["top"]?.toDouble();
      final rightBottom = bottomData["right"]["bottom"]?.toDouble();

      if (leftTop != null && leftBottom != null) {
        final leftPx = (leftTop * debugScale) * mmToPx;

        ribbons.add(Positioned(
          left: leftPx,
          top: topOffsetPx,
          width: ribbonWidthPx,
          height: ribbonHeightPx,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ));
      }

      if (rightTop != null && rightBottom != null) {
        final rightPx =
            ((glassWidth - rightTop - ribbonWidthMm) * debugScale) * mmToPx;

        ribbons.add(Positioned(
          left: rightPx,
          top: topOffsetPx,
          width: ribbonWidthPx,
          height: ribbonHeightPx,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ));
      }
    }

    return ribbons;
  }

  // 1️⃣  Add this just under _buildSidesRibbons ---------------------------------
  List<Widget> _buildMiddleRibbons(
    double panelWidth,
    double panelHeight,
    double scaledGlassWidth,
  ) {
    if (interconnectionRibbon == null || horizontalCellGaps == null) return [];

    // ── geometry that never changes ────────────────────────────────────────────
    const double ribbonWidthMm = 7.0; // middle ribbon width
    const cellWidthMm = 105.0; // one cell
    const sideRibbonMm = 4.0; // outer ribbon width
    const middleHeights = <double>[204, 410, 410, 204]; // four ribbons

    // ── unit conversion helpers ───────────────────────────────────────────────
    final mm2px = panelWidth / scaledGlassWidth; // same as other painters
    double mm(double v) => v * debugScale * mm2px; // millimetres → px quickly

    // pre-compute one row’s X where the gap between the two half-strings starts
    double gap10StartPx(int row) {
      final gaps = List<double?>.from(horizontalCellGaps!['$row'] ?? const []);

      // left-hand side ribbon distance from glass edge
      final leftRibbonMm =
          (interconnectionRibbon!['$row']['left']['top'] + sideRibbonMm)
              .toDouble();

      // walk across the first 10 cells (index 0-9) + the 10 inter-cell gaps
      double acc = leftRibbonMm + (gaps[0] ?? 0);

      for (var c = 0; c < 10; c++) {
        acc += cellWidthMm + (gaps[c + 1] ?? 0);
      }
      return mm(acc); // convert to px only once
    }

    // which rows each ribbon spans
    const spans = [
      [0], // ribbon 0 – row 0 only
      [1, 2], // ribbon 1 – rows 1-2
      [3, 4], // ribbon 2 – rows 3-4
      [5], // ribbon 3 – row 5 only
    ];

    final rowHeightPx = panelHeight / 6;
    final wPx = mm(ribbonWidthMm);

    final List<Widget> ribbons = [];

    for (var i = 0; i < 4; i++) {
      final rows = spans[i];
      final topRow = rows.first;
      final botRow = rows.last;

      // average the gap-10 start for every row we touch → keeps the ribbon
      // square even if the two half-strings are slightly skewed.
      final leftPx =
          rows.map(gap10StartPx).reduce((a, b) => a + b) / rows.length;

      // vertical placement: centre of the rows we cover
      final centerY = ((topRow + botRow + 1) / 2) * rowHeightPx;
      final hPx = mm(middleHeights[i]);
      final topPx = centerY - hPx / 2;

      ribbons.add(Positioned(
        left: leftPx,
        top: topPx,
        width: wPx,
        height: hPx,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green.shade600, // <- distinguish from side ribbons
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ));
    }

    return ribbons;
  }

  List<Widget> _buildAllCells(double wPx, double hPx, double scaledGlassWidth,
      double scaledGlassHeight) {
    if (horizontalCellGaps == null ||
        interconnectionRibbon == null ||
        verticalCellGaps == null ||
        glassCellMm == null) {
      return [];
    }

    const rows = 6;
    const cellWmm = 95.0, cellHmm = 200.0, ribbonWmm = 4.0;

    final mm2px = wPx / scaledGlassWidth;
    final rowHpx = hPx / rows;
    final List<Widget> out = [];

    // All clearances from glass edge are scaled
    final List<double?> topClr =
        List<double?>.from(glassCellMm?['top'] ?? const []);
    final List<double?> botClr =
        List<double?>.from(glassCellMm?['bottom'] ?? const []);

    final List<double> scaledTopClr =
        topClr.map((v) => (v ?? 0) * debugScale).toList();
    final List<double> scaledBotClr =
        botClr.map((v) => (v ?? 0) * debugScale).toList();

    double topYFor(int row, int col) {
      if (row == 0 && col < scaledTopClr.length) {
        return (scaledTopClr[col] * mm2px) + 2;
      }
      return row * rowHpx + (rowHpx - cellHmm * debugScale * mm2px) / 2;
    }

    double botYFor(int row, int col) {
      if (row == 5 && col < scaledBotClr.length) {
        return hPx - (scaledBotClr[col] * mm2px) - 2;
      }
      return topYFor(row, col) + cellHmm * debugScale * mm2px;
    }

    for (int r = 0; r < rows; r++) {
      final rawGaps = List<double?>.from(horizontalCellGaps!["$r"] ?? const []);
      final scaledGaps = rawGaps.map((v) => (v ?? 0.0) * debugScale).toList();
      final vGaps = verticalCellGaps!;
      final rib = interconnectionRibbon!["$r"];
      if (rawGaps.length != 20 || rib == null) continue;

      final leftRib = rib["left"];
      if (leftRib?["top"] == null || leftRib?["bottom"] == null) continue;
      final leftEdgeTopMm = (leftRib["top"] + ribbonWmm) * debugScale;
      final leftEdgeBotMm = (leftRib["bottom"] + ribbonWmm) * debugScale;

      double curTopMm = leftEdgeTopMm + scaledGaps[0];
      double curBotMm = leftEdgeBotMm + scaledGaps[0];

      for (int c = 0; c < 10; c++) {
        final skewT = (vGaps["$c"]?[r] ?? 0).toDouble() * debugScale;
        final topY = topYFor(r, c) + skewT * mm2px;
        final botY = botYFor(r, c) + skewT * mm2px;

        out.add(_cell(
          Offset(curTopMm * mm2px, topY),
          Offset(curBotMm * mm2px, botY),
          cellWmm: cellWmm * debugScale,
          mm2px: mm2px,
        ));

        if (c < 9) {
          curTopMm += cellWmm * debugScale + scaledGaps[c + 1];
          curBotMm += cellWmm * debugScale + scaledGaps[c + 1];
        }
      }

      final rightRib = rib["right"];
      if (rightRib?["top"] == null || rightRib?["bottom"] == null) continue;
      double rightEdgeTopMm =
          (glassWidth - rightRib["top"] - ribbonWmm) * debugScale;
      double rightEdgeBotMm =
          (glassWidth - rightRib["bottom"] - ribbonWmm) * debugScale;

      curTopMm = rightEdgeTopMm - scaledGaps[19] - cellWmm * debugScale;
      curBotMm = rightEdgeBotMm - scaledGaps[19] - cellWmm * debugScale;

      for (int c = 19; c >= 10; c--) {
        final skewT = (vGaps["$c"]?[r] ?? 0).toDouble() * debugScale;
        final topY = topYFor(r, c) + skewT * mm2px;
        final botY = botYFor(r, c) + skewT * mm2px;

        out.add(_cell(
          Offset(curTopMm * mm2px, topY),
          Offset(curBotMm * mm2px, botY),
          cellWmm: cellWmm * debugScale,
          mm2px: mm2px,
        ));

        if (c > 10) {
          curTopMm -= cellWmm * debugScale + scaledGaps[c - 1];
          curBotMm -= cellWmm * debugScale + scaledGaps[c - 1];
        }
      }
    }

    return out;
  }

  Widget _cell(Offset topLeft, Offset bottomLeft,
      {required double cellWmm, required double mm2px}) {
    return CustomPaint(
      painter: _CellPainter(
        topLeft: topLeft,
        bottomLeft: bottomLeft,
        widthPx: cellWmm * mm2px,
      ),
    );
  }
}

class _CellPainter extends CustomPainter {
  final Offset topLeft;
  final Offset bottomLeft;
  final double widthPx;

  _CellPainter({
    required this.topLeft,
    required this.bottomLeft,
    required this.widthPx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topLeft.dx + widthPx, topLeft.dy)
      ..lineTo(bottomLeft.dx + widthPx, bottomLeft.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(
      path,
      paint
        ..style = PaintingStyle.stroke
        ..color = Colors.red
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
