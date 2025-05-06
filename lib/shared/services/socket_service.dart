// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
//import '../utils/constants.dart';
import 'dart:html' as html;

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

  // ----------------- CLOSE -----------------
  void close() {
    isConnected = false;
    _channel?.sink.close();
    _channel = null;
  }
}
