import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class IssueSelectorWidget extends StatefulWidget {
  final String channelId;
  final Function(String fullPath) onIssueSelected;

  const IssueSelectorWidget({
    super.key,
    required this.channelId,
    required this.onIssueSelected,
  });

  @override
  IssueSelectorWidgetState createState() => IssueSelectorWidgetState();
}

class IssueSelectorWidgetState extends State<IssueSelectorWidget>
    with TickerProviderStateMixin {
  List<String> pathStack = ["Dati.Esito.Esito_Scarto.Difetti"];
  List<dynamic> currentItems = [];
  Map<int, bool> hoverStates = {};
  Set<String> selectedPaths = {};
  late AnimationController _loadingController;
  bool isLoading = true;
  late AnimationController _pulseController;
  String? _currentIP;
  String? _currentPort;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fetchCurrentPath();
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('backend_ip');
    final port = prefs.getString('backend_port');
    setState(() {
      _currentIP = ip ?? '192.168.0.100';
      _currentPort = port ?? '8000';
    });
  }

  Future<void> _fetchCurrentPath() async {
    setState(() {
      isLoading = true;
    });

    final currentPath = pathStack.join(".");
    final url = Uri.parse(
        'http://$_currentIP:$_currentPort/api/issues/${widget.channelId}?path=$currentPath');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          currentItems = data['items'];
          isLoading = false;
        });
      } else {
        setState(() {
          currentItems = [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        currentItems = [];
        isLoading = false;
      });
    }
  }

  void _goDeeper(String folderName) {
    setState(() {
      pathStack.add(folderName);
      hoverStates.clear();
    });
    _fetchCurrentPath();
  }

  void _goBack() {
    if (pathStack.length > 1) {
      setState(() {
        pathStack.removeLast();
        hoverStates.clear();
      });
      _fetchCurrentPath();
    }
  }

  bool _isHighlighted(String folderName) {
    final folderPath = [...pathStack, folderName].join(".");
    return selectedPaths.any((p) => p.startsWith(folderPath));
  }

  Widget _buildImageForLevel() {
    final currentFolder = pathStack.isNotEmpty ? pathStack.last : 'default';

    // Normalize folder name to asset file naming convention
    final folderImageName =
        currentFolder.split('.').last.toLowerCase().replaceAll(' ', '_');

    return Image.asset(
      '/images/$folderImageName.jpg',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset('assets/images/default.jpg', fit: BoxFit.cover);
      },
    );
  }

  void resetSelection() {
    setState(() {
      selectedPaths.clear();
    });
  }

  void restoreSelection(List<String> issues) {
    print("🔄 Restoring selection for issues: $issues");
    setState(() {
      selectedPaths = issues.toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = pathStack.join(".");

    return Row(
      children: [
        // LEFT SIDE - Selector
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Navigation Bar
                Row(
                  children: [
                    if (pathStack.length > 1)
                      IconButton(
                        icon:
                            const Icon(Icons.arrow_back, color: Colors.black87),
                        onPressed: _goBack,
                      ),
                    Expanded(
                      child: Text(
                        currentPath,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                isLoading
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: CircularProgressIndicator(
                              color: Colors.blueAccent),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true, // <== important to add!
                        itemCount: currentItems.length,
                        itemBuilder: (context, index) {
                          final item = currentItems[index];
                          final isFolder = item['type'] == 'folder';
                          final fullPath = "$currentPath.${item['name']}";
                          final isSelected = selectedPaths.contains(fullPath);
                          final isParentHighlighted =
                              _isHighlighted(item['name']);

                          return MouseRegion(
                            onEnter: (_) =>
                                setState(() => hoverStates[index] = true),
                            onExit: (_) =>
                                setState(() => hoverStates[index] = false),
                            child: GestureDetector(
                              onTap: () {
                                if (isFolder) {
                                  _goDeeper(item['name']);
                                } else {
                                  setState(() {
                                    if (isSelected) {
                                      selectedPaths.remove(fullPath);
                                    } else {
                                      selectedPaths.add(fullPath);
                                    }
                                    widget.onIssueSelected(fullPath);
                                  });
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isSelected || isParentHighlighted
                                      ? Colors.blue.withOpacity(0.05)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected || isParentHighlighted
                                        ? Colors.blueAccent
                                        : Colors.grey.shade300,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (isFolder)
                                      Icon(
                                        Icons.folder,
                                        color: isParentHighlighted
                                            ? Colors.blueAccent
                                            : Colors.blueGrey,
                                      )
                                    else
                                      Checkbox(
                                        value: isSelected,
                                        onChanged: (checked) {
                                          setState(() {
                                            if (checked == true) {
                                              selectedPaths.add(fullPath);
                                            } else {
                                              selectedPaths.remove(fullPath);
                                            }
                                            widget.onIssueSelected(fullPath);
                                          });
                                        },
                                        activeColor: Colors.blueAccent,
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        item['name'],
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (isFolder)
                                      const Icon(Icons.chevron_right,
                                          color: Colors.blueGrey),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 16),

        // RIGHT SIDE - Image/Preview panel
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade100,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(
                    maxHeight: 475,
                    maxWidth: double.infinity,
                  ),
                  child: _buildImageForLevel(),
                ),
              ),
            ),
          ),
        )
      ],
    );
  }
}
