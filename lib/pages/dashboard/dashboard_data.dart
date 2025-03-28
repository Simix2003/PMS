import 'package:flutter/material.dart';
import 'package:ix_monitor/pages/work_in_progress.dart';
import '../create_visuals_page.dart';
import '../graphs/data_view.dart';

class DashboardData extends StatefulWidget {
  const DashboardData({super.key});

  @override
  State<DashboardData> createState() => _DashboardDataState();
}

class _DashboardDataState extends State<DashboardData> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DataViewPage(),
    const OverlayEditorPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.query_stats),
            label: 'Analisi Dati',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.airline_stops_rounded),
            label: 'AI',
          ),
        ],
      ),
    );
  }
}
