import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OverlayEditorPage extends StatefulWidget {
  const OverlayEditorPage({super.key});

  @override
  State<OverlayEditorPage> createState() => _OverlayEditorPageState();
}

class _OverlayEditorPageState extends State<OverlayEditorPage> {
  List<Map<String, dynamic>> availableConfigs = [];
  String? selectedPath;
  String? selectedImageUrl;
  List<Map<String, dynamic>> rectangles = [];
  bool isLoading = false;
  Offset? dragStartGlobal;
  Offset? resizeStartGlobal;
  int? activeDragIndex;
  int? activeResizeIndex;
  Size? initialResizeSize;
  final GlobalKey _imageKey = GlobalKey();
  Size? imageSize;

  Future<void> fetchAvailablePaths() async {
    final uri =
        Uri.parse('http://192.168.0.10:8000/api/available_overlay_paths');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      setState(() {
        availableConfigs = List<Map<String, dynamic>>.from(data);
      });
    }
  }

  Future<void> fetchOverlay(String path) async {
    setState(() => isLoading = true);
    final uri =
        Uri.parse('http://192.168.0.10:8000/api/overlay_config?path=$path');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        selectedPath = path;
        selectedImageUrl = data['image_url'];
        rectangles = List<Map<String, dynamic>>.from(data['rectangles']);
      });
    } else {
      setState(() {
        selectedImageUrl = null;
        rectangles = [];
      });
    }
    setState(() => isLoading = false);
  }

  void updateRectangle(
      int index, double newX, double newY, double newW, double newH) {
    if (imageSize == null) return;

    setState(() {
      rectangles[index]['x'] = (newX / imageSize!.width).clamp(0.0, 1.0);
      rectangles[index]['y'] = (newY / imageSize!.height).clamp(0.0, 1.0);
      rectangles[index]['width'] = (newW / imageSize!.width).clamp(0.01, 1.0);
      rectangles[index]['height'] = (newH / imageSize!.height).clamp(0.01, 1.0);
    });
  }

  @override
  void initState() {
    super.initState();
    fetchAvailablePaths();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overlay Editor')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButton<String>(
              value: selectedPath,
              hint: const Text("Seleziona il path"),
              onChanged: (newValue) {
                setState(() {
                  selectedPath = newValue!;
                });
                fetchOverlay(newValue!);
              },
              items: availableConfigs
                  .map((config) => DropdownMenuItem<String>(
                        value: config['path'] as String,
                        child: Text(config['path']),
                      ))
                  .toList(),
            ),
          ),
          if (isLoading) const Center(child: CircularProgressIndicator()),
          if (!isLoading && selectedImageUrl != null)
            Expanded(
              child: InteractiveViewer(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const imageAspectRatio = 16 / 9;

                    double maxWidth = constraints.maxWidth;
                    double maxHeight = constraints.maxHeight;

                    double targetWidth, targetHeight;

                    if (maxWidth / maxHeight > imageAspectRatio) {
                      targetHeight = maxHeight;
                      targetWidth = targetHeight * imageAspectRatio;
                    } else {
                      targetWidth = maxWidth;
                      targetHeight = targetWidth / imageAspectRatio;
                    }

                    return Center(
                      child: SizedBox(
                        width: targetWidth,
                        height: targetHeight,
                        child: Stack(
                          children: [
                            Image.network(
                              selectedImageUrl!,
                              key: _imageKey,
                              width: targetWidth,
                              height: targetHeight,
                              fit: BoxFit.contain,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    final box = _imageKey.currentContext
                                        ?.findRenderObject() as RenderBox?;
                                    if (box != null && imageSize != box.size) {
                                      setState(() {
                                        imageSize = box.size;
                                      });
                                    }
                                  });
                                }
                                return child;
                              },
                            ),
                            if (imageSize != null)
                              ...rectangles.asMap().entries.map((entry) {
                                final index = entry.key;
                                final rect = entry.value;

                                double x = rect['x'] * imageSize!.width;
                                double y = rect['y'] * imageSize!.height;
                                double width = rect['width'] * imageSize!.width;
                                double height =
                                    rect['height'] * imageSize!.height;

                                return Positioned(
                                  left: x,
                                  top: y,
                                  width: width,
                                  height: height,
                                  child: GestureDetector(
                                    onPanStart: (_) {
                                      dragStartGlobal = Offset(x, y);
                                      activeDragIndex = index;
                                    },
                                    onPanUpdate: (details) {
                                      if (activeDragIndex == index &&
                                          dragStartGlobal != null) {
                                        final newX = x + details.delta.dx;
                                        final newY = y + details.delta.dy;
                                        updateRectangle(
                                            index, newX, newY, width, height);
                                      }
                                    },
                                    onPanEnd: (_) {
                                      dragStartGlobal = null;
                                      activeDragIndex = null;
                                    },
                                    child: Stack(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.greenAccent,
                                                width: 2),
                                            color:
                                                Colors.green.withOpacity(0.2),
                                          ),
                                          child: Center(
                                            child: Text(
                                              rect['name'],
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: GestureDetector(
                                            onPanStart: (details) {
                                              resizeStartGlobal =
                                                  details.globalPosition;
                                              initialResizeSize =
                                                  Size(width, height);
                                              activeResizeIndex = index;
                                            },
                                            onPanUpdate: (details) {
                                              if (activeResizeIndex == index &&
                                                  resizeStartGlobal != null &&
                                                  initialResizeSize != null) {
                                                final dx =
                                                    details.globalPosition.dx -
                                                        resizeStartGlobal!.dx;
                                                final dy =
                                                    details.globalPosition.dy -
                                                        resizeStartGlobal!.dy;
                                                final newW =
                                                    initialResizeSize!.width +
                                                        dx;
                                                final newH =
                                                    initialResizeSize!.height +
                                                        dy;
                                                updateRectangle(
                                                    index, x, y, newW, newH);
                                              }
                                            },
                                            onPanEnd: (_) {
                                              resizeStartGlobal = null;
                                              activeResizeIndex = null;
                                              initialResizeSize = null;
                                            },
                                            child: const Icon(Icons.open_with,
                                                size: 18, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("Salva modifiche"),
              onPressed: selectedPath == null
                  ? null
                  : () async {
                      final uri = Uri.parse(
                          'http://192.168.0.10:8000/api/update_overlay_config');
                      final body = {
                        "path": selectedPath,
                        "rectangles": rectangles,
                      };

                      final response = await http.post(
                        uri,
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode(body),
                      );

                      if (response.statusCode == 200) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('✔️ Modifiche salvate!')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ Errore: ${response.body}')),
                        );
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}
