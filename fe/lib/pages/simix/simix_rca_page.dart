import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/services/socket_service.dart';

class SimixRcaPage extends StatefulWidget {
  const SimixRcaPage({super.key});

  @override
  State<SimixRcaPage> createState() => _SimixRcaPageState();
}

class _SimixRcaPageState extends State<SimixRcaPage> {
  final TextEditingController _contextController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final WebSocketService _ws = WebSocketService();

  String? _question;
  List<String> _suggestions = [];
  final List<Map<String, String>> _chain = [];
  bool _loading = false;
  String _buffer = '';
  int _dotCount = 0;
  Timer? _timer;

  void _startTimer() {
    _timer?.cancel();
    _dotCount = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      setState(() {
        _dotCount = (_dotCount + 1) % 4;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _dotCount = 0;
  }

  Future<void> _askNext([String? answer]) async {
    if (answer != null && _question != null) {
      _chain.add({'q': _question!, 'a': answer});
    }
    final ctx = _contextController.text.trim();
    if (ctx.isEmpty) return;
    setState(() {
      _loading = true;
      _buffer = '';
    });
    _startTimer();
    _ws.connectToSimixRca(
      context: ctx,
      chain: _chain,
      onToken: (token) {
        if (token == '[[END]]') {
          try {
            final data = jsonDecode(_buffer);
            setState(() {
              _question = data['question'] as String?;
              _suggestions = List<String>.from(data['suggestions'] ?? []);
              _answerController.clear();
              _loading = false;
            });
          } catch (_) {
            setState(() {
              _loading = false;
            });
          }
          _stopTimer();
          _ws.close();
        } else {
          setState(() {
            _buffer += token;
          });
        }
      },
      onError: (_) {
        setState(() {
          _loading = false;
        });
        _stopTimer();
      },
    );
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
    if (_loading) {
      return Center(
        child: Text(
          'Simix sta pensando${'.' * _dotCount}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
      );
    }

    return Column(
      children: [
        Text(
          _question!,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: _suggestions
              .map((s) => ElevatedButton(
                    onPressed: () => _askNext(s),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12)),
                    child: Text(s),
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
          style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
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

  @override
  void dispose() {
    _ws.close();
    _stopTimer();
    super.dispose();
  }
}
