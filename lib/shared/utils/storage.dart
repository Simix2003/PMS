import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:localstorage/localstorage.dart';

class StorageService {
  static const String _issuesKey = 'issues';
  static final LocalStorage _localStorage = initLocalStorage() as LocalStorage;

  // Save issues (static method)
  static Future<void> saveIssues(List<Map<String, String>> issues) async {
    final String encoded =
        jsonEncode(issues); // Ensure 'issues' is properly encoded to a String

    if (kIsWeb) {
      _localStorage.setItem(_issuesKey, encoded);
    }
  }

  // Load issues (static method)
  static Future<List<Map<String, String>>> loadIssues() async {
    String? raw;
    if (kIsWeb) {
      raw = await _localStorage.getItem(_issuesKey);
    }

    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      return List<Map<String, String>>.from(
        decoded.map((e) => Map<String, String>.from(e)),
      );
    } catch (e) {
      print('Error decoding issues: $e');
      return [];
    }
  }

  // Clear issues (static method)
  static Future<void> clearIssues() async {
    if (kIsWeb) {
      _localStorage.removeItem(_issuesKey);
    }
  }
}
