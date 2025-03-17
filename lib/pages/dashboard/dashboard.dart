import 'package:flutter/material.dart';
import '../graphs/data_view.dart';
import '../home_page/home_page.dart';
import '../object_details/object_details_page.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    ObjectDetailsPage(),
    DataViewPage(),
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
            label: 'Difetti',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Dettagli Oggetto',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.data_exploration),
            label: 'Analisi Dati',
          ),
        ],
      ),
    );
  }
}
