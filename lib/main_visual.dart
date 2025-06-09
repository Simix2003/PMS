// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'pages/loading_Screen/loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT');

  // 🌍 Get the first segment of the path to determine the zone
  final uri = html.window.location;
  final pathSegments = uri.pathname!.split('/')..removeWhere((e) => e.isEmpty);
  final zone = pathSegments.isNotEmpty ? pathSegments.first : 'AIN';

  runApp(MyApp(zone: zone));
}

class MyApp extends StatelessWidget {
  final String zone;

  const MyApp({super.key, required this.zone});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PMS',

      locale: const Locale('it', 'IT'),
      supportedLocales: const [Locale('it', 'IT')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),

      // 🎯 Pass the zone to your first screen
      home: LoadingScreen(targetPage: 'Visual', zone: zone),
    );
  }
}
