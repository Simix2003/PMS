// ignore_for_file: deprecated_member_use, unrelated_type_equality_checks

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class IssueSelectorWidget extends StatefulWidget {
  final String selectedLine;
  final String channelId;
  final Function(String fullPath) onIssueSelected;

  const IssueSelectorWidget({
    super.key,
    required this.selectedLine,
    required this.channelId,
    required this.onIssueSelected,
  });

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
      return "Dati.Esito.Esito_Scarto.Difetti.${pathStack.join(".")}";
    }
  }

  // Determine the background image URL for the current level.
  String get currentImageUrl {
    final line = widget.selectedLine;
    final station = widget.channelId;

    if (pathStack.isEmpty) return "";

    if (pathStack.length == 1) {
      final group = pathStack.first.toLowerCase();
      return "http://192.168.0.10:8000/images/$line/$station/$group.jpg";
    }

    final base = pathStack.first.toLowerCase();
    final sub = pathStack.last.toLowerCase().replaceAll(' ', '_');
    return "http://192.168.0.10:8000/images/$line/$station/${base}_$sub.jpg";
  }

  Future<void> _fetchCurrentItems() async {
    setState(() {
      isLoading = true;
    });

    final line = widget.selectedLine;
    final channel = widget.channelId;

    // Correct the URL parameters: replace `channel` with `station`
    final issueUrl = Uri.parse(
        'http://192.168.0.10:8000/api/issues/$line/$channel?path=$apiPath');
    final overlayUrl = Uri.parse(
        'http://192.168.0.10:8000/api/overlay_config?path=$apiPath&line_name=$line&station=$channel');

    try {
      final issueResponse = await http.get(issueUrl);
      print('Sending overlayURL: $overlayUrl');
      final overlayResponse = await http.get(overlayUrl);
      print('Received overlayURL respone: ${overlayResponse.body}');

      if (issueResponse.statusCode == 200) {
        final data = jsonDecode(issueResponse.body);
        currentItems = data['items'];
      }

      if (overlayResponse.statusCode == 200) {
        final overlay = jsonDecode(overlayResponse.body);
        backgroundImageUrl = overlay['image_url'] ?? currentImageUrl;
        currentRectangles = overlay['rectangles'];
      } else {
        currentRectangles = [];
        backgroundImageUrl = currentImageUrl;
      }
    } catch (e) {
      currentItems = [];
      currentRectangles = [];
      backgroundImageUrl = currentImageUrl;
    }

    setState(() {
      isLoading = false;
    });
  }

  void _onGroupSelected(String group) {
    // When a main group is selected, set pathStack to contain that group.
    setState(() {
      if (group == 'Mancanza_Ribbon') {
        pathStack = ['Mancanza_Ribbon', 'Ribbon'];
      } else {
        pathStack = [group];
      }
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
        if (pathStack[0] == 'Mancanza_Ribbon' && pathStack.length == 2) {
          pathStack = [];
        } else {
          pathStack.removeLast();
          _fetchCurrentItems();
        }
      });
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

  Widget _buildDisallineamentoButtons() {
    final subGroups = ["Ribbon", "Stringa"];

    return Padding(
      padding: const EdgeInsets.only(top: 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: subGroups.map((sub) {
                final fullPathPrefix =
                    "Dati.Esito.Esito_Scarto.Difetti.Disallineamento.$sub";
                final isSelected = selectedLeaves
                    .any((leaf) => leaf.startsWith(fullPathPrefix));

                return ElevatedButton(
                  onPressed: () {
                    setState(() {
                      pathStack.add(sub);
                    });
                    _fetchCurrentItems();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? Colors.deepOrange.withOpacity(0.2)
                        : Colors.white,
                    foregroundColor: Colors.black,
                    side: isSelected
                        ? const BorderSide(color: Colors.deepOrange, width: 2)
                        : const BorderSide(color: Colors.blueGrey, width: 1),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: isSelected ? 3 : 2,
                  ),
                  child: Text(
                    sub,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    if (pathStack.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _goBack,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Indietro',
              color: Colors.white,
              iconSize: 28,
            ),
          ),
          const SizedBox(width: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _goHome,
              icon: const Icon(Icons.home),
              tooltip: 'Home',
              color: Colors.white,
              iconSize: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneraliButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: currentItems.map<Widget>((item) {
                final String name = item['name'];
                final fullPath = "$apiPath.$name";
                final bool isSelected = selectedLeaves.contains(fullPath);

                return ElevatedButton(
                  onPressed: () {
                    setState(() {
                      if (isSelected) {
                        selectedLeaves.remove(fullPath);
                      } else {
                        selectedLeaves.add(fullPath);
                      }
                    });
                    widget.onIssueSelected(fullPath);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isSelected ? Colors.deepOrange.withOpacity(0.2) : null,
                    foregroundColor: Colors.black,
                    side: isSelected
                        ? const BorderSide(color: Colors.deepOrange, width: 2)
                        : null,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: isSelected ? 3 : 1,
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSelection() {
    return Padding(
      padding: const EdgeInsets.only(top: 60.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "Seleziona un gruppo di difetti",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          Center(
            child: Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: mainGroups.map((group) {
                final bool selected = groupHasSelected(group);
                return ElevatedButton(
                  onPressed: () => _onGroupSelected(group),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selected
                        ? Colors.deepOrange.withOpacity(0.2)
                        : null, // Default button color when not selected
                    foregroundColor: Colors.black,
                    side: selected
                        ? const BorderSide(color: Colors.deepOrange, width: 2)
                        : null,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: selected ? 3 : null,
                  ),
                  child: Text(
                    group,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<double> _desaturationMatrix(double amount) {
    // amount: 0 = full color, 1 = full grayscale
    final r = 0.2126;
    final g = 0.7152;
    final b = 0.0722;
    final inv = 1 - amount;

    return [
      r * amount + inv,
      g * amount,
      b * amount,
      0,
      0,
      r * amount,
      g * amount + inv,
      b * amount,
      0,
      0,
      r * amount,
      g * amount,
      b * amount + inv,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
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
                ColorFiltered(
                  colorFilter: ColorFilter.matrix(_desaturationMatrix(
                      0.5)), // 0.0 = full color, 1.0 = grayscale
                  child: Image.network(
                    backgroundImageUrl,
                    key: _imageKey,
                    width: targetWidth,
                    height: targetHeight,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
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
                ),

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
                                ? Colors.deepOrange.withOpacity(0.2)
                                : Colors.black.withOpacity(0.05),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.deepOrange
                                  : Colors.blue.shade800,
                              width: isSelected ? 6 : 4,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: const Offset(2, 2),
                                    ),
                                  ]
                                : [],
                            borderRadius:
                                BorderRadius.circular(8), // same as buttons
                          ),
                          child: Center(
                              child: const SizedBox
                                  .shrink() // Hide text when selected

                              ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuidedHint() {
    String path =
        apiPath; // es: "Dati.Esito.Esito_Scarto.Difetti.Saldatura.Stringa_F"

    String hint;

    if (pathStack.isEmpty) {
      hint = "Seleziona un gruppo di difetti per iniziare.";
    } else if (pathStack.length == 1 && pathStack[0] == "Saldatura") {
      hint = "Seleziona Interconnection Ribbon";
    } else if (pathStack.length == 2 && pathStack[0] == "Saldatura") {
      hint = "Seleziona la Stringa interessata dal difetto di saldatura.";
    } else if (pathStack.length == 3 && pathStack[0] == "Saldatura") {
      hint = "Seleziona i String-Ribbon interessati dal difetto di saldatura.";
    } else if (pathStack.length == 1 && pathStack[0] == "Disallineamento") {
      hint = "Scegli tra Interconnection Ribbon o Stringa.";
    } else if (pathStack[0] == "Disallineamento" &&
        pathStack[1] == "Ribbon" &&
        pathStack.length == 3) {
      hint = "Seleziona Interconnection Ribbon disallineato";
    } else if (path.contains("Disallineamento.Ribbon")) {
      hint = "Seleziona lato Interconnection Ribbon disallineato";
    } else if (path.contains("Disallineamento.Stringa")) {
      hint = "Seleziona la stringa che presenta disallineamento.";
    } else if (pathStack.length == 3 && pathStack[0] == "Mancanza_Ribbon") {
      hint = "Seleziona Interconnection Ribbon mancante.";
    } else if (pathStack.length == 2 && pathStack[0] == "Mancanza_Ribbon") {
      hint = "Seleziona lato Interconnection Ribbon mancante.";
    } else if (pathStack.length == 1 && pathStack[0] == "Generali") {
      hint = "Seleziona il tipo di difetto generale riscontrato.";
    } else {
      hint = "Seleziona l'area corretta toccando l'immagine.";
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Text(
        hint,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 600,
      child: pathStack.isEmpty
          ? SingleChildScrollView(child: _buildGroupSelection())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNavigationButtons(),
                  _buildGuidedHint(),
                  if (pathStack.length == 1 &&
                      pathStack[0] == "Disallineamento")
                    _buildDisallineamentoButtons()
                  else if (pathStack.length == 1 && pathStack[0] == "Generali")
                    _buildGeneraliButtons()
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight:
                            500, // 👈 limit how tall the image view can be
                      ),
                      child: _buildOverlayView(),
                    ),
                ],
              ),
            ),
    );
  }
}
