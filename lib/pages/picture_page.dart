// ignore_for_file: camel_case_types

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:simple_web_camera/simple_web_camera.dart';

class takePicturePage extends StatefulWidget {
  // ignore: use_super_parameters
  const takePicturePage({Key? key}) : super(key: key);

  @override
  State<takePicturePage> createState() => _HomePageState();
}

class _HomePageState extends State<takePicturePage> {
  String result = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () async {
                var res = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SimpleWebCameraPage(
                        appBarTitle: "Take a Picture", centerTitle: true),
                  ),
                );
                setState(() {
                  if (res is String) {
                    result = res;
                  }
                });
              },
              child: const Text("Take a picture"),
            ),
            const SizedBox(height: 16),
            const Text("Picture taken:"),
            if (result.isNotEmpty)
              Center(
                child: SizedBox(
                  child: Image.memory(
                    base64Decode(result),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
