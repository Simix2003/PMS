// lib/shared/services/api_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ApiService {
  static var baseUrl = "http://$ipAddress:$port";

  static Future<String> fetchPLCStatus(
      String selectedLine, String selectedChannel) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/plc_status'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data[selectedLine]?[selectedChannel] ?? "UNKNOWN";
      } else {
        return "ERROR";
      }
    } catch (_) {
      return "ERROR";
    }
  }

  static Future<bool> submitIssues({
    required String selectedLine,
    required String selectedChannel,
    required String objectId,
    required List<String> issues,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/set_issues'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'line_name': selectedLine,
        'channel_id': selectedChannel,
        'object_id': objectId,
        'issues': issues,
      }),
    );

    return response.statusCode == 200;
  }

  static Future<void> simulateTrigger(String line, String channel) async {
    await http.post(
      Uri.parse('$baseUrl/api/simulate_trigger'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"line_name": line, "channel_id": channel}),
    );
  }

  static Future<void> simulateOutcome(
      String line, String channel, String outcome) async {
    await http.post(
      Uri.parse('$baseUrl/api/simulate_outcome'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {"line_name": line, "channel_id": channel, "value": outcome}),
    );
  }

  static Future<bool> simulateObjectId(String channel, String objectId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/simulate_objectId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "channel_id": channel,
        "objectId": objectId,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> fetchProductionSummary({
    required String selectedLine,
    DateTime? singleDate,
    DateTimeRange? range,
    int selectedTurno = 0,
  }) async {
    String url;
    if (range != null) {
      final from = _formatDate(range.start);
      final to = _formatDate(range.end);
      url =
          '$baseUrl/api/productions_summary?from=$from&to=$to&line_name=$selectedLine';
    } else {
      final date = _formatDate(singleDate ?? DateTime.now());
      url =
          '$baseUrl/api/productions_summary?date=$date&line_name=$selectedLine';
    }

    if (selectedTurno != 0) {
      url += '&turno=$selectedTurno';
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final jsonMap = json.decode(response.body);
      for (var station in jsonMap['stations'].values) {
        station['last_object'] ??= 'No Data';
        station['last_esito'] ??= 'No Data';
        station['last_cycle_time'] ??= 'No Data';
        station['last_in_time'] ??= 'No Data';
        station['last_out_time'] ??= 'No Data';
      }
      return Map<String, dynamic>.from(jsonMap);
    } else {
      throw Exception('Errore durante il caricamento dei dati');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAvailableOverlayPaths() async {
    final uri = Uri.parse('$baseUrl/api/available_overlay_paths');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception("Errore nel caricamento dei path disponibili");
    }
  }

  static Future<Map<String, dynamic>> fetchOverlayConfig(String path) async {
    final uri = Uri.parse('$baseUrl/api/overlay_config?path=$path');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } else {
      throw Exception("Errore nel caricamento del config dell'overlay");
    }
  }

  static Future<bool> updateOverlayConfig({
    required String path,
    required List<Map<String, dynamic>> rectangles,
  }) async {
    final uri = Uri.parse('$baseUrl/api/update_overlay_config');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "path": path,
        "rectangles": rectangles,
      }),
    );

    return response.statusCode == 200;
  }

  static Future<List<dynamic>> fetchIssues({
    required String line,
    required String station,
    required String path,
  }) async {
    final url = Uri.parse('$baseUrl/api/issues/$line/$station?path=$path');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['items'] ?? [];
    } else {
      throw Exception("Errore nel caricamento dei difetti");
    }
  }

  static Future<Map<String, dynamic>> fetchIssueOverlay({
    required String line,
    required String station,
    required String path,
  }) async {
    final url = Uri.parse(
        '$baseUrl/api/overlay_config?path=$path&line_name=$line&station=$station');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {}; // Fallback: no overlay available
    }
  }

  static Future<bool> sendObjectOutcome({
    required String lineName,
    required String channelId,
    required String objectId,
    required String outcome, // "buona" or "scarto"
  }) async {
    final url = Uri.parse('$baseUrl/api/set_outcome');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "line_name": lineName,
        "channel_id": channelId,
        "object_id": objectId,
        "outcome": outcome,
      }),
    );
    return response.statusCode == 200;
  }

  //HELPERS
  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String buildOverlayImageUrl({
    required String line,
    required String station,
    required List<String> pathStack,
  }) {
    if (pathStack.isEmpty) return "";

    if (pathStack.length == 1) {
      final group = pathStack.first.toLowerCase();
      return "$baseUrl/images/$line/$station/$group.jpg";
    }

    final base = pathStack.first.toLowerCase();
    final sub = pathStack.last.toLowerCase().replaceAll(' ', '_');
    return "$baseUrl/images/$line/$station/${base}_$sub.jpg";
  }
}
