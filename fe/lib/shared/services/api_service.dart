// lib/shared/services/api_service.dart
// ignore_for_file: non_constant_identifier_names, avoid_print
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/globals.dart';
import 'socket_service.dart';

class ApiService {
  static String get baseUrl {
    final uri = html.window.location;
    final host = uri.hostname;
    final isSecure = uri.protocol == 'https:';

    final httpProtocol = isSecure ? 'https' : 'http';

    final effectivePort = (host == 'localhost') ? '8001' : uri.port;

    return '$httpProtocol://$host:$effectivePort';
  }

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
    required List<Map<String, dynamic>> issues,
  }) async {
    final payload = {
      'line_name': selectedLine,
      'channel_id': selectedChannel,
      'object_id': objectId,
      'issues': issues,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/api/set_issues'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      // Try to extract the error message
      String errorMessage = 'Errore durante l’invio.';
      try {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body.containsKey('error')) {
          errorMessage = body['error'];
        }
      } catch (_) {
        // If parsing fails, use raw body
        errorMessage = response.body;
      }

      // Let the caller (e.g. _submitIssues) handle the message
      throw Exception(errorMessage);
    }
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
    DateTime? startTime,
    DateTime? endTime,
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

    if (startTime != null && endTime != null) {
      final startStr = Uri.encodeComponent(startTime.toIso8601String());
      final endStr = Uri.encodeComponent(endTime.toIso8601String());
      url += '&start_time=$startStr&end_time=$endStr';
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

        // Ensure cycle_times is a List<num>
        if (station['cycle_times'] is List) {
          station['cycle_times'] =
              (station['cycle_times'] as List).map((e) => (e as num)).toList();
        } else {
          station['cycle_times'] = <num>[]; // fallback
        }
      }

      Map<String, dynamic> deepCastToStringKeyedMap(Map input) {
        return input.map((key, value) {
          if (value is Map) {
            return MapEntry(key.toString(), deepCastToStringKeyedMap(value));
          } else if (value is List) {
            return MapEntry(
                key.toString(),
                value.map((e) {
                  return e is Map ? deepCastToStringKeyedMap(e) : e;
                }).toList());
          } else {
            return MapEntry(key.toString(), value);
          }
        });
      }

      final cleaned = deepCastToStringKeyedMap(jsonMap as Map);
      return cleaned;
    } else {
      throw Exception('Errore durante il caricamento dei dati');
    }
  }

  static Future<Map<String, dynamic>> fetchOverlayConfig(
      String path, String lineName, String station) async {
    final uri = Uri.parse(
        '$baseUrl/api/overlay_config?path=$path&line_name=$lineName&station=$station');

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
    required String lineName,
    required String station,
  }) async {
    final uri = Uri.parse('$baseUrl/api/update_overlay_config');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "path": path,
        "rectangles": rectangles,
        "line_name": lineName,
        "station": station,
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
    String? object_id,
  }) async {
    final url = Uri.parse(
        '$baseUrl/api/overlay_config?path=$path&line_name=$line&station=$station&object_id=$object_id');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {};
    }
  }

  static Future<bool> sendObjectOutcome({
    required String lineName,
    required String channelId,
    required String objectId,
    required String outcome,
    required bool rework,
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
        "rework": rework,
      }),
    );
    return response.statusCode == 200;
  }

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static Future<String?> fetchStationForObject(String idModulo) async {
    try {
      final uri =
          Uri.parse('$baseUrl/api/station_for_object?id_modulo=$idModulo');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['station'] as String;
      } else {
        debugPrint("❌ Station not found: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ Error fetching station: $e");
      return null;
    }
  }

  static Future<String> buildOverlayImageUrl({
    required String line,
    required String station,
    required List<String> pathStack,
    required String object_id,
  }) async {
    if (pathStack.isEmpty) return "";

    String effectiveStation = station;

    // 🛠 If we are in rework, use the original QC station instead
    if (station == "RMI01") {
      final oldStation = await fetchStationForObject(object_id);
      if (oldStation != null) {
        effectiveStation = oldStation;
      } else {
        debugPrint(
            "❌ Could not resolve old QC station for object_id: $object_id");
        return "";
      }
    }

    final base = pathStack.first.toLowerCase(); // e.g., "saldatura"

    if (pathStack.length == 1) {
      return "$baseUrl/images/$line/$effectiveStation/$base.jpg";
    }

    // Special handling for stringa layers
    final last = pathStack.last;
    final match = RegExp(r'Stringa\[(\d+)\]').firstMatch(last);

    if (match != null) {
      final stringaIndex = match.group(1);
      return "$baseUrl/images/$line/$effectiveStation/${base}_stringa_$stringaIndex.jpg";
    }

    return ""; // fallback
  }

  static Future<String?> exportSelectedObjectsAndGetDownloadUrl({
    required List<String> productionIds, // <-- true production row IDs
    required List<String> moduloIds, // <-- id_modulo strings (for full history)
    required List<Map<String, String>> filters,
    required bool fullHistory,
    void Function(String step, int? current, int? total)? onProgress,
  }) async {
    final url = Uri.parse('$baseUrl/api/export_objects');

    final progressId = DateTime.now().millisecondsSinceEpoch.toString();

    StreamSubscription? sub;
    WebSocketChannel? channel;
    if (onProgress != null) {
      final wsUri =
          Uri.parse('${WebSocketService.baseUrl}/ws/export/$progressId');
      channel = WebSocketChannel.connect(wsUri);
      sub = channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            final step = data['step'];
            final current = data['current'];
            final total = data['total'];
            if (step is String) {
              onProgress(
                step,
                current is int ? current : null,
                total is int ? total : null,
              );
            }
          } catch (_) {}
        },
      );
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "modulo_ids": moduloIds,
        "production_ids": productionIds,
        "filters": filters,
        "fullHistory": fullHistory, // 👈 Include it in the request body
        "progressId": progressId,
      }),
    );

    await sub?.cancel();
    await channel?.sink.close();

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final filename = data["filename"];
      if (filename != null) {
        return "$baseUrl/api/download_export/$filename";
      }
    } else {
      print("❌ Export failed: ${response.statusCode} - ${response.body}");
    }
    return null;
  }

  static Future<String?> exportDailyAndGetDownloadUrl({
    void Function(String step, int? current, int? total)? onProgress,
  }) async {
    final url = Uri.parse('$baseUrl/api/daily_export');

    final progressId = DateTime.now().millisecondsSinceEpoch.toString();

    StreamSubscription? sub;
    WebSocketChannel? channel;
    if (onProgress != null) {
      final wsUri =
          Uri.parse('${WebSocketService.baseUrl}/ws/export/$progressId');
      channel = WebSocketChannel.connect(wsUri);
      sub = channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            final step = data['step'];
            final current = data['current'];
            final total = data['total'];
            if (step is String) {
              onProgress(
                step,
                current is int ? current : null,
                total is int ? total : null,
              );
            }
          } catch (_) {}
        },
      );
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "progressId": progressId,
      }),
    );

    await sub?.cancel();
    await channel?.sink.close();

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final filename = data["filename"];
      if (filename != null) {
        return "$baseUrl/api/download_export/$filename";
      }
    } else {
      print("❌ Daily export failed: ${response.statusCode} - ${response.body}");
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> fetchSearchResults({
    required List<Map<String, String>> filters,
    required String? orderBy,
    required String? orderDirection,
    required String? limit,
    required bool showAllEvents,
  }) async {
    final uri = Uri.parse('$baseUrl/api/search');

    // 🧼 Clean up 'Difetto' filter values
    final cleanedFilters = filters.map((f) {
      if (f['type'] == 'Difetto' && f['value'] != null) {
        final raw = f['value']!;
        final cleanedParts = raw
            .split('>')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();

        return {
          'type': f['type']!,
          'value': cleanedParts.join(' > '),
        };
      }
      return f;
    }).toList();

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "filters": cleanedFilters,
        "order_by": orderBy,
        "order_direction": orderDirection,
        "limit": limit,
        "show_all_events": showAllEvents,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data["results"] ?? []);
    } else {
      throw Exception("Errore durante la ricerca");
    }
  }

  static Future<Map<String, List<dynamic>>> fetchGraphData({
    required String line,
    required String station,
    required String start,
    required String end,
    required List<String> metrics,
    required String groupBy,
    String? extraFilter,
  }) async {
    final uri = Uri.parse('$baseUrl/api/graph_data');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "line": line,
        "station": station,
        "start": start,
        "end": end,
        "metrics": metrics,
        "groupBy": groupBy,
        if (extraFilter != null) 'extra_filter': extraFilter,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data.map((key, value) => MapEntry(
            key,
            List<dynamic>.from(value),
          ));
    } else {
      throw Exception("Errore nel caricamento del grafico");
    }
  }

  static Future<Map<String, dynamic>> fetchInitialIssuesForObject(
    String lineName,
    String channelId,
    String idModulo,
    bool write_to_plc, {
    String? productionId,
  }) async {
    try {
      final uri =
          Uri.parse('$baseUrl/api/issues/for_object').replace(queryParameters: {
        'line_name': lineName,
        'channel_id': channelId,
        'id_modulo': idModulo,
        'write_to_plc': write_to_plc.toString(),
        if (productionId != null) 'production_id': productionId,
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return {
          'issue_paths': List<String>.from(data['issue_paths'] ?? []),
          'pictures': (data['pictures'] as List<dynamic>)
              .map((e) => Map<String, String>.from(e as Map))
              .toList(),
        };
      } else {
        debugPrint("❌ Failed to fetch initial issues: ${response.statusCode}");
        return {'issue_paths': [], 'pictures': []};
      }
    } catch (e) {
      debugPrint("❌ Exception in fetchInitialIssuesForObject: $e");
      return {'issue_paths': [], 'pictures': []};
    }
  }

  static Future<Map<String, dynamic>> getAllSettings() async {
    final response = await http.get(Uri.parse('$baseUrl/api/settings'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load settings');
    }
  }

  static Future<void> setAllSettings(Map<String, dynamic> settings) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/settings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(settings),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save settings');
    }
  }

  static Future<void> refreshBackendSettings() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/settings/refresh'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to refresh settings');
    }
  }

  static Future<List<Map<String, dynamic>>> getUnacknowledgedWarnings(
      String line) async {
    final url = Uri.parse('$baseUrl/api/warnings/$line');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Errore durante il recupero degli allarmi');
    }
  }

  static Future<void> acknowledgeWarning(int warningId) async {
    final url = Uri.parse('$baseUrl/api/warnings/acknowledge/$warningId');
    final response = await http.post(url);

    if (response.statusCode != 200) {
      throw Exception('Errore durante l\'acknowledge del warning');
    }
  }

  static Future<bool> suppressWarning(String line, String timestamp) async {
    final url = Uri.parse('$baseUrl/api/suppress_warning');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'line_name': line,
        'timestamp': timestamp,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      debugPrint("❌ Failed to suppress warning: ${response.body}");
      return false;
    }
  }

  static Future<bool> suppressWarningWithPhoto(
      String lineName, String timestamp, String base64Image) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/warnings/suppress_with_photo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'line_name': lineName,
          'timestamp': timestamp,
          'photo': base64Image,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("❌ Error suppressing warning with photo: $e");
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchDataFromQuery(
      String query) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/run_sql_query'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'query': query}),
    );

    if (response.statusCode == 200) {
      final List<dynamic> raw = jsonDecode(response.body);
      return raw.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Errore nella query: ${response.body}');
    }
  }

  static Future<void> fetchLinesAndInitializeGlobals() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/lines'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> linesData = data['lines'];
        final List<String> stationsData =
            List<String>.from(data['stations'] as List<dynamic>);

        // Clear existing data
        availableLines.clear();
        lineDisplayNames.clear();
        lineOptions.clear();
        availableStations.clear();

        // Populate lines
        for (final item in linesData) {
          final name = item['name'];
          final displayName = item['display_name'];
          availableLines.add(name);
          lineDisplayNames[name] = displayName;
          lineOptions.add(displayName);
        }

        // Validate selectedLine
        if (!availableLines.contains(selectedLine)) {
          selectedLine = availableLines.isNotEmpty ? availableLines[0] : null;
        }

        stationsData.sort();
        availableStations.addAll(stationsData);
      } else {
        throw Exception('❌ Failed to load lines from server');
      }
    } catch (e) {
      debugPrint("❌ Error fetching lines: $e");
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> fetchMBJDetails(String idModulo) async {
    final response =
        await http.get(Uri.parse('$baseUrl/api/mbj_events/$idModulo'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      // XML not found (valid case)
      return null;
    } else {
      // Other errors (e.g. server down, 500, etc.)
      throw Exception('Failed to fetch MBJ details: ${response.statusCode}');
    }
  }

  static Future<bool> preloadXmlIndex() async {
    try {
      final response =
          await http.post(Uri.parse('$baseUrl/api/reload_xml_index'));

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint('❌ Failed to preload XML index: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Exception while preloading XML: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> checkDefectSimilarity(
      String userInput) async {
    final url = Uri.parse('$baseUrl/api/ml/check_defect_similarity');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'input_text': userInput}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint(
            '❌ Failed to check defect similarity: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Exception during checkDefectSimilarity: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> predictReworkETAByObject(
      String objectId) async {
    final url = Uri.parse('$baseUrl/api/ml/predict_eta_by_id_modulo');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_modulo': objectId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['confidence'] == 'high') {
          return {
            'etaInfo': {
              'eta_sec': data['eta_sec'],
              'eta_min': data['eta_min'].round(),
              'reasoning': data['reasoning'],
              'samples': data['historical_samples']
            },
            'noDefectsFound': false
          };
        } else {
          return {'etaInfo': null, 'noDefectsFound': false};
        }
      } else if (response.statusCode == 419) {
        debugPrint('ℹ️ No DEFECTS found for object_id $objectId');
        return {'etaInfo': null, 'noDefectsFound': true};
      } else {
        debugPrint('❌ Failed to get ETA by object_id: ${response.statusCode}');
        return {'etaInfo': null, 'noDefectsFound': false};
      }
    } catch (e) {
      debugPrint('❌ Exception during predictReworkETAByObject: $e');
      return {'etaInfo': null, 'noDefectsFound': false};
    }
  }

  Future<Map<String, dynamic>?> getQGStations({String? lineName}) async {
    final uri = Uri.parse('$baseUrl/api/tablet_stations').replace(
        queryParameters: lineName != null ? {'line_name': lineName} : null);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print("Failed to load stations: ${response.body}");
      return null;
    }
  }

  static Future<Map<String, dynamic>> fetchVisualDataForAin(
      {bool forceRefresh = false}) async {
    final cacheFlag = forceRefresh ? 'false' : 'true';
    final response = await http.get(
      Uri.parse('$baseUrl/api/visual_data?zone=AIN&useCache=$cacheFlag'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Fetched AIN data: $data');

      return {
        ...data,
        'station_1_in': data['station_1_in'] ?? 0,
        'station_2_in': data['station_2_in'] ?? 0,
        'station_1_out_ng': data['station_1_out_ng'] ?? 0,
        'station_2_out_ng': data['station_2_out_ng'] ?? 0,
        'station_1_yield': data['station_1_yield'] ?? 100,
        'station_2_yield': data['station_2_yield'] ?? 100,
        'station_1_yield_shifts': data['station_1_yield_shifts'] ?? [],
        'station_2_yield_shifts': data['station_2_yield_shifts'] ?? [],
        'station_1_yield_last_8h': data['station_1_yield_last_8h'] ?? [],
        'station_2_yield_last_8h': data['station_2_yield_last_8h'] ?? [],
        'shift_throughput': data['shift_throughput'] ?? [],
        'last_8h_throughput': data['last_8h_throughput'] ?? [],
        'fermi_data': data['fermi_data'] ?? [],
        'top_defects_qg2': data['top_defects_qg2'] ?? [],
        'total_defects_qg2': data['total_defects_qg2'] ?? 0,
        'top_defects_vpf': data['top_defects_vpf'] ?? [],
      };
    } else {
      throw Exception('Failed to load zone data');
    }
  }

  static Future<Map<String, dynamic>> fetchVisualDataForVpf() async {
    final response =
        await http.get(Uri.parse('$baseUrl/api/visual_data?zone=VPF'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        ...data,
        'station_1_in': data['station_1_in'] ?? 0,
        'station_1_out_ng': data['station_1_out_ng'] ?? 0,
        'station_1_re_entered': data['station_1_re_entered'] ?? 0,
        'speed_ratio': data['speed_ratio'] ?? [],
        'station_1_yield': data['station_1_yield'] ?? 100,
        'station_1_shifts': data['station_1_shifts'] ?? [],
        'station_1_yield_last_8h': data['station_1_yield_last_8h'] ?? [],
        'eq_defects': data['eq_defects'] ?? [],
        'defects_vpf': data['defects_vpf'] ?? [],
      };
    } else {
      throw Exception('Failed to load VPF zone data');
    }
  }

  static Future<Map<String, dynamic>> fetchVisualDataForEll() async {
    final response =
        await http.get(Uri.parse('$baseUrl/api/visual_data?zone=ELL'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return {
        ...data,
        'station_1_in': data['station_1_in'] ?? 0,
        'station_2_in': data['station_2_in'] ?? 0,
        'station_1_ng_qg2': data['station_1_ng_qg2'] ?? 0,
        'station_1_out_ng': data['station_1_out_ng'] ?? 0,
        'station_2_out_ng': data['station_2_out_ng'] ?? 0,
        'FPY_yield': data['FPY_yield'] ?? 100,
        'RWK_yield': data['RWK_yield'] ?? 100,
        'FPY_yield_shifts': data['FPY_yield_shifts'] ?? [],
        'RWK_yield_shifts': data['RWK_yield_shifts'] ?? [],
        'FPY_yield_last_8h': data['FPY_yield_last_8h'] ?? [],
        'RWK_yield_last_8h': data['RWK_yield_last_8h'] ?? [],
        'shift_throughput': data['shift_throughput'] ?? [],
        'last_8h_throughput': data['last_8h_throughput'] ?? [],
        'fermi_data': data['fermi_data'] ?? [],
        'top_defects': data['top_defects'] ?? [],
        'buffer_ids': data['buffer_ids'] ?? [],
        'value_gauge_1': data['value_gauge_1'] ?? 0,
        'value_gauge_2': data['value_gauge_2'] ?? 0,
      };
    } else {
      throw Exception('Failed to load ELL visual data');
    }
  }

  static Future<Map<String, dynamic>> fetchVisualDataForStr(
      {bool forceRefresh = false}) async {
    final cacheFlag = forceRefresh ? 'false' : 'true';
    final response = await http.get(
      Uri.parse('$baseUrl/api/visual_data?zone=STR&useCache=$cacheFlag'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return {
        ...data,
        // Station inputs
        'station_1_in': data['station_1_in'] ?? 0,
        'station_2_in': data['station_2_in'] ?? 0,
        'station_3_in': data['station_3_in'] ?? 0,
        'station_4_in': data['station_4_in'] ?? 0,
        'station_5_in': data['station_5_in'] ?? 0,

        // NG counts
        'station_1_out_ng': data['station_1_out_ng'] ?? 0,
        'station_2_out_ng': data['station_2_out_ng'] ?? 0,
        'station_3_out_ng': data['station_3_out_ng'] ?? 0,
        'station_4_out_ng': data['station_4_out_ng'] ?? 0,
        'station_5_out_ng': data['station_5_out_ng'] ?? 0,

        // Scrap
        'station_1_scrap': data['station_1_scrap'] ?? 0,
        'station_2_scrap': data['station_2_scrap'] ?? 0,
        'station_3_scrap': data['station_3_scrap'] ?? 0,
        'station_4_scrap': data['station_4_scrap'] ?? 0,
        'station_5_scrap': data['station_5_scrap'] ?? 0,

        // Yields (default to 100%)
        'station_1_yield': data['station_1_yield'] ?? 100,
        'station_2_yield': data['station_2_yield'] ?? 100,
        'station_3_yield': data['station_3_yield'] ?? 100,
        'station_4_yield': data['station_4_yield'] ?? 100,
        'station_5_yield': data['station_5_yield'] ?? 100,

        // Yield history (backend keys mapped)
        'str_yield_shifts': data['str_yield_shifts'] ?? [],
        'overall_yield_shifts': data['overall_yield_shifts'] ?? [],
        'str_yield_last_8h': data['str_yield_last_8h'] ?? [],
        'overall_yield_last_8h': data['overall_yield_last_8h'] ?? [],

        // Throughput, downtime, and stops
        'shift_throughput': data['shift_throughput'] ?? [],
        'fermi_data': data['fermi_data'] ?? [],

        // Defect data
        'top_defects_qg2': data['top_defects_qg2'] ?? [],
        'total_defects_qg2': data['total_defects_qg2'] ?? 0,
        'top_defects_vpf': data['top_defects_vpf'] ?? [],
      };
    } else {
      throw Exception('Failed to load STR zone data');
    }
  }

  static Future<Map<String, dynamic>> fetchVisualDataForLmn(
      {bool forceRefresh = false}) async {
    final cacheFlag = forceRefresh ? 'false' : 'true';
    final response = await http.get(
      Uri.parse('$baseUrl/api/visual_data?zone=LMN&useCache=$cacheFlag'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Fetched LMN data: $data');

      return {
        ...data,
        'station_1_in': data['station_1_in'] ?? 0,
        'station_2_in': data['station_2_in'] ?? 0,
        'station_1_out_ng': data['station_1_out_ng'] ?? 0,
        'station_2_out_ng': data['station_2_out_ng'] ?? 0,
        'station_1_yield': data['station_1_yield'] ?? 100,
        'station_2_yield': data['station_2_yield'] ?? 100,
        'station_1_yield_shifts': data['station_1_yield_shifts'] ?? [],
        'station_2_yield_shifts': data['station_2_yield_shifts'] ?? [],
        'station_1_yield_last_8h': data['station_1_yield_last_8h'] ?? [],
        'station_2_yield_last_8h': data['station_2_yield_last_8h'] ?? [],
        'shift_throughput': data['shift_throughput'] ?? [],
        'last_8h_throughput': data['last_8h_throughput'] ?? [],
        'fermi_data': data['fermi_data'] ?? [],
        'top_defects_qg2': data['top_defects_qg2'] ?? [],
        'total_defects_qg2': data['total_defects_qg2'] ?? 0,
        'top_defects_vpf': data['top_defects_vpf'] ?? [],
      };
    } else {
      throw Exception('Failed to load zone data');
    }
  }

  Future<Map<String, dynamic>?> createStop({
    required int stationId,
    required String startTime,
    required String operatorId,
    required String stopType,
    required String reason,
    required String status,
    int? linkedProductionId,
  }) async {
    final url = Uri.parse('$baseUrl/api/escalation/create_stop');

    final payload = {
      "station_id": stationId,
      "start_time": startTime,
      "operator_id": operatorId,
      "stop_type": stopType,
      "reason": reason,
      "status": status,
      if (linkedProductionId != null)
        "linked_production_id": linkedProductionId,
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print("Failed to create stop: ${response.body}");
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateStopStatus({
    required int stopId,
    required String newStatus,
    required String changedAt,
    required String operatorId,
  }) async {
    final url = Uri.parse('$baseUrl/api/escalation/update_status');

    final payload = {
      "stop_id": stopId,
      "new_status": newStatus,
      "changed_at": changedAt,
      "operator_id": operatorId,
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print("Failed to update stop status: ${response.body}");
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateStopReason({
    required int stopId,
    required String reason,
  }) async {
    final url = Uri.parse('$baseUrl/api/escalation/update_reason');

    final payload = {
      "stop_id": stopId,
      "reason": reason,
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print("Failed to update stop reason: ${response.body}");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStopDetails(int stopId) async {
    final url = Uri.parse('$baseUrl/api/escalation/get_stop_details/$stopId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print("Failed to load stop details: ${response.body}");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStopsForStation(
    int stationId, {
    int shiftsBack = 3,
    bool includeOpen = false,
  }) async {
    final url = Uri.parse(
      '$baseUrl/api/escalation/get_stops/$stationId'
      '?shifts_back=$shiftsBack&include_open=${includeOpen ? 1 : 0}',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint(
            "⚠️ Failed to load stops: ${response.statusCode} → ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ Exception in getStopsForStation: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getMachineStopsForStation(
    int stationId, {
    int shiftsBack = 3,
    bool includeOpen = false,
  }) async {
    final url = Uri.parse(
      '$baseUrl/api/stops/get_machine_stops/$stationId'
      '?shifts_back=$shiftsBack&include_open=${includeOpen ? 1 : 0}',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        print(response.body);
        return jsonDecode(response.body);
      } else {
        debugPrint(
            "⚠️ Failed to load machine stops: ${response.statusCode} → ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ Exception in getMachineStopsForStation: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> deleteStop(int stopId) async {
    final url = Uri.parse('$baseUrl/api/escalation/delete_stop/$stopId');

    final response = await http.delete(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print("Failed to delete stop: ${response.body}");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> loadVisualTargets() async {
    final url = Uri.parse('$baseUrl/api/visual_targets');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print("❌ Failed to load visual targets: ${response.body}");
      return null;
    }
  }

  static Future<bool> saveVisualTargets(
      int shiftTarget, int yieldTarget) async {
    final url = Uri.parse('$baseUrl/api/visual_targets');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'shift_target': shiftTarget,
        'yield_target': yieldTarget,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      print("❌ Failed to save visual targets: ${response.body}");
      return false;
    }
  }

  static Future<Map<String, dynamic>> fetchBufferDefectSummary({
    required String plcIp,
    required int db,
    required int byte,
    required int length,
    int stringLength = 20,
    bool debug = false,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/rwk_buffer_defects'
      '?plc_ip=$plcIp'
      '&db=$db'
      '&byte=$byte'
      '&length=$length'
      '&string_length=$stringLength'
      '&debug=$debug',
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return {
        'bufferIds': List<String>.from(data['BufferIds_Rework'] ?? []),
        'bufferDefects': List<Map<String, dynamic>>.from(
          (data['bufferDefectSummary'] ?? []).map((e) => {
                'object_id': e['object_id'] ?? '',
                'production_id': e['production_id'] ?? 0,
                'rework_count': e['rework_count'] ?? 0,
                'defects': List<Map<String, dynamic>>.from(e['defects'] ?? []),
              }),
        ),
      };
    } else {
      throw Exception('Failed to fetch buffer defect data');
    }
  }

  /// Ask Simix RCA assistant for the next question.
  static Future<Map<String, dynamic>> askSimixRca(
      String context, List<Map<String, String>> chain) async {
    final url = Uri.parse('$baseUrl/api/simix_rca/next');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'context': context, 'why_chain': chain}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Errore durante la richiesta a Simix RCA');
    }
  }
}
