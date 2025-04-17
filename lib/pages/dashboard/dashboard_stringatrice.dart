import 'package:flutter/material.dart';
import 'package:ix_monitor/pages/graphs/data_view.dart';
import '../stringatrice_warning_page.dart';

class DashboardStringatrice extends StatefulWidget {
  const DashboardStringatrice({super.key});

  @override
  State<DashboardStringatrice> createState() => _DashboardStringatriceState();
}

class _DashboardStringatriceState extends State<DashboardStringatrice> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const WarningsPage(),
    const DataViewPage(
      canSearch: false,
    )
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
            icon: Icon(Icons.feedback),
            label: 'Warnings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.today),
            label: 'Dati',
          ),
        ],
      ),
    );
  }
}
