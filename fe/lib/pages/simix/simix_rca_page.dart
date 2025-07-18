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
  String? _summary;
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
      print("📨 Added to chain: $_chain");
    }
    _summary = null;
    final ctx = _contextController.text.trim();
    if (ctx.isEmpty) {
      print("⚠️ Context is empty, skipping request");
      return;
    }
    print(
        "🔗 Connecting to RCA WebSocket with context: '$ctx' and chain length: ${_chain.length}");

    setState(() {
      _loading = true;
      _buffer = '';
    });
    _startTimer();

    _ws.connectToSimixRca(
      context: ctx,
      chain: _chain,
      onToken: (token) {
        print("📩 Received token: '$token'");

        if (token == '[[END]]') {
          print("🏁 End of stream. Final displayed buffer: $_buffer");
          _stopTimer();
          _ws.close();
        } else if (token.startsWith('[[JSON]]')) {
          final cleanJson = token.replaceFirst('[[JSON]]', '');
          print("🗂 Extracted JSON: $cleanJson");
          try {
            final data = jsonDecode(cleanJson);
            setState(() {
              if (data.containsKey('summary')) {
                _summary = data['summary'] as String?;
                _question = null;
                _suggestions = [];
              } else {
                _question = data['question'] as String?;
                _suggestions = List<String>.from(data['suggestions'] ?? []);
              }
              _answerController.clear();
              _buffer = ''; // Clear the typing buffer
              _loading = false; // <<< EXIT loading state NOW
            });
          } catch (e) {
            print("❌ Failed to parse final JSON: $e");
            setState(() {
              _question = 'Errore nel parsing della risposta';
              _suggestions = [];
              _buffer = '';
              _loading = false; // <<< Also exit loading on error
            });
          }
        } else {
          // Show the streaming text as it comes
          setState(() {
            _buffer += token;
          });
        }
      },
      onError: (err) {
        print("❗ WebSocket error: $err");
        setState(() => _loading = false);
        _stopTimer();
      },
    );
  }

  Widget _buildBody() {
    // Show loading screen regardless of question state
    if (_loading) {
      return Center(
        child: Text(
          _buffer.isNotEmpty
              ? _buffer // Live stream text
              : 'Simix sta pensando${'.' * _dotCount}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
      );
    }

    // Show final summary if present
    if (_summary != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Riassunto 5 Why',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Text(
            _summary!,
            style: const TextStyle(fontSize: 18),
          ),
        ],
      );
    }

    // If no question yet, show context input
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

    // Otherwise, show question + suggestions
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
