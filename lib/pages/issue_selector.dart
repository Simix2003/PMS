// ignore_for_file: library_private_types_in_public_api, prefer_interpolation_to_compose_strings

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class IssueSelectorPage extends StatefulWidget {
  final String channelId;
  final Function(String fullPath) onIssueSelected;

  const IssueSelectorPage(
      {super.key, required this.channelId, required this.onIssueSelected});

  @override
  _IssueSelectorPageState createState() => _IssueSelectorPageState();
}

class _IssueSelectorPageState extends State<IssueSelectorPage> {
  List<String> pathStack = ["Dati.Esito.Esito_Scarto.Difetti"];
  List<dynamic> currentItems = [];

  @override
  void initState() {
    super.initState();
    _fetchCurrentPath();
  }

  Future<void> _fetchCurrentPath() async {
    final currentPath = pathStack.join(".");
    final url = Uri.parse(
        'http://192.168.1.132:8000/api/issues/${widget.channelId}?path=$currentPath');
    final response = await http.get(url);

    print('Response: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Data: $data');
      setState(() {
        currentItems = data['items'];
      });
    } else {
      print("Failed to fetch: ${response.body}");
    }
  }

  void _goDeeper(String folderName) {
    setState(() {
      pathStack.add(folderName);
    });
    _fetchCurrentPath();
  }

  void _goBack() {
    if (pathStack.length > 1) {
      setState(() {
        pathStack.removeLast();
      });
      _fetchCurrentPath();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = pathStack.join(".");
    return Scaffold(
      appBar: AppBar(
        title: Text("Sfoglia Difetti"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
      ),
      body: ListView.builder(
        itemCount: currentItems.length,
        itemBuilder: (context, index) {
          final item = currentItems[index];
          return ListTile(
            title: Text(item['name']),
            leading: Icon(
              item['type'] == 'item' ? Icons.folder : Icons.bug_report,
            ),
            onTap: () {
              if (item['type'] == 'item') {
                // Treat as folder
                _goDeeper(item['name']);
              } else {
                final fullPath = "$currentPath." + item['name'];
                widget.onIssueSelected(fullPath);
                Navigator.pop(context);
              }
            },
          );
        },
      ),
    );
  }
}
