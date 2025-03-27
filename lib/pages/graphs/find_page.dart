// lib/pages/find_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

            // Filter Chips
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
            const SizedBox(height: 30),

            // Search Button
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('Cerca'),
                onPressed: () {
                  // Fake search action
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

            const SizedBox(height: 20),

            const Center(
              child: Text(
                'Fai una ricerca per vedere più risultati...',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
