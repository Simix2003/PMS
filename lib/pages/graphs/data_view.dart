// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

import 'find_page.dart';

class DataViewPage extends StatefulWidget {
  const DataViewPage({super.key});

  @override
  _DataViewPageState createState() => _DataViewPageState();
}

class _DataViewPageState extends State<DataViewPage> {
  late Future<Map<String, dynamic>> _dataFuture;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _dataFuture = fetchData();
  }

  Future<Map<String, dynamic>> fetchData() async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final response = await http.get(Uri.parse(
        'http://192.168.0.10:8000/api/productions_summary?date=$formattedDate'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Errore durante il caricamento dei dati');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Analisi Dati',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FindPage()),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          } else {
            final data = snapshot.data!;
            final stations = ['M308', 'M309', 'M326'];

            final maxY = stations
                    .map((station) => (data['stations'][station] as int))
                    .reduce((a, b) => a > b ? a : b) +
                20;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Oggi, ${DateFormat('d MMMM y', 'it_IT').format(_selectedDate)}',
                            style: const TextStyle(
                                fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 220,
                            child: BarChart(
                              BarChartData(
                                maxY: maxY.toDouble(),
                                barGroups:
                                    stations.asMap().entries.map((entry) {
                                  final station = entry.value;
                                  final idx = entry.key;
                                  return BarChartGroupData(
                                      x: idx,
                                      barRods: [
                                        BarChartRodData(
                                          toY: data['stations'][station]
                                                  ['good_count']
                                              .toDouble(),
                                          color: Colors.green,
                                          width: 20,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        BarChartRodData(
                                          toY: data['stations'][station]
                                                  ['bad_count']
                                              .toDouble(),
                                          color: Colors.red,
                                          width: 20,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ],
                                      showingTooltipIndicators: [0, 1],
                                      barsSpace: 25);
                                }).toList(),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget:
                                          (double value, TitleMeta meta) =>
                                              Text(
                                        stations[value.toInt()],
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          value.toInt().toString(),
                                          style: const TextStyle(fontSize: 12),
                                          textAlign: TextAlign.center,
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  horizontalInterval: 10,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: Colors.grey.withOpacity(0.3),
                                      strokeWidth: 1,
                                      dashArray: [4, 4],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
