import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pages/dashboard/dashboard_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('it_IT');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('Building MyApp');
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'IX-Monitor Home',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: DashboardHome());
  }
}
