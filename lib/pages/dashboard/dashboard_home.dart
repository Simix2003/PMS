import 'package:flutter/material.dart';
import 'package:ix_monitor/pages/work_in_progress.dart';
import '../home_page/home_page.dart';

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const WorkInProgressPage(),
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
            icon: Icon(Icons.feedback),
            label: 'Work in Progress',
          ),
        ],
      ),
    );
  }
}
