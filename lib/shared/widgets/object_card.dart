// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';

class ObjectCard extends StatefulWidget {
  final String objectNumber;
  final bool isObjectOK;
  final bool hasBeenEvaluated;
  final VoidCallback onReset;
  final void Function(bool isOk) onEvaluate;

  const ObjectCard({
    super.key,
    required this.objectNumber,
    required this.isObjectOK,
    required this.hasBeenEvaluated,
    required this.onReset,
    required this.onEvaluate,
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
                    widget.objectNumber,
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
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => widget.onEvaluate(true),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Pezzo OK'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => widget.onEvaluate(false),
                          icon: const Icon(Icons.error),
                          label: const Text('Pezzo Difettoso'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
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
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: widget.onReset,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Ricomincia Valutazione'),
                      ),
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
