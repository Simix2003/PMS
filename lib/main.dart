import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'pages/dashboard/dashboard.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await SimpleSecureStorage.initialize(WebInitializationOptions(
      keyPassword: 'S3cur3Master36!2025',
      encryptionSalt: 'IXMonitorSalt123!',
    ));
  } else {
    await SimpleSecureStorage.initialize();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IX-Monitor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const Dashboard(),
    );
  }
}
