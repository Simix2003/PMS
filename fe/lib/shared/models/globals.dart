// globals.dart
import 'package:flutter/material.dart';

String? selectedLine;
List<String> availableLines = [];
Map<String, String> lineDisplayNames = {};
List<String> lineOptions = [];
List<String> availableStations = [];
ValueNotifier<List<Map<String, dynamic>>> escalations = ValueNotifier([]);
