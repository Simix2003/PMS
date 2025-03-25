// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';

Widget M326HomePage(context) {
  return Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Center(
          child: Icon(
            Icons.factory,
            color: Colors.orangeAccent,
            size: 80,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "M326 STATION",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "Questa è una schermata personalizzata per la M326.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: () {
            // Insert fake action here
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("M326 Action triggered")),
            );
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text("Avvia Processo"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    ),
  );
}
