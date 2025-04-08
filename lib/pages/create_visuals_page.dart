// create_visual_page.dart
import 'package:flutter/material.dart';
import '../shared/services/api_service.dart';

Map<String, dynamic> issueTree = {
  "Generali": {
    "Non Lavorato Poe Scaduto": {},
    "Non Lavorato da Telecamere": {},
    "Materiale Esterno su Celle": {},
    "Bad Soldering": {}
  },
  "Saldatura": {},
  "Saldatura.Stringa[1]": {},
  "Saldatura.Stringa[2]": {},
  "Saldatura.Stringa[3]": {},
  "Saldatura.Stringa[4]": {},
  "Saldatura.Stringa[5]": {},
  "Saldatura.Stringa[6]": {},
  "Saldatura.Stringa[7]": {},
  "Saldatura.Stringa[8]": {},
  "Saldatura.Stringa[9]": {},
  "Saldatura.Stringa[10]": {},
  "Saldatura.Stringa[11]": {},
  "Saldatura.Stringa[12]": {},
  "Disallineamento": {
    for (var i = 1; i <= 12; i++) 'Stringa[\$i]': null,
    for (var i = 1; i <= 10; i++)
      'Ribbon[\$i]': {"F": null, "M": null, "B": null},
  },
  "Mancanza Ribbon": {
    for (var i = 1; i <= 10; i++)
      'Ribbon[\$i]': {"F": null, "M": null, "B": null},
  },
  "Macchie ECA": {
    for (var i = 1; i <= 12; i++) 'Stringa[\$i]': null,
  },
  "Celle Rotte": {
    for (var i = 1; i <= 12; i++) 'Stringa[\$i]': null,
  },
  "Lunghezza String Ribbon": {
    for (var i = 1; i <= 12; i++) 'Stringa[\$i]': null,
  }
};

List<Map<String, dynamic>> generateRectanglesFromTree(dynamic node) {
  List<Map<String, dynamic>> rectangles = [];

  void walk(String path, dynamic current) {
    if (current is Map && current.isNotEmpty) {
      current.forEach((key, value) {
        walk(path.isEmpty ? key : "\$path.\$key", value);
      });
    } else {
      rectangles.add({
        "name": path.split('.').last,
        "x": 0.45,
        "y": 0.45,
        "width": 0.1,
        "height": 0.1,
        "type": "leaf",
      });
    }
  }

  walk("", node);
  return rectangles;
}

class CreateVisualPage extends StatefulWidget {
  final String lineName;
  final String station;

  const CreateVisualPage({
    Key? key,
    required this.lineName,
    required this.station,
  }) : super(key: key);

  @override
  State<CreateVisualPage> createState() => _CreateVisualPageState();
}

class _CreateVisualPageState extends State<CreateVisualPage> {
  final List<String> mainGroups = issueTree.keys.toList();
  String? selectedGroup;
  String? selectedPath;
  String? selectedImageUrl;
  List<Map<String, dynamic>> rectangles = [];
  Offset? dragStartGlobal;
  Offset? resizeStartGlobal;
  int? activeDragIndex;
  int? activeResizeIndex;
  Size? initialResizeSize;
  final GlobalKey _imageKey = GlobalKey();
  Size? imageSize;
  bool isLoading = false;

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

  Future<void> _saveOverlay() async {
    if (selectedPath == null) return;
    try {
      final success = await ApiService.updateOverlayConfig(
        path: selectedPath!,
        rectangles: rectangles,
        lineName: widget.lineName,
        station: widget.station,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '✔️ Modifiche salvate!'
              : '❌ Errore durante il salvataggio'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Errore durante il salvataggio: \$e')),
      );
    }
  }

  Future<void> _onGroupSelected(String group) async {
    setState(() {
      selectedGroup = group;
      selectedPath = "Dati.Esito.Esito_Scarto.Difetti.$group";
      isLoading = true;
    });

    try {
      final overlay = await ApiService.fetchOverlayConfig(
        selectedPath!,
        widget.lineName,
        widget.station,
      );

      setState(() {
        selectedImageUrl = overlay["image_url"];
        rectangles = List<Map<String, dynamic>>.from(overlay["rectangles"]);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Overlay non trovato per '\$group'")),
      );
      setState(() {
        selectedImageUrl = null;
        rectangles = [];
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editor Overlay')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButton<String>(
              value: selectedGroup,
              hint: const Text("Seleziona il gruppo di difetti"),
              onChanged: (group) {
                if (group != null) _onGroupSelected(group);
              },
              items: mainGroups
                  .map((group) => DropdownMenuItem<String>(
                        value: group,
                        child: Text(group),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (selectedImageUrl != null)
            Expanded(
              child: InteractiveViewer(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const aspectRatio = 16 / 9;
                    double maxWidth = constraints.maxWidth;
                    double maxHeight = constraints.maxHeight;
                    double targetWidth, targetHeight;
                    if (maxWidth / maxHeight > aspectRatio) {
                      targetHeight = maxHeight;
                      targetWidth = targetHeight * aspectRatio;
                    } else {
                      targetWidth = maxWidth;
                      targetHeight = targetWidth / aspectRatio;
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
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) {
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
                                final x = rect['x'] * imageSize!.width;
                                final y = rect['y'] * imageSize!.height;
                                final w = rect['width'] * imageSize!.width;
                                final h = rect['height'] * imageSize!.height;
                                return Positioned(
                                  left: x,
                                  top: y,
                                  width: w,
                                  height: h,
                                  child: GestureDetector(
                                    onPanStart: (_) {
                                      dragStartGlobal = Offset(x, y);
                                      activeDragIndex = index;
                                    },
                                    onPanUpdate: (details) {
                                      if (activeDragIndex == index &&
                                          _imageKey.currentContext != null) {
                                        final box = _imageKey.currentContext!
                                            .findRenderObject() as RenderBox;
                                        final localPosition = box.globalToLocal(
                                            details.globalPosition);

                                        final newX = localPosition.dx - (w / 2);
                                        final newY = localPosition.dy - (h / 2);

                                        updateRectangle(
                                            index, newX, newY, w, h);
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
                                              initialResizeSize = Size(w, h);
                                              activeResizeIndex = index;
                                            },
                                            onPanUpdate: (details) {
                                              if (activeResizeIndex == index) {
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
                                              initialResizeSize = null;
                                              activeResizeIndex = null;
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
              onPressed: (selectedPath == null || selectedImageUrl == null)
                  ? null
                  : _saveOverlay,
            ),
          ),
        ],
      ),
    );
  }
}
