// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../shared/services/api_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;

class _ChatMessage {
  final String role;
  final String content;
  final bool shimmer;

  _ChatMessage({
    required this.role,
    required this.content,
    this.shimmer = false,
  });
}

class AIHelperChat extends StatefulWidget {
  final void Function(String sqlQuery)? onQueryGenerated;

  const AIHelperChat({super.key, this.onQueryGenerated});

  @override
  State<AIHelperChat> createState() => _AIHelperChatState();
}

class _AIHelperChatState extends State<AIHelperChat> {
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> messages = [
    _ChatMessage(role: 'ai', content: 'Ciao, come posso aiutarti?'),
  ];

  bool _loading = true;
  bool _showButtons = false;
  bool _showShimmerExport = false;
  String _exportStatus = '';

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 1500), () {
      setState(() {
        messages.add(_ChatMessage(
          role: 'ai',
          content: 'Vuoi esportare i dati di ieri dalle 6 alle 5:59?',
        ));
        _loading = false;
        _showButtons = true;
      });
    });
  }

  void _handleResponse(bool accepted) async {
    setState(() {
      _showButtons = false;
      messages.add(_ChatMessage(role: 'user', content: accepted ? 'Sì' : 'No'));
    });

    await Future.delayed(const Duration(milliseconds: 600));

    if (!accepted) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      messages.add(_ChatMessage(
        role: 'ai',
        content: 'Va bene, faccio partire l\'esportazione!',
      ));
    });

    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _showShimmerExport = true;
      _exportStatus = 'Preparazione...';
    });

    final downloadUrl = await ApiService.exportDailyAndGetDownloadUrl(
      onProgress: (step, current, total) {
        setState(() {
          _exportStatus = _translateExportStep(step, current, total);
        });
      },
    );

    setState(() {
      _showShimmerExport = false;
      if (downloadUrl != null) {
        messages.add(_ChatMessage(role: 'ai', content: 'Esportazione completata!'));
        if (kIsWeb) html.window.open(downloadUrl, '_blank');
      } else {
        messages.add(_ChatMessage(role: 'ai', content: 'Errore durante l\'esportazione'));
      }
    });
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';
    final bubbleColor =
        isUser ? const Color(0xFF0A84FF) : Colors.white.withOpacity(0.15);
    final textColor = Colors.white;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.circular(20);
    final margin = isUser
        ? const EdgeInsets.only(left: 40, right: 12, top: 6, bottom: 6)
        : const EdgeInsets.only(left: 12, right: 40, top: 6, bottom: 6);

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          margin: margin,
          child: isUser
              ? Material(
                  color: bubbleColor,
                  borderRadius: radius,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      msg.content,
                      style: TextStyle(color: textColor, fontSize: 15),
                    ),
                  ),
                )
              : ClipRRect(
                  borderRadius: radius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        color: bubbleColor,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.0,
                        ),
                      ),
                      child: msg.shimmer
                          ? Shimmer.fromColors(
                              baseColor: Colors.white.withOpacity(0.4),
                              highlightColor: Colors.white.withOpacity(0.9),
                              child: Text(
                                msg.content,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : Text(
                              msg.content,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildShimmerBubble({String? text}) {
    final child = text != null
        ? Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          )
        : const SizedBox(height: 20, width: 250);

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 40, top: 6, bottom: 6),
      child: Shimmer.fromColors(
        baseColor: Colors.white.withOpacity(0.15),
        highlightColor: Colors.white.withOpacity(0.3),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildYesNoButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade400,
              foregroundColor: Colors.white,
              minimumSize: const Size(160, 60), // Bigger button
              textStyle:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => _handleResponse(true),
            child: const Text("Sì"),
          ),
          const SizedBox(width: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              minimumSize: const Size(160, 60),
              textStyle:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => _handleResponse(false),
            child: const Text("No"),
          ),
        ],
      ),
    );
  }

  String _translateExportStep(String step, int? current, int? total) {
    if (step.startsWith('creating:')) {
      final sheet = step.split(':').last;
      final base = 'Creazione foglio $sheet...';
      if (current != null && total != null) {
        return '$current/$total - $base';
      }
      return base;
    }
    if (step.startsWith('finished:')) {
      final sheet = step.split(':').last;
      final base = 'Completato foglio $sheet';
      if (current != null && total != null) {
        return '$current/$total - $base';
      }
      return base;
    }
    const mapping = {
      'init': 'Preparazione...',
      'start_sheets': 'Inizio creazione fogli...',
      'db_connect': 'Connessione al database...',
      'objects': 'Caricamento oggetti...',
      'productions': 'Caricamento produzioni...',
      'defects': 'Caricamento difetti...',
      'excel': 'Generazione Excel...',
      'saving': 'Salvataggio file...',
      'done': 'Completato.'
    };
    final base = mapping[step] ?? step;
    if (current != null && total != null) {
      return '$current/$total - $base';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 1500,
            height: 700,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withOpacity(0.6),
                  Colors.purple.withOpacity(0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            ),
            child: Column(
              children: [
                // ── HEADER ──────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                          color: Colors.white.withOpacity(0.1), width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.auto_awesome,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Mini Bro (Beta)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── CHAT ───────────────────────────────
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.withOpacity(0.05),
                          Colors.purple.withOpacity(0.05),
                        ],
                      ),
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: messages.length +
                          (_loading ? 1 : 0) +
                          (_showShimmerExport ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_loading && index == messages.length) {
                          return _buildShimmerBubble();
                        } else if (_showShimmerExport &&
                            index == messages.length + (_loading ? 1 : 0)) {
                          return _buildShimmerBubble(text: _exportStatus);
                        } else {
                          return _buildMessageBubble(messages[index]);
                        }
                      },
                    ),
                  ),
                ),

                // ── BUTTONS or EMPTY ─────────────────────
                _showButtons ? _buildYesNoButtons() : const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
