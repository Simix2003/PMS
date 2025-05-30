import 'package:flutter/material.dart';
import 'package:ix_monitor/pages/dashboard/dashboard_visual.dart';
import 'dart:ui';
import 'dart:math' as math;

import '../../shared/services/api_service.dart';
import '../dashboard/dashboard_data.dart';
import '../dashboard/dashboard_home.dart';
import '../dashboard/dashboard_stringatrice.dart';

class LoadingScreen extends StatefulWidget {
  final String targetPage;

  const LoadingScreen({super.key, required this.targetPage});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  double _loadingProgress = 0.0;

  // For animated background blobs
  final List<Blob> _blobs = List.generate(
    5,
    (index) => Blob(
      size: 150 + (index * 30),
      position: Offset(
        math.Random().nextDouble() * 400 - 100,
        math.Random().nextDouble() * 800 - 200,
      ),
      color: [
        const Color(0xFFE0F7FF),
        const Color(0xFFDBE9FF),
        const Color(0xFFD4C9FF),
        const Color(0xFFC9E7FF),
        const Color(0xFFDCFFE9),
      ][index],
    ),
  );

  @override
  void initState() {
    super.initState();

    // Animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    // Start animation
    _controller.forward();

    // Simulate loading progress
    _simulateLoading();

    // Animate background blobs
    _animateBlobs();
  }

  void _animateBlobs() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        for (var blob in _blobs) {
          blob.update();
        }
        setState(() {});
        _animateBlobs();
      }
    });
  }

  Future<void> _simulateLoading() async {
    const duration = Duration(seconds: 2);
    final start = DateTime.now();

    // Start line loading early
    final lineLoadFuture = ApiService.fetchLinesAndInitializeGlobals();

    // Animate progress
    while (DateTime.now().difference(start) < duration) {
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      if (mounted) {
        setState(() {
          _loadingProgress = elapsed / duration.inMilliseconds;
        });
      }
      await Future.delayed(const Duration(milliseconds: 16)); // ~60 FPS
    }

    // Ensure line data is ready before continuing
    await lineLoadFuture;

    if (mounted) {
      setState(() {
        _loadingProgress = 1.0;
      });

      switch (widget.targetPage) {
        case 'Home':
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardHome()),
          );
          break;
        case 'Data':
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardData()),
          );
          break;
        case 'Stringatrice':
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardStringatrice()),
          );
          break;
        case 'Visual':
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardVisual()),
          );
          break;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5F9FF),
              Color(0xFFEDF4FF),
              Color(0xFFE5F0FF),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background animated blobs
            Positioned.fill(
              child: CustomPaint(
                painter: BlobPainter(_blobs),
              ),
            ),

            // Subtle grid pattern
            Positioned.fill(
              child: CustomPaint(
                painter: GridPainter(),
              ),
            ),

            // Top right decorative element
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.blue.shade300.withOpacity(0.3),
                      Colors.blue.shade300.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom left decorative element
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.purple.shade200.withOpacity(0.3),
                      Colors.purple.shade200.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Main content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo and Title with Translucent Glass Effect
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 40, horizontal: 40),
                            width: size.width * 0.85,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.6),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 30,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // PMS Icon
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.blue.shade400,
                                        Colors.blue.shade600,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(26),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.shade300
                                            .withOpacity(0.5),
                                        blurRadius: 15,
                                        spreadRadius: 0,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.analytics_outlined,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 25),

                                // PMS Text with modern gradient
                                ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.blue.shade600,
                                      Colors.indigo.shade500,
                                      Colors.purple.shade500,
                                    ],
                                  ).createShader(bounds),
                                  child: const Text(
                                    "PMS",
                                    style: TextStyle(
                                      fontSize: 56,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: -1.0,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Full title
                                Text(
                                  "Production Monitoring System",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blueGrey.shade800,
                                    letterSpacing: 0.3,
                                  ),
                                ),

                                const SizedBox(height: 40),

                                // Loading progress
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                      maxWidth: size.width * 0.7),
                                  child: Column(
                                    children: [
                                      // Modern progress indicator
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.3),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Stack(
                                            children: [
                                              AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 200),
                                                width: (size.width * 0.7) *
                                                    _loadingProgress,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                    colors: [
                                                      Colors.blue.shade400,
                                                      Colors.blue.shade600,
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 30),

                                      // Modern floating DATA indicator
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.7),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 10,
                                              spreadRadius: 0,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.blue.shade600,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.blue.shade400
                                                        .withOpacity(0.5),
                                                    blurRadius: 6,
                                                    spreadRadius: 0,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            ShimmerTextGradient(
                                              text: widget.targetPage,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 2,
                                                color: Colors.blueGrey.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
          ],
        ),
      ),
    );
  }
}

// Blob class for animated background elements
class Blob {
  Offset position;
  double size;
  Color color;
  double directionX = math.Random().nextDouble() * 2 - 1;
  double directionY = math.Random().nextDouble() * 2 - 1;

  Blob({
    required this.position,
    required this.size,
    required this.color,
  });

  void update() {
    // Slow, subtle movement
    position = Offset(
      position.dx + directionX * 0.3,
      position.dy + directionY * 0.3,
    );

    // Change direction occasionally
    if (math.Random().nextDouble() < 0.01) {
      directionX = math.Random().nextDouble() * 2 - 1;
      directionY = math.Random().nextDouble() * 2 - 1;
    }
  }
}

// Blob painter
class BlobPainter extends CustomPainter {
  final List<Blob> blobs;

  BlobPainter(this.blobs);

  @override
  void paint(Canvas canvas, Size size) {
    for (var blob in blobs) {
      final paint = Paint()
        ..color = blob.color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(blob.position, blob.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Grid pattern painter (more subtle)
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.03)
      ..strokeWidth = 0.5;

    const double spacing = 40;

    // Draw vertical lines
    for (double i = 0; i <= size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    // Draw horizontal lines
    for (double i = 0; i <= size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Modern shimmer text with gradient effect
class ShimmerTextGradient extends StatefulWidget {
  final String text;
  final TextStyle style;

  const ShimmerTextGradient({
    Key? key,
    required this.text,
    required this.style,
  }) : super(key: key);

  @override
  State<ShimmerTextGradient> createState() => _ShimmerTextGradientState();
}

class _ShimmerTextGradientState extends State<ShimmerTextGradient>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        // Using the controller value directly instead of CurvedAnimation.evaluate
        final shimmerValue = _shimmerController.value;

        return Text(
          widget.text,
          style: widget.style.copyWith(
            foreground: Paint()
              ..shader = LinearGradient(
                colors: [
                  Colors.blueGrey.shade800,
                  Colors.blue.shade500,
                  Colors.blueGrey.shade800,
                ],
                stops: [0.0, shimmerValue, 1.0],
              ).createShader(const Rect.fromLTWH(0, 0, 150, 20)),
          ),
        );
      },
    );
  }
}
