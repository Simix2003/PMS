import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mesh/mesh.dart';

class AIReportGeneratorDialog extends StatefulWidget {
  final Future<String> Function() onGenerateReport;

  const AIReportGeneratorDialog({
    super.key,
    required this.onGenerateReport,
  });

  @override
  State<AIReportGeneratorDialog> createState() =>
      _AIReportGeneratorDialogState();
}

class _AIReportGeneratorDialogState extends State<AIReportGeneratorDialog>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _scaleController;

  bool _isGenerating = false;
  String _currentStep = '';
  String? _generatedReport;
  String? _error;

  final List<String> _generationSteps = [
    'Inizializzazione AI...',
    'Analisi dati turno...',
    'Elaborazione statistiche...',
    'Generazione insights...',
    'Finalizzazione report...',
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _generateReport() async {
    setState(() {
      _isGenerating = true;
      _generatedReport = null;
      _error = null;
    });

    // Start animations
    _pulseController.repeat();
    _rotationController.repeat();
    _scaleController.forward();

    try {
      // Simulate step-by-step generation
      for (int i = 0; i < _generationSteps.length; i++) {
        setState(() {
          _currentStep = _generationSteps[i];
        });
        await Future.delayed(Duration(milliseconds: 800 + (i * 200)));
      }

      // Call the actual report generation
      final report = await widget.onGenerateReport();

      setState(() {
        _generatedReport = report;
        _currentStep = 'Report generato con successo!';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _currentStep = 'Errore nella generazione';
      });
    } finally {
      // Stop animations
      _pulseController.stop();
      _rotationController.stop();
      _scaleController.reverse();

      setState(() {
        _isGenerating = false;
      });
    }
  }

  Widget _buildLoadingAnimation() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _rotationController]),
      builder: (context, child) {
        return Container(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer rotating gradient ring
              Transform.rotate(
                angle: _rotationController.value * 2 * math.pi,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Colors.blue.withOpacity(0.8),
                        Colors.purple.withOpacity(0.8),
                        Colors.pink.withOpacity(0.8),
                        Colors.orange.withOpacity(0.8),
                        Colors.blue.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
              ),

              // Middle pulsing layer
              ScaleTransition(
                scale: Tween<double>(
                  begin: 0.8,
                  end: 1.2,
                ).animate(CurvedAnimation(
                  parent: _pulseController,
                  curve: Curves.easeInOut,
                )),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Inner core with mesh gradient
              Container(
                width: 100,
                height: 100,
                child: ClipOval(
                  child: OMeshGradient(
                    tessellation: 8,
                    size: const Size(100, 100),
                    mesh: OMeshRect(
                      width: 3,
                      height: 3,
                      vertices: [
                        // Dynamic vertices that change with animation
                        DoubleDoubleToOVertex((0.0, 0.0)).v,
                        NumNumToOVertex((
                          0.5 +
                              0.1 *
                                  math.sin(
                                      _pulseController.value * 2 * math.pi),
                          0.0
                        )).v,
                        NumNumToOVertex((1.0, 0.0)).v,
                        DoubleDoubleToOVertex((
                          0.0,
                          0.5 +
                              0.1 *
                                  math.cos(_pulseController.value * 2 * math.pi)
                        )).v,
                        DoubleDoubleToOVertex((0.5, 0.5)).v,
                        DoubleDoubleToOVertex((
                          1.0,
                          0.5 -
                              0.1 *
                                  math.sin(_pulseController.value * 2 * math.pi)
                        )).v,
                        NumNumToOVertex((0.0, 1.0)).v,
                        DoubleDoubleToOVertex((
                          0.5 -
                              0.1 *
                                  math.cos(
                                      _pulseController.value * 2 * math.pi),
                          1.0
                        )).v,
                        DoubleDoubleToOVertex((1.0, 1.0)).v,
                      ],
                      colors: [
                        Colors.blue.withOpacity(0.9),
                        Colors.purple.withOpacity(0.8),
                        Colors.pink.withOpacity(0.9),
                        Colors.cyan.withOpacity(0.8),
                        Colors.white.withOpacity(0.9),
                        Colors.orange.withOpacity(0.8),
                        Colors.indigo.withOpacity(0.9),
                        Colors.amber.withOpacity(0.8),
                        Colors.teal.withOpacity(0.9),
                      ],
                    ),
                  ),
                ),
              ),

              // AI icon in center
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepIndicator() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        _currentStep,
        key: ValueKey(_currentStep),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Success animation
        ScaleTransition(
          scale: _scaleController,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.8),
                  Colors.teal.withOpacity(0.8),
                ],
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),

        const SizedBox(height: 24),

        const Text(
          'Report Generato!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 16),

        if (_generatedReport != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              _generatedReport!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Action buttons
        Row(
          children: [
            Expanded(
              child: _buildGlassButton(
                'Chiudi',
                Icons.close_rounded,
                () => Navigator.of(context).pop(),
                isPrimary: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGlassButton(
                'Condividi',
                Icons.share_rounded,
                () {
                  // Handle share functionality
                  Navigator.of(context).pop(_generatedReport);
                },
                isPrimary: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.red.withOpacity(0.8),
                Colors.pink.withOpacity(0.8),
              ],
            ),
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),

        const SizedBox(height: 24),

        const Text(
          'Errore nella Generazione',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 16),

        if (_error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              _error!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Action buttons
        Row(
          children: [
            Expanded(
              child: _buildGlassButton(
                'Chiudi',
                Icons.close_rounded,
                () => Navigator.of(context).pop(),
                isPrimary: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGlassButton(
                'Riprova',
                Icons.refresh_rounded,
                _generateReport,
                isPrimary: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassButton(
    String text,
    IconData icon,
    VoidCallback onPressed, {
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isPrimary
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withOpacity(0.6),
                  Colors.purple.withOpacity(0.5),
                  Colors.pink.withOpacity(0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
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
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'AI Report Generator',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!_isGenerating)
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
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

                  const SizedBox(height: 32),

                  // Content based on state
                  if (_isGenerating) ...[
                    _buildLoadingAnimation(),
                    const SizedBox(height: 24),
                    _buildStepIndicator(),
                  ] else if (_generatedReport != null) ...[
                    _buildSuccessView(),
                  ] else if (_error != null) ...[
                    _buildErrorView(),
                  ] else ...[
                    // Initial state
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.withOpacity(0.8),
                            Colors.purple.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Genera Report Turno',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'L\'AI analizzerà i dati del turno e genererà un report dettagliato con insights e statistiche.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Generate button
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _generateReport,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.withOpacity(0.8),
                                  Colors.purple.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Genera Report',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
