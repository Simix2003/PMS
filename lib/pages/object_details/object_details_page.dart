import 'package:flutter/material.dart';

class ObjectDetailsPage extends StatelessWidget {
  const ObjectDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dettagli Oggetto')),
      body: const Center(
          child:
              Text('Qui potrai cercare un oggetto e vedere i suoi problemi')),
    );
  }
}
