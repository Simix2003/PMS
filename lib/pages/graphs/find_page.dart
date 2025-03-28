import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FindPage extends StatefulWidget {
  const FindPage({super.key});

  @override
  _FindPageState createState() => _FindPageState();
}

class _FindPageState extends State<FindPage> {
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? _selectedRange;

  List<String> stations = ['M308', 'M309', 'M326'];
  List<String> selectedStations = [];
  bool showGood = true;
  bool showBad = true;

  String? selectedDefect;
  final Map<String, String> defectTypes = {
    'Disallineamento': 'Disallineamento',
    'Mancanza': 'Mancanza Ribbon',
    'Generali': 'Generali',
    'Saldatura': 'Saldatura',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ricerca Dati'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cerca ID Modulo o Utente...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Filter Chips for Stations
            Wrap(
              spacing: 10,
              children: stations.map((station) {
                return FilterChip(
                  label: Text(station),
                  selected: selectedStations.contains(station),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedStations.add(station);
                      } else {
                        selectedStations.remove(station);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Date Range Picker
            ListTile(
              title: const Text("Intervallo date"),
              subtitle: Text(
                _selectedRange == null
                    ? 'Seleziona date'
                    : '${DateFormat('dd MMM y').format(_selectedRange!.start)} → ${DateFormat('dd MMM y').format(_selectedRange!.end)}',
              ),
              trailing: const Icon(Icons.date_range),
              onTap: () async {
                final today = DateTime.now();
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(today.year - 1),
                  lastDate: today,
                );

                if (picked != null) {
                  setState(() => _selectedRange = picked);
                }
              },
            ),
            const SizedBox(height: 20),

            // Good/Bad Filter Toggles
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text("Mostra solo:"),
                Switch(
                  value: showGood,
                  onChanged: (value) {
                    setState(() {
                      showGood = value;
                    });
                  },
                  activeTrackColor: Colors.green,
                  activeColor: Colors.greenAccent,
                ),
                Text("Buoni"),
                Switch(
                  value: showBad,
                  onChanged: (value) {
                    setState(() {
                      showBad = value;
                    });
                  },
                  activeTrackColor: Colors.red,
                  activeColor: Colors.redAccent,
                ),
                Text("Scarti"),
              ],
            ),
            const SizedBox(height: 20),

            // Defect Type Selector
            DropdownButton<String>(
              value: selectedDefect,
              hint: const Text('Seleziona Tipo Difetto'),
              items: defectTypes.entries
                  .map((entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedDefect = value;
                });
              },
            ),
            const SizedBox(height: 20),

            // Search Button
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('Cerca'),
                onPressed: () {
                  _performSearch();
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Placeholder for results
            const Text(
              'Risultati della Ricerca:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Show the results (to be updated with actual API results)
            _buildSearchResults(),
          ],
        ),
      ),
    );
  }

  void _performSearch() async {
    final queryParams = {
      'date': _selectedRange != null
          ? DateFormat('yyyy-MM-dd').format(_selectedRange!.start)
          : null,
      'from_date': _selectedRange != null
          ? DateFormat('yyyy-MM-dd').format(_selectedRange!.start)
          : null,
      'to_date': _selectedRange != null
          ? DateFormat('yyyy-MM-dd').format(_selectedRange!.end)
          : null,
      'stations': selectedStations.join(','),
      'showGood': showGood ? 'true' : 'false',
      'showBad': showBad ? 'true' : 'false',
      'defect': selectedDefect,
      'search_query': _searchController.text,
    };

    final response = await http.get(
      Uri.http(
        '192.168.0.10:8000',
        '/api/productions_search',
        queryParams,
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        // Update results (you should modify this part to display actual data)
      });
    } else {
      // Handle errors
      print('Errore durante la ricerca');
    }
  }

  Widget _buildSearchResults() {
    // Display results here (mock example for now)
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.memory, color: Colors.blueGrey),
            title: const Text('Modulo ID: ABC123'),
            subtitle: const Text('Utente: Mario Rossi - Station: M308'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.memory, color: Colors.blueGrey),
            title: const Text('Modulo ID: XYZ789'),
            subtitle: const Text('Utente: Luca Bianchi - Station: M326'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}
