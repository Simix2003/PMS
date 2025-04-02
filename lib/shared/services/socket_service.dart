import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import '../utils/constants.dart';

class WebSocketService {
  static String baseUrl = 'ws://$ipAddress:$port';
  WebSocketChannel? _channel;
  Function(Map<String, dynamic>)? onMessage;
  Function? onError;
  Function? onDone;

  void connect({
    required String line,
    required String channel,
    required void Function(Map<String, dynamic> decodedMessage) onMessage,
    void Function()? onDone,
    void Function(dynamic error)? onError,
  }) {
    _channel?.sink.close();

    final uri = Uri.parse('$baseUrl/ws/$line/$channel');
    _channel = WebSocketChannel.connect(uri);

    this.onMessage = onMessage;
    this.onDone = onDone;
    this.onError = onError;

    _channel!.stream.listen(
      (message) {
        final decoded = jsonDecode(message);
        onMessage(decoded);
      },
      onDone: onDone,
      onError: onError,
    );
  }

  void connectToSummary({
    required String selectedLine,
    required void Function() onMessage,
    void Function()? onDone,
    void Function(dynamic)? onError,
  }) {
    _channel?.sink.close();
    _channel = WebSocketChannel.connect(
      Uri.parse('$baseUrl/ws/summary/$selectedLine'),
    );

    _channel!.stream.listen(
      (_) => onMessage(),
      onDone: onDone,
      onError: onError,
    );
  }

  void close() {
    _channel?.sink.close();
  }

  bool isConnected() => _channel != null;
}
