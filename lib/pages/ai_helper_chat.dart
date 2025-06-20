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
  final String? downloadUrl; // <-- add this

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

  @override
  void initState() {
    super.initState();

    messages.add(_ChatMessage(role: 'ai', content: '', shimmer: true));

    Future.delayed(const Duration(milliseconds: 1000), () {
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

  void _handleResponse(bool accepted) async {
    setState(() {
      _showButtons = false;
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

    // 1. Add shimmer message FIRST and remember its index
    int progressIndex = -1;

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
      final translated = _translateExportStep(step, current, total);
      final isFinal = translated.trim().toLowerCase().contains("completato");

      if (progressIndex != -1) {
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
    });

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
                                  "  ${msg.content}",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : msg.downloadUrl != null
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.insert_drive_file,
                                          size: 18, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text(
                                        msg.content,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          if (kIsWeb) {
                                            final anchor = html.AnchorElement(
                                                href: msg.downloadUrl!)
                                              ..target = '_blank'
                                              ..download = msg.content;
                                            anchor.click();
                                          }
                                        },
                                        icon: const Icon(Icons.download,
                                            size: 16),
                                        label: const Text("Scarica"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.white.withOpacity(0.2),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          textStyle:
                                              const TextStyle(fontSize: 13),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      )
                                    ],
                                  )
                                : Text(
                                    msg.content,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 15,
                                    ),
                                  )),
                  ),
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
            style: _buttonStyle(Colors.green),
            child: const Text("📅 Dati di ieri"),
          ),
          ElevatedButton(
            onPressed: () => _handleExportOption("weekly"),
            style: _buttonStyle(Colors.orange),
            child: const Text("📆 Settimana scorsa"),
          ),
          ElevatedButton(
            onPressed: () => _handleExportOption("monthly"),
            style: _buttonStyle(Colors.purple),
            child: const Text("🗓️ Ultimo mese"),
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
      setState(() {
        messages.add(_ChatMessage(
          role: 'ai',
          content: '❌ Questo tipo di esportazione non è ancora disponibile.',
        ));
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
        return "Esporta l’ultimo mese";
      default:
        return "Esporta dati";
    }
  }

  ButtonStyle _buttonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      minimumSize: const Size(220, 60),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      itemCount: messages.length,
                      itemBuilder: (context, index) =>
                          _buildMessageBubble(messages[index]),
                    ),
                  ),
                ),

                // ── BUTTONS or EMPTY ─────────────────────
                _showButtons ? _buildExportButtons() : const SizedBox.shrink()
              ],
            ),
          ),
        ),
      ),
    );
  }
}
