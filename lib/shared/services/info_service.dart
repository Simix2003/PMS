import 'dart:convert';
import 'package:flutter/services.dart';

class DefectInfoService {
  static Map<String, dynamic>? _cache;

  static Future<Map<String, dynamic>> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/defect_info.json');
    _cache = jsonDecode(raw) as Map<String, dynamic>;
    return _cache!;
  }

  static Future<Map<String, String>?> get(String key) async {
    final data = await load();
    final node = data[key];
    if (node == null) return null;
    return {
      'description': node['description'] ?? '',
      'image': node['image'] ?? '',
    };
  }
}
