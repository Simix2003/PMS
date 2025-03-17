import 'package:flutter/material.dart';

class ObjectDetailsPage extends StatefulWidget {
  const ObjectDetailsPage({super.key});

  @override
  State<ObjectDetailsPage> createState() => _ObjectDetailsPageState();
}

class _ObjectDetailsPageState extends State<ObjectDetailsPage> {
  final TextEditingController _controller = TextEditingController();
  String searchQuery = '';

  // Dummy KO objects list
  final List<Map<String, dynamic>> koObjects = [
    {
      'objectNumber': 'OBJ-00123',
      'issues': ['Superficie danneggiata', 'Colore non conforme']
    },
    {
      'objectNumber': 'OBJ-00456',
      'issues': ['Dimensioni errate']
    },
    {
      'objectNumber': 'OBJ-00789',
      'issues': ['Problemi di assemblaggio', 'Componente mancante']
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredObjects = koObjects.where((obj) {
      return obj['objectNumber']
          .toString()
          .toLowerCase()
          .contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Dettagli Oggetto')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Inserisci numero oggetto...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      searchQuery = _controller.text;
                    });
                  },
                ),
              ),
              onSubmitted: (val) {
                setState(() {
                  searchQuery = val;
                });
              },
            ),
            const SizedBox(height: 24),
            Expanded(
              child: filteredObjects.isEmpty
                  ? const Center(
                      child: Text(
                        'Nessun oggetto trovato.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredObjects.length,
                      itemBuilder: (context, index) {
                        final obj = filteredObjects[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text(obj['objectNumber']),
                            subtitle: Text(
                                '${obj['issues'].length} problemi rilevati'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () => _showIssuesDialog(obj),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showIssuesDialog(Map<String, dynamic> obj) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Problemi per ${obj['objectNumber']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...obj['issues'].map<Widget>((issue) => ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: Text(issue),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }
}
