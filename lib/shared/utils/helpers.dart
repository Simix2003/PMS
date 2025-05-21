import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

Color getStatusColor(int? esito) {
  if (esito == 1 || esito == 5) return Colors.green;
  if (esito == 2) return Colors.grey;
  if (esito == 4) return Colors.amber;
  if (esito == 6) return Colors.red;
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
