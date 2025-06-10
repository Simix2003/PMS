// ignore_for_file: deprecated_member_use, must_be_immutable, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'AI.dart';

class ObjectCard extends StatefulWidget {
  final String objectId;
  final String stringatrice;
  bool isObjectOK;
  bool hasBeenEvaluated;
  String selectedLine;
  String selectedChannel;
  final bool issuesSubmitted;
  final Function(List<String>) onIssuesLoaded;
  bool reWork;

  ObjectCard({
    super.key,
    required this.objectId,
    required this.stringatrice,
    required this.isObjectOK,
    required this.hasBeenEvaluated,
    required this.selectedLine,
    required this.selectedChannel,
    required this.issuesSubmitted,
    required this.onIssuesLoaded,
    required this.reWork,
  });

  @override
  State<ObjectCard> createState() => _ObjectCardState();
}

class _ObjectCardState extends State<ObjectCard> with TickerProviderStateMixin {
  bool _isHoveringKO = false;
  String? estimatedFixTime; // Example: "7 min"

  void _sendOutcome(BuildContext context, String outcome) async {
    HapticFeedback.mediumImpact();
    setState(() {
      widget.hasBeenEvaluated = true;
    });

    final success = await ApiService.sendObjectOutcome(
        lineName: widget.selectedLine,
        channelId: widget.selectedChannel,
        objectId: widget.objectId,
        outcome: outcome,
        rework: widget.reWork);

    if (success) {
      setState(() {
        widget.hasBeenEvaluated = true;
        widget.isObjectOK = (outcome == "buona");
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text("Errore nel mandare l'esito al PLC"),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      setState(() {
        widget.hasBeenEvaluated = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.reWork) {
      _fetchETAPrediction();
    }
  }

  Future<void> _fetchETAPrediction() async {
    final etaInfo = await ApiService.predictReworkETAByObject(widget.objectId);
    if (etaInfo != null) {
      estimatedFixTime = etaInfo['eta_min'].toString();
      print("ETA: ${etaInfo['eta_min']} min (${etaInfo['samples']} samples)");
    } else {
      estimatedFixTime = null;
      print("No ETA available for this module.");
    }
  }

  @override
  Widget build(BuildContext context) {
    Color? glowColor;
    if (widget.hasBeenEvaluated) {
      glowColor = widget.isObjectOK ? Colors.green : Colors.red;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: glowColor ?? Colors.grey.shade300,
          width: 3,
        ),
        boxShadow: glowColor != null
            ? [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.reWork &&
              !widget.hasBeenEvaluated &&
              estimatedFixTime != null)
            ShimmerRevealETA(estimatedFixTime: estimatedFixTime!),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side: Object info
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modulo:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.memory, color: Colors.blueGrey, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        widget.objectId,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Right side: Da stringatrice
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "Da stringatrice:",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.stringatrice,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Status text
          Text(
            widget.hasBeenEvaluated
                ? (widget.isObjectOK ? "Status: Modulo G" : "Status: Modulo NG")
                : "Status: Attesa validazione",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),

          if (!widget.hasBeenEvaluated) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildFlatButton(
                    label: widget.reWork
                        ? "Controlla Difetti del Modulo"
                        : "Inserisci Difetti del Modulo",
                    icon: Icons.close_rounded,
                    color: widget.reWork ? Colors.yellow.shade800 : Colors.red,
                    onPressed: () => _sendOutcome(context, "scarto"),
                    isHovering: _isHoveringKO,
                    onHoverChanged: (value) =>
                        setState(() => _isHoveringKO = value),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFlatButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required bool isHovering,
    required Function(bool) onHoverChanged,
  }) {
    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          elevation: isHovering ? 4 : 0,
        ),
        child: Text(label, style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
    );
  }
}
