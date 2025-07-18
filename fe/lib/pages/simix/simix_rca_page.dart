import 'dart:ui';
import 'package:flutter/material.dart';
import '../../shared/services/api_service.dart';

class SimixRcaPage extends StatefulWidget {
  const SimixRcaPage({super.key});

  @override
  State<SimixRcaPage> createState() => _SimixRcaPageState();
}

class _SimixRcaPageState extends State<SimixRcaPage> {
  final TextEditingController _contextController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();

  String? _question;
  List<String> _suggestions = [];
  final List<Map<String, String>> _chain = [];

  Future<void> _askNext([String? answer]) async {
    print('Called');
    if (answer != null && _question != null) {
      _chain.add({'q': _question!, 'a': answer});
    }
    final ctx = _contextController.text.trim();
    if (ctx.isEmpty) return;
    final res = await ApiService.askSimixRca(ctx, _chain);
    setState(() {
      _question = res['question'] as String?;
      _suggestions = List<String>.from(res['suggestions'] ?? []);
      _answerController.clear();
    });
  }

  Widget _buildBody() {
    if (_question == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Inserisci il contesto del problema',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _contextController,
            decoration: const InputDecoration(
              hintText: 'Es. NG2 su STR01, modulo 1234',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _askNext,
            child: const Text('Inizia analisi 5 Why'),
          )
        ],
      );
    }

    return Column(
      children: [
        Text(
          _question!,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: _suggestions
              .map((s) => ActionChip(
                    label: Text(s),
                    onPressed: () => _askNext(s),
                  ))
              .toList(),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _answerController,
          decoration: const InputDecoration(hintText: 'Scrivi la risposta...'),
          onSubmitted: (v) => _askNext(v),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => _askNext(_answerController.text.trim()),
          child: const Text('Invia'),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.6),
                  Colors.purple.withOpacity(0.4)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }
}
