import 'dart:convert';
import 'package:simple_secure_storage/simple_secure_storage.dart';

class StorageService {
  static const String _issuesKey = 'issues';

  static Future<void> saveIssues(List<Map<String, String>> issues) async {
    final encoded = jsonEncode(issues);
    await SimpleSecureStorage.write(_issuesKey, encoded);
  }

  static Future<List<Map<String, String>>> loadIssues() async {
    final raw = await SimpleSecureStorage.read(_issuesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      List<dynamic> decoded = jsonDecode(raw);
      return List<Map<String, String>>.from(
        decoded.map((e) => Map<String, String>.from(e)),
      );
    } catch (e) {
      return [];
    }
  }

  static Future<void> clearIssues() async {
    await SimpleSecureStorage.delete(_issuesKey);
  }
}
