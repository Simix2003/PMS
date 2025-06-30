import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

Color getStatusColor(int? esito) {
  if (esito == 1 || esito == 5) return const Color(0xFF34C759);
  if (esito == 2) return Colors.grey;
  if (esito == 4) return const Color(0xFF8E6E00); // Dark Mustard / Olive
  if (esito == 6) return const Color(0xFFFF3B30);
  if (esito == 7) return const Color(0xFFFF9500);
  if (esito == 10) return Colors.blue;
  return Colors.blueGrey;
}

String getStatusLabel(int? esito) {
  switch (esito) {
    case 1:
      return 'G';
    case 2:
      return 'In Produzione';
    case 4:
      return 'Escluso';
    case 5:
      return 'G Operatore';
    case 6:
      return 'NG';
    case 7:
      return 'NC';
    case 10:
      return 'MBJ';
    default:
      return 'N/A';
  }
}

Uint8List decodeImage(String data) {
  if (data.startsWith('data:image')) {
    return base64Decode(data.split(',').last);
  }
  return base64Decode(data);
}

// Helper methods for confidence indicator
Color getConfidenceColor(double confidence) {
  if (confidence >= 0.8) return Colors.green;
  if (confidence >= 0.6) return Colors.orange;
  return Colors.red;
}

IconData getConfidenceIcon(double confidence) {
  if (confidence >= 0.8) return Icons.check_circle_outline;
  if (confidence >= 0.6) return Icons.info_outline;
  return Icons.warning_amber_outlined;
}
