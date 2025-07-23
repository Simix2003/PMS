// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
//import '../utils/constants.dart';
import 'dart:html' as html;
import '../models/globals.dart';

class WebSocketService {
  static String get baseUrl {
    final uri = html.window.location;
    final host = uri.hostname;
    final isSecure = uri.protocol == 'https:';

    final wsProtocol = isSecure ? 'wss' : 'ws';
    final effectivePort = (host == 'localhost') ? '8001' : uri.port;

    return '$wsProtocol://$host:$effectivePort';
  }

  WebSocketChannel? _channel;
  bool isConnected = false;

  void _handleStream({
    required Stream stream,
    required void Function(dynamic message) onMessage,
    void Function()? onDone,
    void Function(dynamic error)? onError,
  }) {
    isConnected = true;

    stream.listen(
      (message) => onMessage(message),
      onDone: () {
        isConnected = false;
        if (onDone != null) onDone();
      },
      onError: (error) {
        isConnected = false;
        if (onError != null) onError(error);
      },
      cancelOnError: true,
    );
  }

  // ----------------- GENERIC CONNECT -----------------
  void connect({
    required String line,
    required String channel,
    required void Function(Map<String, dynamic>) onMessage,
    void Function()? onDone,
    void Function(dynamic)? onError,
  }) {
    close();

    final uri = Uri.parse('$baseUrl/ws/$line/$channel');
    _channel = WebSocketChannel.connect(uri);

    _handleStream(
      stream: _channel!.stream,
      onMessage: (msg) => onMessage(jsonDecode(msg)),
      onDone: onDone,
      onError: onError,
    );
  }

  // ----------------- SUMMARY -----------------
  void connectToSummary({
    required String selectedLine,
    required void Function() onMessage,
    void Function()? onDone,
    void Function(dynamic)? onError,
  }) {
    close();

    _channel = WebSocketChannel.connect(
      Uri.parse('$baseUrl/ws/summary/$selectedLine'),
    );

    _handleStream(
      stream: _channel!.stream,
      onMessage: (_) => onMessage(),
      onDone: onDone,
      onError: onError,
    );
  }

  // ----------------- STRINGATRICE WARNINGS -----------------
  void connectToStringatriceWarnings({
    required String line,
    required void Function(Map<String, dynamic>) onMessage,
    void Function()? onDone,
    void Function(dynamic)? onError,
  }) {
    close();

    final uri = Uri.parse('$baseUrl/ws/warnings/$line');
    _channel = WebSocketChannel.connect(uri);

    _handleStream(
      stream: _channel!.stream,
      onMessage: (msg) => onMessage(jsonDecode(msg)),
      onDone: onDone,
      onError: onError,
    );
  }

  // ----------------- VISUAL MONITORING -----------------
  void connectToVisual({
    required String line,
    required String zone,
    required void Function(Map<String, dynamic>) onMessage,
    void Function()? onDone,
    void Function(dynamic)? onError,
  }) {
    close();

    final uri = Uri.parse('$baseUrl/ws/visual/$line/$zone');
    _channel = WebSocketChannel.connect(uri);

    _handleStream(
      stream: _channel!.stream,
      onMessage: (msg) => onMessage(jsonDecode(msg)),
      onDone: onDone,
      onError: onError,
    );
  }

  // ----------------- ESCALATIONS -----------------
  void connectToEscalations({
    void Function()? onDone,
    void Function(dynamic)? onError,
  }) {
    close();

    final uri = Uri.parse('$baseUrl/ws/escalations');
    _channel = WebSocketChannel.connect(uri);

    _handleStream(
      stream: _channel!.stream,
      onMessage: (msg) {
        final data = jsonDecode(msg);
        if (data is Map && data['type'] == 'escalation_update') {
          final payload = data['payload'];
          if (payload is List) {
            escalations.value =
                List<Map<String, dynamic>>.from(payload);
          }
        }
      },
      onDone: onDone,
      onError: onError,
    );
  }

  // ----------------- EXPORT PROGRESS -----------------
  void connectToExportProgress({
    required String progressId,
    required void Function(Map<String, dynamic>) onMessage,
    void Function()? onDone,
    void Function(dynamic)? onError,
  }) {
    close();

    final uri = Uri.parse('$baseUrl/ws/export/$progressId');
    _channel = WebSocketChannel.connect(uri);

    _handleStream(
      stream: _channel!.stream,
      onMessage: (msg) => onMessage(jsonDecode(msg)),
      onDone: onDone,
      onError: onError,
    );
  }

  // ----------------- SIMIX RCA -----------------
  void connectToSimixRca({
    required String context,
    required List<Map<String, String>> chain,
    required void Function(String) onToken,
    void Function()? onDone,
    void Function(dynamic)? onError,
  }) {
    close();
    final uri = Uri.parse('$baseUrl/ws/simix_rca');
    print("🔌 Connecting to WebSocket: $uri");

    try {
      _channel = WebSocketChannel.connect(uri);
      print("✅ WebSocket connected");

      // Send initial payload
      final payload = jsonEncode({'context': context, 'why_chain': chain});
      print("📤 Sending payload: $payload");
      _channel!.sink.add(payload);

      _handleStream(
        stream: _channel!.stream,
        onMessage: (msg) {
          String text;
          if (msg is String) {
            text = msg;
          } else if (msg is List<int>) {
            text = utf8.decode(msg);
          } else {
            text = msg.toString();
          }
          print("📥 Raw message received: '$text'");
          onToken(text);
        },
        onDone: () {
          print("🔒 WebSocket closed by server");
          onDone?.call();
        },
        onError: (err) {
          print("❗ WebSocket stream error: $err");
          onError?.call(err);
        },
      );
    } catch (e) {
      print("❌ Failed to connect WebSocket: $e");
      onError?.call(e);
    }
  }

  // ----------------- CLOSE -----------------
  void close() {
    isConnected = false;
    _channel?.sink.close();
    _channel = null;
  }
}
