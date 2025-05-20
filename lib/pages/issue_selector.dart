// ignore_for_file: deprecated_member_use, unrelated_type_equality_checks, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:ix_monitor/pages/picture_gallery.dart';
import 'package:ix_monitor/pages/picture_page.dart';
import '../../shared/services/api_service.dart';
import '../shared/services/info_service.dart';

class IssueSelectorWidget extends StatefulWidget {
  final String selectedLine;
  final String channelId;
  final Function(String fullPath) onIssueSelected;
  final void Function(List<Map<String, String>> pictures)? onPicturesChanged;
  final bool canAdd;
  final bool isReworkMode; // defaults to false
  final List<String> initiallySelectedIssues; // used in rework
  final List<Map<String, String>> initiallyCreatedPictures; // used in rework
  final String objectId;

  const IssueSelectorWidget({
    super.key,
    required this.selectedLine,
    required this.channelId,
    required this.onIssueSelected,
    this.onPicturesChanged,
    this.canAdd = true,
    this.isReworkMode = false,
    this.initiallySelectedIssues = const [],
    this.initiallyCreatedPictures = const [],
    required this.objectId,
  });

  @override
  IssueSelectorWidgetState createState() => IssueSelectorWidgetState();
}

class IssueSelectorWidgetState extends State<IssueSelectorWidget>
    with TickerProviderStateMixin {
  // pathStack is empty to start with and when empty, it will default to the base path.
  List<String> pathStack = [];
  List<dynamic> currentItems = [];
  List<dynamic> currentRectangles = [];
  String backgroundImageUrl = "";
  bool isLoading = false;
  Set<String> selectedLeaves = {};
  final GlobalKey _imageKey = GlobalKey();
  Size? imageSize;
  List<String> altroIssues = [];
  TextEditingController altroController = TextEditingController();
  List<Map<String, String>> allPictures = [];
  String? activeLeafDefect;

  // Updated main groups to exactly match backend keys:
  final List<String> mainGroups = [ //Should get from MySQL : defects table
    "Saldatura",
    "Disallineamento",
    "Mancanza Ribbon",
    "Generali",
    "Macchie ECA",
    "Celle Rotte",
    "I Ribbon Leadwire",
    "Lunghezza String Ribbon",
    "Graffio su Cella",
    "Altro",
  ];

  @override
  void initState() {
    super.initState();

    if (widget.isReworkMode) {
      selectedLeaves = widget.initiallySelectedIssues.toSet();
      allPictures = widget.initiallyCreatedPictures;

      // Extract ALTRO issues from selectedLeaves
      for (final issue in widget.initiallySelectedIssues) {
        if (issue.startsWith("Dati.Esito.Esito_Scarto.Difetti.Altro: ")) {
          final text = issue.split("Altro: ").last;
          altroIssues.add(text);
        }
      }
    }
  }

  // Build the full API path using the new backend structure.
  String get apiPath {
    if (pathStack.isEmpty) {
      return "Dati.Esito.Esito_Scarto.Difetti";
    } else {
      return "Dati.Esito.Esito_Scarto.Difetti.${pathStack.join(".")}";
    }
  }

  Future<void> _fetchCurrentItems() async {
    setState(() => isLoading = true);
    try {
      final issues = await ApiService.fetchIssues(
        line: widget.selectedLine,
        station: widget.channelId,
        path: apiPath,
      );

      final overlay = await ApiService.fetchIssueOverlay(
        line: widget.selectedLine,
        station: widget.channelId,
        path: apiPath,
        object_id: widget.objectId,
      );

      final fallbackUrl = await ApiService.buildOverlayImageUrl(
        line: widget.selectedLine,
        station: widget.channelId,
        pathStack: pathStack,
        object_id: widget.objectId,
      );

      setState(() {
        currentItems = issues;
        currentRectangles = overlay['rectangles'] ?? [];
        final newImageUrl = overlay['image_url'];
        backgroundImageUrl = (newImageUrl != null && newImageUrl.isNotEmpty)
            ? newImageUrl
            : fallbackUrl;
      });

      _updateActiveLeafDefectIfSelected();
    } catch (e) {
      debugPrint("❌ Error in _fetchCurrentItems: $e");

      final fallbackUrl = await ApiService.buildOverlayImageUrl(
        line: widget.selectedLine,
        station: widget.channelId,
        pathStack: pathStack,
        object_id: widget.objectId,
      );

      setState(() {
        currentItems = [];
        currentRectangles = [];
        backgroundImageUrl = fallbackUrl;
      });
    }
    setState(() => isLoading = false);
  }

  void _onGroupSelected(String group) {
    setState(() {
      pathStack = [group];

      // 👇 Automatically restore previously selected defect in Generali or Altro
      if (group == "Generali") {
        final match = selectedLeaves.firstWhere(
          (defect) => defect.contains(".Generali."),
          orElse: () => "",
        );
        activeLeafDefect = match.isNotEmpty ? match : null;
      } else if (group == "Altro") {
        final match = selectedLeaves.firstWhere(
          (defect) => defect.contains("Altro: "),
          orElse: () => "",
        );
        activeLeafDefect = match.isNotEmpty ? match : null;
      } else {
        activeLeafDefect = null; // reset for others
      }
    });

    if (group != "Altro" || (widget.isReworkMode && groupHasSelected(group))) {
      _fetchCurrentItems();
    }
  }

  void _updateActiveLeafDefectIfSelected() {
    if (_isLeafLevel()) {
      for (var rect in currentRectangles) {
        final String fullPath = "$apiPath.${normalizeName(rect['name'])}";
        if (selectedLeaves.contains(fullPath)) {
          setState(() {
            activeLeafDefect = fullPath;
          });
          break;
        }
      }
    }
  }

  void _onRectangleTapped(String name, String type) {
    // Full path of tapped rectangle is apiPath + "." + name.
    if (type == "Folder") {
      // If folder, push new level.
      setState(() {
        pathStack.add(name);
      });
      _fetchCurrentItems();
    } else if (type == "Leaf") {
      final fullPath = "$apiPath.${normalizeName(name)}";

      // ⛔ Prevent changes if canAdd is false
      if (!widget.canAdd) {
        return;
      }

      setState(() {
        if (selectedLeaves.contains(fullPath)) {
          selectedLeaves.remove(fullPath);
          if (activeLeafDefect == fullPath) {
            activeLeafDefect = null;
          }
        } else {
          selectedLeaves.add(fullPath);
          activeLeafDefect = fullPath;
        }
      });
      widget.onIssueSelected(fullPath);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unsupported rectangle type")),
      );
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
    });
  }

  bool groupHasSelected(String group) {
    if (group == "Altro") {
      return altroIssues.isNotEmpty;
    }
    return selectedLeaves.any((issuePath) => issuePath.contains(".$group."));
  }

  Widget _buildNavigationButtons(bool isLeaf, fullPath) {
    if (pathStack.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indietro
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

            // Home
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

            if (isLeaf && selectedLeaves.contains(fullPath) ||
                activeLeafDefect != null) ...[
              const SizedBox(width: 24),

              // Scatta Foto
              if (!widget.isReworkMode || widget.isReworkMode && widget.canAdd)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextButton.icon(
                    onPressed: () async {
                      var res = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TakePicturePage(),
                        ),
                      );

                      if (res != null &&
                          res is String &&
                          activeLeafDefect != null) {
                        setState(() {
                          allPictures.add({
                            'defect': activeLeafDefect!,
                            'image': res,
                          });

                          // 🔁 Notifica al parent
                          widget.onPicturesChanged?.call(allPictures);
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Foto aggiunta con successo!"),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text(
                      "Scatta Foto",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),

              const SizedBox(width: 12),

              if (allPictures.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PictureGalleryPage(
                            images: allPictures,
                            onDelete: (index) {
                              setState(() {
                                allPictures.removeAt(index);
                                // 🔁 Notifica al parent
                                widget.onPicturesChanged?.call(allPictures);
                              });
                            },
                            isPreloaded: widget.isReworkMode ? true : false,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.image, color: Colors.white),
                    label: Text(
                      "Immagini",
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
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

                return Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ElevatedButton(
                      onPressed: widget.canAdd
                          ? () {
                              setState(() {
                                if (isSelected) {
                                  selectedLeaves.remove(fullPath);
                                  if (activeLeafDefect == fullPath) {
                                    activeLeafDefect = null;
                                  }
                                } else {
                                  selectedLeaves.add(fullPath);
                                  activeLeafDefect = fullPath;
                                }
                              });
                              widget.onIssueSelected(fullPath);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? Colors.deepOrange.withOpacity(0.2)
                            : null,
                        foregroundColor: Colors.black,
                        side: isSelected
                            ? const BorderSide(
                                color: Colors.deepOrange, width: 2)
                            : null,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 20),
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
                    ),

                    // ℹ️ Info icon for the leaf (e.g., "Bad Soldering")
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.blue,
                        ),
                        splashRadius: 20,
                        tooltip: 'Info',
                        onPressed: () =>
                            _showDefectInfo(name), // pass leaf name
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAltroField() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Descrivi i problemi riscontrati:",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.canAdd)
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: Focus(
                      autofocus: false,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.text,
                        child: TextField(
                          controller: altroController,
                          decoration: InputDecoration(
                            hintText: "Scrivi qui l'anomalia...",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: widget.canAdd
                    ? () {
                        final text = altroController.text.trim();
                        final fullPath =
                            "Dati.Esito.Esito_Scarto.Difetti.Altro: $text";
                        if (text.isNotEmpty && !altroIssues.contains(text)) {
                          setState(() {
                            altroIssues.add(text);
                            selectedLeaves.add(fullPath);
                            activeLeafDefect = fullPath;
                            widget.onIssueSelected(fullPath);
                            altroController.clear();
                          });
                        }
                      }
                    : null,
                child: const Text("Aggiungi Difetto"),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: altroIssues.map((issue) {
              return Chip(
                label: Text(issue),
                deleteIcon: const Icon(Icons.close),
                onDeleted: () {
                  setState(() {
                    final path =
                        "Dati.Esito.Esito_Scarto.Difetti.Altro: $issue";
                    altroIssues.remove(issue);
                    selectedLeaves.remove(path);
                    widget.onIssueSelected(path);
                  });
                },
                backgroundColor: Colors.deepOrange.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.deepOrange),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _showDefectInfo(String key) async {
    final info = await DefectInfoService.get(key);
    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nessuna descrizione disponibile')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(key, style: Theme.of(context).textTheme.titleLarge),
            ),

            // Scrollable + zoomable content
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      if (info['image']!.isNotEmpty)
                        SizedBox(
                          height: 400,
                          child: InteractiveViewer(
                            panEnabled: true,
                            minScale: 1,
                            maxScale: 4,
                            child: Image.asset(info['image']!,
                                fit: BoxFit.contain),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(info['description']!, textAlign: TextAlign.justify),
                    ],
                  ),
                ),
              ),
            ),

            // Close button
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Chiudi'),
              ),
            ),
          ],
        ),
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
                return Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ElevatedButton(
                      onPressed: () => _onGroupSelected(group),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selected
                            ? Colors.deepOrange.withOpacity(0.2)
                            : null,
                        foregroundColor: Colors.black,
                        side: selected
                            ? const BorderSide(
                                color: Colors.deepOrange, width: 2)
                            : null,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 20),
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
                    ),

                    // ℹ️ Info button in the corner
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.blue,
                        ),
                        splashRadius: 20,
                        tooltip: 'Info',
                        onPressed: () =>
                            _showDefectInfo(group), // You define this
                      ),
                    ),
                  ],
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

  bool _isPathSelected(String fullPath) {
    for (final leaf in selectedLeaves) {
      if (leaf.trim() == fullPath.trim()) {
        return true;
      }
      if (leaf.trim().startsWith("${fullPath.trim()}.")) {
        return true;
      }
    }
    return false;
  }

  String normalizeName(String name) {
    // Trasforma "Pin[6] - B" in "Pin[6].B"
    if (name.contains(' - ')) {
      final parts = name.split(' - ');
      return "${parts[0]}.${parts[1]}";
    }
    return name;
  }

  String denormalizeName(String normalized) {
    // Converts "Pin[6].B" back to "Pin[6] - B"
    if (normalized.contains('.')) {
      final parts = normalized.split('.');
      return "${parts[0]} - ${parts[1]}";
    }
    return normalized;
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
                  colorFilter: ColorFilter.matrix(_desaturationMatrix(0.5)),
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
                          if (box != null) {
                            if (imageSize != box.size) {
                              setState(() {
                                imageSize = box.size;
                              });
                            }
                          } else {
                            debugPrint("⚠️ RenderBox is null!");
                          }
                        });
                      } else {
                        debugPrint("⏳ Image still loading...");
                      }
                      return child;
                    },
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint("❌ Image failed to load: $error");
                      return const Center(
                        child: Icon(Icons.error, size: 60, color: Colors.red),
                      );
                    },
                  ),
                ),
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
                    final String type = rect['type'] ?? "Leaf";
                    final fullPath = "$apiPath.${normalizeName(name)}";
                    final isSelected = _isPathSelected(fullPath);

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
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const SizedBox.shrink(),
                        ),
                      ),
                    );
                  }),
                if (imageSize == null)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuidedHint() {
    String hint;

    if (widget.isReworkMode) {
      if (pathStack.isEmpty) {
        hint = "Visualizza i difetti segnalati per questo modulo.";
      } else if (pathStack.length == 1 && pathStack[0] == "Saldatura") {
        hint = "Controlla la stringa segnalata per un difetto di saldatura.";
      } else if (pathStack.length == 2 && pathStack[0] == "Saldatura") {
        hint = "Controlla i Pin indicati nella stringa selezionata.";
      } else if (pathStack.length == 1 && pathStack[0] == "Disallineamento") {
        hint =
            "Verifica il disallineamento di Stringhe o Interconnection Ribbon.";
      } else if (pathStack.length == 1 && pathStack[0] == "Mancanza Ribbon") {
        hint = "Verifica la mancanza dei Ribbon indicati.";
      } else if (pathStack.length == 1 && pathStack[0] == "Generali") {
        hint = "Verifica la presenza di difetti generali sul modulo.";
      } else if (pathStack.length == 1 && pathStack[0] == "Macchie ECA") {
        hint = "Controlla le celle per possibili macchie da ECA.";
      } else if (pathStack.length == 1 && pathStack[0] == "Celle Rotte") {
        hint = "Ispeziona le celle segnalate come rotte.";
      } else if (pathStack.length == 1 &&
          pathStack[0] == "Lunghezza String Ribbon") {
        hint = "Controlla la lunghezza delle stringhe indicate.";
      } else {
        hint =
            "Controlla l'area segnalata toccando sull'immagine per i dettagli.";
      }
    } else {
      if (pathStack.isEmpty) {
        hint = "Seleziona un gruppo di difetti per iniziare.";
      } else if (pathStack.length == 1 && pathStack[0] == "Saldatura") {
        hint = "Seleziona la Stringa interessata dal difetto di saldatura.";
      } else if (pathStack.length == 2 && pathStack[0] == "Saldatura") {
        hint = "Seleziona i Pin interessati dal difetto di saldatura.";
      } else if (pathStack.length == 1 && pathStack[0] == "Disallineamento") {
        hint = "Seleziona Interconnection Ribbon o Stringa disallineati.";
      } else if (pathStack.length == 1 && pathStack[0] == "Mancanza Ribbon") {
        hint = "Seleziona Interconnection Ribbon mancante.";
      } else if (pathStack.length == 1 && pathStack[0] == "Generali") {
        hint = "Seleziona il tipo di difetto generale riscontrato.";
      } else if (pathStack.length == 1 && pathStack[0] == "Macchie ECA") {
        hint = "Seleziona le Celle macchiate.";
      } else if (pathStack.length == 1 && pathStack[0] == "Celle Rotte") {
        hint = "Seleziona le Celle rotte.";
      } else if (pathStack.length == 1 &&
          pathStack[0] == "Lunghezza String Ribbon") {
        hint = "Seleziona la Stringa interessata dal difetto di lunghezza.";
      } else {
        hint = "Seleziona l'area corretta toccando l'immagine.";
      }
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

  bool _isLeafLevel() {
    return currentRectangles.every((r) => r['type'] != 'Folder');
  }

  String _fullPath() {
    return pathStack.isEmpty ? '' : pathStack.join('.');
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
                  _buildNavigationButtons(_isLeafLevel(), _fullPath()),
                  _buildGuidedHint(),
                  if (pathStack.length == 1 && pathStack[0] == "Generali")
                    _buildGeneraliButtons()
                  else if (pathStack.length == 1 && pathStack[0] == "Altro")
                    _buildAltroField()
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 500,
                      ),
                      child: backgroundImageUrl.isNotEmpty
                          ? _buildOverlayView()
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
    );
  }
}
