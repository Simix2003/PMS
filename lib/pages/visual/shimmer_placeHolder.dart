// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

Widget buildShimmerBox({
  double height = 100,
  double width = double.infinity,
  EdgeInsets? margin,
}) {
  return Container(
    height: height,
    width: width,
    margin: margin,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
  );
}

Widget buildShimmerPlaceholder() {
  return Shimmer.fromColors(
    baseColor: Colors.grey.shade300,
    highlightColor: Colors.grey.shade100,
    period: const Duration(milliseconds: 1500), // Slow shimmer for better perf
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── HEADER ROW 1 ──
        Row(
          children: [
            Expanded(
                child: buildShimmerBox(height: 80, margin: EdgeInsets.all(4))),
            Expanded(
                child: buildShimmerBox(height: 80, margin: EdgeInsets.all(4))),
            Expanded(
                child: buildShimmerBox(height: 80, margin: EdgeInsets.all(4))),
          ],
        ),
        SizedBox(height: 12),

        // ── MAIN ROW ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT PANEL
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  buildShimmerBox(height: 200, margin: EdgeInsets.all(4)),
                  buildShimmerBox(height: 180, margin: EdgeInsets.all(4)),
                ],
              ),
            ),
            // CENTER PANEL
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  buildShimmerBox(height: 180, margin: EdgeInsets.all(4)),
                  buildShimmerBox(height: 200, margin: EdgeInsets.all(4)),
                ],
              ),
            ),
            // RIGHT PANEL
            Expanded(
              flex: 2,
              child: buildShimmerBox(height: 425, margin: EdgeInsets.all(4)),
            ),
          ],
        ),
        SizedBox(height: 12),

        // ── HEADER ROW 2 ──
        Row(
          children: [
            Expanded(
                flex: 3,
                child: buildShimmerBox(height: 65, margin: EdgeInsets.all(4))),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  buildShimmerBox(
                      height: 65, width: 65, margin: EdgeInsets.all(4)),
                  Expanded(
                      child: buildShimmerBox(
                          height: 65, margin: EdgeInsets.all(4))),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),

        // ── SECOND ROW ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  buildShimmerBox(height: 160, margin: EdgeInsets.all(4)),
                  buildShimmerBox(height: 160, margin: EdgeInsets.all(4)),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  buildShimmerBox(height: 160, margin: EdgeInsets.all(4)),
                  buildShimmerBox(height: 160, margin: EdgeInsets.all(4)),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
