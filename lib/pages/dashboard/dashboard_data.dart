import 'package:flutter/material.dart';
import 'package:ix_monitor/pages/graphs/find_page.dart';
import '../graphs/data_view.dart';

class DashboardData extends StatefulWidget {
  const DashboardData({super.key});

  @override
  State<DashboardData> createState() => _DashboardDataState();
}

class _DashboardDataState extends State<DashboardData> {
  int _currentIndex = 0;
  List<Map<String, String>>? filtersForFindPage;
  bool autoSearch = false;

  List<Widget> get _pages => [
        DataViewPage(
          canSearch: true,
          onBarTap: (filters) {
            setState(() {
              filtersForFindPage = filters;
              autoSearch = true;
              _currentIndex = 1;
            });
          },
        ),
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
            label: 'Dati',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.query_stats),
            label: 'Ricerca Dati',
          ),
        ],
      ),
    );
  }
}
