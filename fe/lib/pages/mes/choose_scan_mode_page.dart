import 'package:flutter/material.dart';
import 'single_module_page.dart';
import 'trolley_page.dart';

class ChooseScanModePage extends StatelessWidget {
  const ChooseScanModePage({super.key});

  @override
  Widget build(BuildContext context) {
    final String _userName = "Simone Paparo";
    const primaryColor = Colors.blue;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FB),
      body: Stack(
        children: [
          // Top-right user info
          Positioned(
            top: 30,
            right: 40,
            child: Row(
              children: [
                const Icon(Icons.account_circle, size: 34, color: Colors.grey),
                const SizedBox(width: 16),
                Text(
                  _userName,
                  style: const TextStyle(fontSize: 24),
                ),
              ],
            ),
          ),

          // Main content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    /// Titolo
                    const Text(
                      'Seleziona Modalità',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    /// Modulo Singolo
                    SizedBox(
                      width: double.infinity,
                      height: 80,
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.qr_code,
                          size: 36,
                          color: primaryColor,
                        ),
                        label: const Text(
                          'Modulo Singolo',
                          style: TextStyle(fontSize: 22),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryColor,
                          side: const BorderSide(color: primaryColor, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SingleModulePage()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    /// Trolley
                    SizedBox(
                      width: double.infinity,
                      height: 80,
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.trolley,
                          size: 36,
                          color: primaryColor,
                        ),
                        label: const Text(
                          'Trolley',
                          style: TextStyle(fontSize: 22),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryColor,
                          side: const BorderSide(color: primaryColor, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TrolleyPage()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
