// lib/pages/find_page.dart
import 'package:flutter/material.dart';

class FindPage extends StatelessWidget {
  const FindPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cerca'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: Text(
          'Questa è la pagina di ricerca',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
