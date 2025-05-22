import 'package:flutter/material.dart';
import 'package:ix_monitor/shared/services/api_service.dart';

class PreloadXmlPage extends StatefulWidget {
  const PreloadXmlPage({super.key});

  @override
  State<PreloadXmlPage> createState() => _PreloadXmlPageState();
}

class _PreloadXmlPageState extends State<PreloadXmlPage> {
  bool _loading = false;

  Future<void> _startPreload() async {
    setState(() {
      _loading = true;
    });

    try {
      final success = await ApiService.preloadXmlIndex();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Precaricamento completato con successo!'
                : 'Errore durante il precaricamento XML.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Errore di rete durante il precaricamento.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Precarica XML'),
      ),
      body: Center(
        child: _loading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Caricamento in corso...'),
                ],
              )
            : ElevatedButton.icon(
                onPressed: _startPreload,
                icon: const Icon(Icons.download_for_offline),
                label: const Text('Carica'),
              ),
      ),
    );
  }
}
