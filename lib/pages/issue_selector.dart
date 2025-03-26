import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class IssueSelectorWidget extends StatefulWidget {
  final String channelId;
  final Function(String fullPath) onIssueSelected;

  const IssueSelectorWidget({
    Key? key,
    required this.channelId,
    required this.onIssueSelected,
  }) : super(key: key);

  @override
  IssueSelectorWidgetState createState() => IssueSelectorWidgetState();
}

class IssueSelectorWidgetState extends State<IssueSelectorWidget>
    with TickerProviderStateMixin {
  // When pathStack is empty, show main group selection.
  // Once a group is selected, we add it to pathStack.
  List<String> pathStack = [];
  List<dynamic> currentItems = [];
  List<dynamic> currentRectangles = [];
  String backgroundImageUrl = "";
  bool isLoading = false;
  Set<String> selectedLeaves = {};
  final GlobalKey _imageKey = GlobalKey();
  Size? imageSize;

  // Define main groups and a mapping to base images.
  final List<String> mainGroups = [
    "Saldatura",
    "Disallineamento",
    "Mancanza_Ribbon",
    "Generali",
  ];
  //"Rottura_Celle",
  //"Macchie_ECA_Celle",

  final Map<String, String> groupImages = {
    "Saldatura": "http://192.168.0.10:8000/images/Linea2/saldatura.jpg",
    "Disallineamento":
        "http://192.168.0.10:8000/images/Linea2/disallineamento.jpg",
    "Mancanza_Ribbon":
        "http://192.168.0.10:8000/images/Linea2/mancanza_ribbon.jpg",
    "Generali": "http://192.168.0.10:8000/images/Linea2/generali.jpg",
  };

  //"Rottura_Celle": "http://192.168.0.10:8000/images/Linea2/rottura_celle.jpg",
  //"Macchie_ECA_Celle":
  //      "http://192.168.0.10:8000/images/Linea2/macchie_eca_celle.jpg",

  @override
  void initState() {
    super.initState();
    // Start by showing the main groups.
  }

  // Build the full API path: always prefixed with "Dati.Esito.Esito_Scarto.Difetti"
  String get apiPath {
    if (pathStack.isEmpty) {
      return "Dati.Esito.Esito_Scarto.Difetti";
    } else {
      return "Dati.Esito.Esito_Scarto.Difetti." + pathStack.join(".");
    }
  }

  // Determine the background image URL for the current level.
  String get currentImageUrl {
    if (pathStack.isEmpty) return "";
    if (pathStack.length == 1) {
      // level 1: use main group image
      return groupImages[pathStack.first] ??
          "http://192.168.0.10:8000/images/Linea2/default.jpg";
    }
    // For deeper levels, you might have images like: "<group>_<subfolder>.jpg"
    String base = pathStack.first.toLowerCase();
    String sub = pathStack.last.toLowerCase().replaceAll(' ', '_');
    return "http://192.168.0.10:8000/images/Linea2/${base}_$sub.jpg";
  }

  Future<void> _fetchCurrentItems() async {
    setState(() {
      isLoading = true;
    });

    final issueUrl = Uri.parse(
        'http://192.168.0.10:8000/api/issues/${widget.channelId}?path=$apiPath');
    final overlayUrl =
        Uri.parse('http://192.168.0.10:8000/api/overlay_config?path=$apiPath');

    try {
      final issueResponse = await http.get(issueUrl);
      final overlayResponse = await http.get(overlayUrl);

      if (issueResponse.statusCode == 200) {
        final data = jsonDecode(issueResponse.body);
        currentItems = data['items'];
      }

      if (overlayResponse.statusCode == 200) {
        final overlay = jsonDecode(overlayResponse.body);
        backgroundImageUrl = overlay['image_url'];
        currentRectangles = overlay['rectangles'];
      } else {
        currentRectangles = [];
      }
    } catch (e) {
      currentItems = [];
      currentRectangles = [];
    }

    setState(() {
      isLoading = false;
    });
  }

  void _onGroupSelected(String group) {
    // When a main group is selected, set pathStack to contain that group.
    setState(() {
      pathStack = [group];
    });
    _fetchCurrentItems();
  }

  void _onRectangleTapped(String name, String type) {
    // Full path of tapped rectangle is apiPath + "." + name.
    final fullPath = "$apiPath.$name";
    if (type == "folder") {
      // Not a leaf: push to stack and load next level.
      setState(() {
        pathStack.add(name);
      });
      _fetchCurrentItems();
    } else {
      // Leaf: toggle selection.
      setState(() {
        if (selectedLeaves.contains(fullPath)) {
          selectedLeaves.remove(fullPath);
        } else {
          selectedLeaves.add(fullPath);
        }
      });
      widget.onIssueSelected(fullPath);
    }
  }

  void _goBack() {
    if (pathStack.isNotEmpty) {
      setState(() {
        pathStack.removeLast();
      });
      _fetchCurrentItems();
    }
  }

  void _goHome() {
    setState(() {
      pathStack = [];
      backgroundImageUrl = "";
      currentItems = [];
      currentRectangles = [];
      // ❌ Do NOT reset selectedLeaves here
    });
  }

  bool groupHasSelected(String group) {
    return selectedLeaves.any((issuePath) => issuePath.contains(".$group."));
  }

  // Navigation buttons overlay
  Widget _buildNavigationButtons() {
    // Show back & home buttons only if we're not on the main groups level.
    if (pathStack.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: _goBack,
            child: const Text("Back"),
          ),
          ElevatedButton(
            onPressed: _goHome,
            child: const Text("Home"),
          ),
        ],
      ),
    );
  }

  // Main view: if pathStack is empty, show main groups as big buttons.
  Widget _buildGroupSelection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Seleziona un gruppo",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: mainGroups.map((group) {
              return ElevatedButton(
                onPressed: () => _onGroupSelected(group),
                style: ElevatedButton.styleFrom(
                  backgroundColor: groupHasSelected(group)
                      ? Colors.greenAccent.withOpacity(0.3)
                      : null,
                  side: groupHasSelected(group)
                      ? const BorderSide(color: Colors.green, width: 2)
                      : null,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                ),
                child: Text(
                  group,
                  style: const TextStyle(fontSize: 20),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Assuming your base image is 16:9
        const imageAspectRatio = 16 / 9;

        double maxWidth = constraints.maxWidth;
        double maxHeight = constraints.maxHeight;

        double targetWidth, targetHeight;

        if (maxWidth / maxHeight > imageAspectRatio) {
          // screen is wider than image aspect ratio
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
                // Background image
                Image.network(
                  backgroundImageUrl,
                  key: _imageKey,
                  width: targetWidth,
                  height: targetHeight,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final box = _imageKey.currentContext?.findRenderObject()
                            as RenderBox?;
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
                // Navigation buttons (Back & Home)
                _buildNavigationButtons(),
                // Rectangles overlay
                if (imageSize != null)
                  ...currentRectangles
                      .where((rect) =>
                          (rect['width'] ?? 0) > 0.02 &&
                          (rect['height'] ?? 0) > 0.02)
                      .map((rect) {
                    final double x = rect['x'] * imageSize!.width;
                    final double y = rect['y'] * imageSize!.height;
                    final double width = rect['width'] * imageSize!.width;
                    final double height = rect['height'] * imageSize!.height;

                    final String name = rect['name'];
                    final String type = rect['type'];
                    final fullPath = "$apiPath.$name";
                    // Highlight if this rectangle was directly selected or is a parent
                    final isSelected = selectedLeaves.contains(fullPath) ||
                        selectedLeaves.any((leaf) => leaf.startsWith(fullPath));

                    return Positioned(
                      left: x,
                      top: y,
                      width: width,
                      height: height,
                      child: GestureDetector(
                        onTap: () => _onRectangleTapped(name, type),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.green.withOpacity(0.3)
                                : Colors.black.withOpacity(0.1),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.greenAccent
                                  : Colors.blueAccent,
                              width: isSelected ? 4 : 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(2, 2),
                              ),
                            ],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 2,
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 600, // adjust as needed
      child: pathStack.isEmpty ? _buildGroupSelection() : _buildOverlayView(),
    );
  }
}
