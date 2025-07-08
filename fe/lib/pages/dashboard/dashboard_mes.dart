import 'package:flutter/material.dart';
import 'package:ix_monitor/pages/graphs/find_page.dart';
import 'package:ix_monitor/pages/mes/single_module_page.dart';

class DashboardMES extends StatefulWidget {
  const DashboardMES({super.key});

  @override
  State<DashboardMES> createState() => _DashboardMESState();
}

class _DashboardMESState extends State<DashboardMES> {
  int _currentIndex = 0;
  List<Map<String, String>>? filtersForFindPage;
  bool autoSearch = false;

  List<Widget> get _pages => [
        SingleModulePage(),
        FindPage(
          initialFilters: filtersForFindPage,
          autoSearch: autoSearch,
          onSearchCompleted: () {
            setState(() {
              autoSearch = false;
            });
          },
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;

            if (index == 1 && !autoSearch) {
              // 🧼 Reset filters ONLY if user manually taps the tab and it's not from a bar tap
              filtersForFindPage = null;
            }
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.today),
            label: 'Mini MES',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.query_stats),
            label: 'Mega MES',
          ),
        ],
      ),
    );
  }
}
