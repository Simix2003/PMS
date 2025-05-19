// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class AIHelperChat extends StatefulWidget {
  final void Function(String sqlQuery)? onQueryGenerated;

  const AIHelperChat({super.key, this.onQueryGenerated});

  @override
  State<AIHelperChat> createState() => _AIHelperChatState();
}

class _AIHelperChatState extends State<AIHelperChat> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> messages = [
    _ChatMessage(role: 'ai', content: 'Ciao, come posso aiutarti?'),
  ];

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add(_ChatMessage(role: 'user', content: text));
      messages.add(_ChatMessage(role: 'ai', content: 'Sto elaborando...'));
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final history = messages
          .where((m) => m.role != 'ai' || m.content != 'Sto elaborando...')
          .take(6) // limit to last 6 entries (optional)
          .map((m) => {
                'role': m.role == 'ai' ? 'assistant' : 'user',
                'content': m.content,
              })
          .toList();

      final response = await http.post(
        Uri.parse('http://localhost:8001/api/chat_query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': text,
          'history': history,
        }),
      );

      final data = jsonDecode(response.body);
      final answer =
          data['response']?.toString() ?? 'Errore nella risposta AI.';

      setState(() {
        messages.removeLast(); // remove "Sto elaborando..."
        messages.add(_ChatMessage(role: 'ai', content: answer));
      });

      _scrollToBottom();

      final regex = RegExp(r'```sql\s*([\s\S]*?)```');
      final match = regex.firstMatch(answer);

      if (match != null) {
        final sqlQuery = match.group(1)?.trim();

        if (sqlQuery != null && sqlQuery.toLowerCase().startsWith('select')) {
          widget.onQueryGenerated?.call(sqlQuery); // ✅ Send clean query back
          Navigator.of(context).pop(); // ✅ Close the dialog
        }
      }
    } catch (e) {
      setState(() {
        messages.removeLast();
        messages.add(_ChatMessage(role: 'ai', content: 'Errore: $e'));
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';

    // Apple Intelligence style - glass effect for AI responses, solid for user
    final bubbleColor = isUser
        ? const Color(0xFF0A84FF) // Apple blue for user messages
        : Colors.white.withOpacity(0.15); // Translucent white for AI

    final textColor = isUser
        ? Colors.white // White text for user messages
        : Colors.white; // White text for AI messages

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
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                      ),
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
                      child: Text(
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
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                // Glassmorphism Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
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
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 20,
                            ),
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
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Chat area with gradient background
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
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(messages[index]);
                      },
                    ),
                  ),
                ),

                // Glassmorphism Input area
                ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _controller,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Chiedi qualcosa...',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _sendMessage,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0A84FF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String role; // 'user' or 'ai'
  final String content;

  _ChatMessage({required this.role, required this.content});
}
