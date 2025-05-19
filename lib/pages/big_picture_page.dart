import 'package:flutter/material.dart';
import 'package:ix_monitor/shared/utils/helpers.dart';

class FullImagePage extends StatelessWidget {
  final String image;
  final String defect;

  const FullImagePage({super.key, required this.image, required this.defect});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Zoomable image
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 1,
                maxScale: 5,
                child: Image.memory(
                  decodeImage(image),
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Back button (top-left)
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
