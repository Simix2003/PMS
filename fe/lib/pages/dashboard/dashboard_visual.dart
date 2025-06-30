import 'package:flutter/material.dart';
import '../visual/visual_page.dart';

class DashboardVisual extends StatelessWidget {
  final String zone;

  const DashboardVisual({super.key, required this.zone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VisualPage(zone: zone),
    );
  }
}
