// ignore_for_file: deprecated_member_use, must_be_immutable

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ObjectCard extends StatefulWidget {
  final String objectId;
  bool isObjectOK;
  bool hasBeenEvaluated;
  String selectedChannel;

  ObjectCard({
    super.key,
    required this.objectId,
    required this.isObjectOK,
    required this.hasBeenEvaluated,
    required this.selectedChannel,
  });

  @override
  State<ObjectCard> createState() => _ObjectCardState();
}

class _ObjectCardState extends State<ObjectCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    if (!widget.hasBeenEvaluated) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ObjectCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasBeenEvaluated != oldWidget.hasBeenEvaluated) {
      if (!widget.hasBeenEvaluated) {
        _animationController.repeat();
      } else {
        _animationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getBorderColor() {
    if (!widget.hasBeenEvaluated) {
      final value = math.sin(_animationController.value * math.pi * 2);
      final intensity = (value + 1) / 2;
      return Color.lerp(
        Colors.yellow.shade400,
        Colors.yellow.shade700,
        intensity,
      )!;
    } else {
      return widget.isObjectOK ? Colors.green : Colors.red;
    }
  }

  void _sendOutcome(BuildContext context, String outcome) async {
    final response = await http.post(
      Uri.parse('http://192.168.1.132:8000/api/set_outcome'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "channel_id": widget.selectedChannel,
        "object_id": widget.objectId,
        "outcome": outcome,
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        widget.hasBeenEvaluated = true;
        widget.isObjectOK = (outcome == "buona");
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore nel mandare l'esito al PLC")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _getBorderColor().withOpacity(0.6),
                blurRadius: 10,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Card(
            elevation: 4,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _getBorderColor(),
                width: 2.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pezzo in Produzione:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.objectId,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!widget.hasBeenEvaluated) ...[
                    const Text(
                      'Stato: In valutazione',
                      style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Stato: ${widget.isObjectOK ? 'Pezzo OK' : 'Pezzo Difettoso'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.isObjectOK ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                  if (!widget.hasBeenEvaluated) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // KO Button (LEFT)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _sendOutcome(context, "scarto"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "KO",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // OK Button (RIGHT)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _sendOutcome(context, "buona"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "OK",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
