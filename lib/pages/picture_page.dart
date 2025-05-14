// ignore_for_file: camel_case_types, use_build_context_synchronously

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:simple_web_camera/simple_web_camera.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class TakePicturePage extends StatefulWidget {
  const TakePicturePage({super.key});

  @override
  State<TakePicturePage> createState() => _TakePicturePageState();
}

class _TakePicturePageState extends State<TakePicturePage>
    with SingleTickerProviderStateMixin {
  String result = '';
  bool hasTakenPicture = false;
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // Open camera as soon as the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openCamera();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<String> compressBase64Image(String base64) async {
    Uint8List decoded = base64Decode(base64);

    final compressed = await FlutterImageCompress.compressWithList(
      decoded,
      minWidth: 1280,
      minHeight: 960,
      quality: 70,
      format: CompressFormat.jpeg,
      keepExif: false,
    );

    return base64Encode(compressed);
  }

  void openCamera() async {
    setState(() {
      isLoading = true;
    });

    try {
      var res = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SimpleWebCameraPage(
            appBarTitle: "Scatta una foto al difetto",
            centerTitle: true,
          ),
        ),
      );

      if (res is String && mounted) {
        setState(() {
          result = res;
          hasTakenPicture = true;
          isLoading = false;
        });
        _animationController.forward();
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void retakePicture() {
    _animationController.reverse().then((_) {
      setState(() {
        result = '';
        hasTakenPicture = false;
      });
      openCamera();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Scatta una Foto",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: isLoading
              ? _buildLoadingView()
              : hasTakenPicture
                  ? _buildImagePreviewView()
                  : _buildCameraPromptView(),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const CircularProgressIndicator(
            color: Color(0xFFE94560),
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          "Preparazione fotocamera...",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreviewView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.memory(
                base64Decode(result),
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 24),
              _buildActionButton(
                icon: Icons.refresh,
                label: "Riscatta",
                color: const Color(0xFFE94560),
                onPressed: retakePicture,
              ),
              const SizedBox(width: 16),
              _buildActionButton(
                icon: Icons.check,
                label: "Conferma",
                color: const Color(0xFF4CAF50),
                onPressed: () async {
                  final compressed = await compressBase64Image(result);
                  Navigator.pop(context, compressed);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPromptView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(75),
          ),
          child: const Icon(
            Icons.camera_alt_rounded,
            size: 80,
            color: Color(0xFFE94560),
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          "Nessuna foto scattata",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Premi il pulsante qui sotto per scattare una foto del difetto",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 40),
        _buildActionButton(
          icon: Icons.camera_alt,
          label: "Scatta Foto",
          color: Colors.green,
          onPressed: openCamera,
          isLarge: true,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isLarge = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: isLarge ? 16 : 14,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(
          horizontal: isLarge ? 32 : 20,
          vertical: isLarge ? 16 : 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isLarge ? 16 : 12),
        ),
        elevation: 5,
      ),
    );
  }
}
