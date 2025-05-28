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

  Widget _buildManualCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required String pdfFile,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openManual(context, pdfFile),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withOpacity(0.2),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manuali e Istruzioni")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildManualCard(
            context: context,
            title: "Work Instruction QG2",
            description: "Guida operativa per il controllo qualità in QG2.",
            icon: Icons.menu_book_outlined,
            pdfFile: 'WorkInstructionQG2.pdf',
            color: Colors.blue,
          ),
          _buildManualCard(
            context: context,
            title: "Work Instruction ReWork",
            description: "Procedura per la gestione dei pezzi KO nel ReWork.",
            icon: Icons.build_circle_outlined,
            pdfFile: 'WorkInstructionReWork.pdf',
            color: Colors.orange,
          ),
          _buildManualCard(
            context: context,
            title: "Manuale PMS",
            description: "Manuale completo per l’utilizzo del sistema PMS.",
            icon: Icons.description_outlined,
            pdfFile: 'Manuale.pdf',
            color: Colors.green,
          ),
        ],
      ),
    );
  }
}
