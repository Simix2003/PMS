import 'package:flutter/material.dart';

class DataViewPage extends StatelessWidget {
  const DataViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Grafici & Analisi')),
      body: const Center(
          child: Text('Qui ci saranno i grafici e report dei dati')),
    );
  }
}
