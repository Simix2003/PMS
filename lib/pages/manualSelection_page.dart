import 'package:flutter/material.dart';

import 'pdf_manual_page.dart';

class ManualSelectionPage extends StatelessWidget {
  const ManualSelectionPage({super.key});

  void _openManual(BuildContext context, String fileName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManualePage(pdfFileName: fileName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manuali e Istruzioni")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ElevatedButton(
            onPressed: () => _openManual(context, 'WorkInstructionQG2.pdf'),
            child: const Text("📘 Work Instruction QG2"),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _openManual(context, 'WorkInstructionReWork.pdf'),
            child: const Text("🔧 Work Instruction ReWork"),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _openManual(context, 'Manuale.pdf'),
            child: const Text("📖 Manuale PMS"),
          ),
        ],
      ),
    );
  }
}
