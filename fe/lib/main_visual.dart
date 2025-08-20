// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'pages/loading_Screen/loading_screen.dart';

/// 🔒 Allowed zones (add/remove as needed)
const Set<String> kAllowedZones = {
  'AIN',
  'ELL',
  'VPF',
  'STR',
  'LMN',
  'DELTAMAX'
};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT');

  // 🌍 Read first path segment and normalize
  final uri = html.window.location;
  final segs = uri.pathname!.split('/')
    ..removeWhere((e) => e.isNotEmpty == false);
  final raw = segs.isNotEmpty ? segs.first : null;
  final zone = (raw ?? '').toUpperCase();

  // If zone missing or not allowed → show landing; otherwise boot directly into zone
  final startZone = kAllowedZones.contains(zone) ? zone : null;

  // Clean URL to "/" when invalid/missing
  if (startZone == null && (uri.pathname != '/' && uri.pathname!.isNotEmpty)) {
    html.window.history.replaceState(null, '', '/');
  }

  runApp(MyApp(zone: startZone));
}

class MyApp extends StatelessWidget {
  final String? zone;
  const MyApp({super.key, required this.zone});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0A84FF), // iOS blue
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PMS — Production Monitoring System',
      locale: const Locale('it', 'IT'),
      supportedLocales: const [Locale('it', 'IT')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        fontFamily: 'Roboto',
        textTheme: Typography.blackCupertino,
        scaffoldBackgroundColor: const Color(0xFFF8FAFF),
      ),
      home: zone == null
          ? const ZonePickerHome()
          : LoadingScreen(targetPage: 'Visual', zone: zone!),
    );
  }
}

class ZonePickerHome extends StatelessWidget {
  const ZonePickerHome({super.key});

  void _goToZone(BuildContext context, String zone) {
    html.window.history.replaceState(null, '', '/$zone');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoadingScreen(targetPage: 'Visual', zone: zone),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zones = kAllowedZones.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.8),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            // Mini “pill” logo
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A84FF), Color(0xFF64D2FF)],
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'PMS — Production Monitoring System',
              style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          // 🎨 Background gradient “soft light”
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF6F9FF), // very light blue
                  Color(0xFFF0F4FF),
                  Color(0xFFEFF3FA),
                ],
              ),
            ),
          ),
          // Vignette delicata
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [
                  Colors.white.withOpacity(0.6),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),

          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _PageTitle(),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      spacing: 18,
                      runSpacing: 18,
                      children: [
                        for (final z in zones)
                          _ZoneCard(
                            label: z,
                            icon: _iconFor(z),
                            accent: _accentFor(z),
                            onTap: () => _goToZone(context, z),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _Footer(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Titolo chiaro, leggibile, “Apple‑ish”
class _PageTitle extends StatelessWidget {
  const _PageTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Seleziona Zona',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Accedi rapidamente alle aree di produzione',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.black.withOpacity(0.58),
                fontWeight: FontWeight.w400,
              ),
        ),
      ],
    );
  }
}

/// Card “frosted glass” chiara: blur, bordo sottile, lieve ombra.
/// Hover: solleva leggermente + aumenta contrasto.
class _ZoneCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _ZoneCard({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_ZoneCard> createState() => _ZoneCardState();
}

class _ZoneCardState extends State<_ZoneCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    const baseWidth = 220.0;
    const baseHeight = 130.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: baseWidth,
          height: baseHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.black.withOpacity(_hover ? 0.10 : 0.08),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(_hover ? 0.85 : 0.80),
                Colors.white.withOpacity(_hover ? 0.70 : 0.65),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color:
                    const Color(0xFF93A5BF).withOpacity(_hover ? 0.25 : 0.18),
                blurRadius: _hover ? 22 : 14,
                offset: const Offset(0, 10),
              ),
              // edge glow laterale con colore di accento
              BoxShadow(
                color: widget.accent.withOpacity(_hover ? 0.18 : 0.12),
                blurRadius: _hover ? 26 : 18,
                spreadRadius: 0,
                offset: const Offset(6, 0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Frosted blur
                BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: const SizedBox.expand(),
                ),
                // Highlight tenue
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.30),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: widget.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            widget.icon,
                            size: 28,
                            color: Colors.black.withOpacity(0.80),
                          ),
                          const Spacer(),
                          Text(
                            widget.label,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.0,
                                  color: Colors.black.withOpacity(0.92),
                                ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Entra',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: Colors.black.withOpacity(0.60),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.arrow_forward_ios,
                                  size: 14,
                                  color: Colors.black.withOpacity(0.55)),
                            ],
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

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.8,
      child: Text(
        '© ${DateTime.now().year} PMS — Production Monitoring System',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black.withOpacity(0.55),
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}

// ————————————————————————————————————————————————————————————————
// Utilities: icone e accenti per zona
// ————————————————————————————————————————————————————————————————
IconData _iconFor(String zone) {
  switch (zone) {
    case 'AIN':
      return Icons.sensors;
    case 'ELL':
      return Icons.precision_manufacturing;
    case 'VPF':
      return Icons.dashboard_customize;
    case 'STR':
      return Icons.view_stream;
    case 'LMN':
      return Icons.memory;
    case 'DELTAMAX':
      return Icons.stacked_bar_chart;
    default:
      return Icons.factory_outlined;
  }
}

Color _accentFor(String zone) {
  switch (zone) {
    case 'AIN':
      return const Color(0xFF64D2FF); // iOS cyan
    case 'ELL':
      return const Color(0xFFFF9F0A); // iOS orange
    case 'VPF':
      return const Color(0xFF0A84FF); // iOS blue
    case 'STR':
      return const Color(0xFF30D158); // iOS green
    case 'LMN':
      return const Color(0xFFBF5AF2); // iOS purple
    case 'DELTAMAX':
      return const Color(0xFFFF375F); // iOS pink/red
    default:
      return const Color(0xFF0A84FF);
  }
}
