import 'package:flutter/material.dart';

Color getStatusColor(int? esito) {
  if (esito == 1 || esito == 5) return Colors.green;
  if (esito == 2) return Colors.grey;
  if (esito == 4) return Colors.amber;
  if (esito == 6) return Colors.red;
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
    default:
      return 'N/A';
  }
}
