// ignore_for_file: deprecated_member_use, must_be_immutable, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

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

class _ObjectCardState extends State<ObjectCard> with TickerProviderStateMixin {
  bool _isHoveringOK = false;
  bool _isHoveringKO = false;

  void _sendOutcome(BuildContext context, String outcome) async {
    HapticFeedback.mediumImpact();
    setState(() {
      widget.hasBeenEvaluated = false;
    });

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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Production Unit',
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
            ],
          ),

          const SizedBox(height: 16),

          // Status text
          Text(
            widget.hasBeenEvaluated
                ? (widget.isObjectOK ? "Status: Unità OK" : "Status: Unità KO")
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
                // KO Button
                Expanded(
                  child: _buildFlatButton(
                    label: "KO",
                    icon: Icons.close_rounded,
                    color: Colors.red,
                    onPressed: () => _sendOutcome(context, "scarto"),
                    isHovering: _isHoveringKO,
                    onHoverChanged: (value) =>
                        setState(() => _isHoveringKO = value),
                  ),
                ),
                const SizedBox(width: 12),
                // OK Button
                Expanded(
                  child: _buildFlatButton(
                    label: "OK",
                    icon: Icons.check_rounded,
                    color: Colors.green,
                    onPressed: () => _sendOutcome(context, "buona"),
                    isHovering: _isHoveringOK,
                    onHoverChanged: (value) =>
                        setState(() => _isHoveringOK = value),
                  ),
                ),
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
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
        label: Text(label, style: TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          elevation: isHovering ? 4 : 0,
        ),
      ),
    );
  }
}
