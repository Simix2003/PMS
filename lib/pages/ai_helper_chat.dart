// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../shared/services/api_service.dart';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

class _ChatMessage {
  final String role;
  final String content;
  final bool shimmer;
  final String? downloadUrl;

  _ChatMessage({
    required this.role,
    required this.content,
    this.shimmer = false,
    this.downloadUrl,
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

  final List<_ChatMessage> messages = [];

  bool _showButtons = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    messages.add(_ChatMessage(role: 'ai', content: '', shimmer: true));

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted || _disposed) return;

      setState(() {
        messages.removeWhere((m) => m.shimmer);
        messages.add(_ChatMessage(
          role: 'ai',
          content: 'Come posso aiutarti? Scegli un\'opzione qui sotto:',
        ));
        _showButtons = true;
      });
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  void _handleResponse(bool accepted) async {
    if (!mounted) return;

    setState(() {
      _showButtons = false;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    if (!accepted) {
      if (mounted) Navigator.pop(context);
      return;
    }

    if (!mounted) return;
    setState(() {
      messages.add(_ChatMessage(
        role: 'ai',
        content: 'Va bene, faccio partire l\'esportazione!',
      ));
    });

    await Future.delayed(const Duration(milliseconds: 800));

    int progressIndex = -1;

    if (!mounted) return;
    setState(() {
      messages.add(_ChatMessage(
        role: 'ai',
        content: '⏳ Inizio esportazione...',
        shimmer: true,
      ));
      progressIndex = messages.length - 1;
    });

    final downloadUrl = await ApiService.exportDailyAndGetDownloadUrl(
      onProgress: (step, current, total) {
        if (!mounted) return;

        final translated = _translateExportStep(step, current, total);
        final isFinal = translated.trim().toLowerCase().contains("completato");

        if (progressIndex != -1 && mounted) {
          setState(() {
            messages[progressIndex] = _ChatMessage(
              role: 'ai',
              content: translated,
              shimmer: !isFinal,
            );
          });

          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      },
    );

    if (!mounted) return;
    setState(() {
      if (downloadUrl != null) {
        final fileName = downloadUrl.split('/').last;
        messages.add(_ChatMessage(
          role: 'ai',
          content: fileName,
          downloadUrl: downloadUrl,
        ));
      } else {
        messages.add(_ChatMessage(
            role: 'ai', content: 'Errore durante l\'esportazione'));
      }
    });
  }

  Widget _buildMessageContent(_ChatMessage msg, Color textColor) {
    if (msg.downloadUrl != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, size: 18, color: textColor),
          const SizedBox(width: 8),
          Text(
            msg.content,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              if (kIsWeb && msg.downloadUrl != null) {
                final anchor = html.AnchorElement(href: msg.downloadUrl!)
                  ..target = '_blank'
                  ..download = msg.content;
                anchor.click();
              }
            },
            icon: const Icon(Icons.download, size: 16, color: Colors.white),
            label: const Text("Scarica"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ],
      );
    } else {
      return Text(
        msg.content,
        style: TextStyle(color: textColor, fontSize: 15),
      );
    }
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';
    final bubbleColor =
        isUser ? const Color(0xFF2563EB) : const Color(0xFFF8FAFC);
    final textColor = isUser ? Colors.white : const Color(0xFF1E293B);
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.circular(16);
    final margin = isUser
        ? const EdgeInsets.only(left: 40, right: 16, top: 6, bottom: 6)
        : const EdgeInsets.only(left: 16, right: 40, top: 6, bottom: 6);

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          margin: margin,
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: isUser
                ? null
                : Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: (msg.shimmer && mounted && !_disposed)
                ? Shimmer.fromColors(
                    baseColor: const Color(0xFF94A3B8),
                    highlightColor: const Color(0xFF64748B),
                    child: Text(
                      "  ${msg.content}",
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : _buildMessageContent(msg, textColor),
          ),
        ),
      ],
    );
  }

  Widget _buildExportButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          ElevatedButton(
            onPressed: () => _handleExportOption("daily"),
            style: _buttonStyle(const Color(0xFF059669)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text("Esporta i dati di ieri"),
                SizedBox(height: 4),
                Text(
                  "dalle 06:00 alle 05:59 del giorno dopo",
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _handleExportOption("weekly"),
            style: _buttonStyle(const Color(0xFFEA580C)),
            child: const Text("Esporta i dati della settimana scorsa"),
          ),
          ElevatedButton(
            onPressed: () => _handleExportOption("monthly"),
            style: _buttonStyle(const Color(0xFF7C3AED)),
            child: const Text("Esporta i dati del mese scorso"),
          ),
        ],
      ),
    );
  }

  void _handleExportOption(String type) {
    setState(() {
      _showButtons = false;
      messages.add(_ChatMessage(role: 'user', content: _labelForType(type)));
    });

    if (type == "daily") {
      _handleResponse(true); // existing logic
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted || _disposed) return;

        setState(() {
          messages.add(_ChatMessage(
            role: 'ai',
            content:
                '😔 Scusami, non sono ancora in grado di eseguire questa esportazione',
          ));
        });

        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted || _disposed) return;

          setState(() {
            messages.add(_ChatMessage(
              role: 'ai',
              content: 'Posso aiutarti in qualche altro modo?',
            ));
            _showButtons = true;
          });
        });
      });
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case "daily":
        return "Esporta i dati di ieri";
      case "weekly":
        return "Esporta la settimana scorsa";
      case "monthly":
        return "Esporta l'ultimo mese";
      default:
        return "Esporta dati";
    }
  }

  ButtonStyle _buttonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      minimumSize: const Size(220, 54),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      shadowColor: Colors.transparent,
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
        return '  $current/$total - $base';
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
      return ' $current/$total - $base';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.auto_awesome,
                                color: Color(0xFF3B82F6), size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Assistente Simix (Beta)',
                            style: TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Color(0xFF64748B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close,
                              color: Color(0xFF64748B), size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── CHAT ───────────────────────────────
                Expanded(
                  child: Container(
                    color: Colors.transparent,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) =>
                          _buildMessageBubble(messages[index]),
                    ),
                  ),
                ),

                // ── BUTTONS or EMPTY ─────────────────────
                _showButtons
                    ? Container(
                        child: _buildExportButtons(),
                      )
                    : const SizedBox.shrink()
              ],
            ),
          ),
        ),
      ),
    );
  }
}
