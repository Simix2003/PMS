import 'package:flutter/material.dart';
import 'solarPanelNew.dart';

class ShimmerPanelReveal extends StatefulWidget {
  final DistancesSolarPanelWidget panel;

  const ShimmerPanelReveal({super.key, required this.panel});

  @override
  State<ShimmerPanelReveal> createState() => _ShimmerPanelRevealState();
}

class _ShimmerPanelRevealState extends State<ShimmerPanelReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _animationDone = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Wait one frame before switching to plain panel
        setState(() {
          _animationDone = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_animationDone) {
      return widget.panel; // Fully visible after shimmer
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;

        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [progress - 0.2, progress],
              colors: [
                Colors.white,
                Colors.transparent,
              ],
            ).createShader(rect);
          },
          blendMode: BlendMode.dstIn,
          child: widget.panel,
        );
      },
    );
  }
}
