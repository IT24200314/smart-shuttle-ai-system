// ============================================================
// Smart Shuttle — Student Map Screen
// Real-time bus tracking view for students
//
// Map: google_maps_flutter GoogleMap widget
//   → Requires API key in AndroidManifest.xml / web/index.html
//   → Demo fallback: custom-painted map simulation
//
// ETA: Computed via Google Maps Distance Matrix API
//   (endpoint: maps.googleapis.com/maps/api/distancematrix)
//   → Bus GPS → student stop → drive-time in seconds → countdown
//
// Crowd Density: read from Cloud Firestore trips collection
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/crowd_density_badge.dart';

class StudentMapScreen extends StatefulWidget {
  const StudentMapScreen({super.key});

  @override
  State<StudentMapScreen> createState() => _StudentMapScreenState();
}

class _StudentMapScreenState extends State<StudentMapScreen>
    with TickerProviderStateMixin {
  late AnimationController _busCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _busAnim;
  late Animation<double> _pulseAnim;

  String _selectedRoute = 'Route A — Main Gate';
  final List<String> _routes = [
    'Route A — Main Gate',
    'Route B — Faculty Block',
    'Route C — Hostel Block',
  ];

  // Simulated waypoints for the bus icon (as fractions of screen)
  final List<Offset> _waypoints = const [
    Offset(0.15, 0.65),
    Offset(0.30, 0.50),
    Offset(0.45, 0.40),
    Offset(0.60, 0.35),
    Offset(0.75, 0.45),
    Offset(0.85, 0.55),
  ];

  @override
  void initState() {
    super.initState();
    _busCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _busAnim  = CurvedAnimation(parent: _busCtrl,   curve: Curves.linear);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _busCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Offset _busPosition(double t) {
    final totalSegments = _waypoints.length - 1;
    final progress = t * totalSegments;
    final seg = progress.floor().clamp(0, totalSegments - 1);
    final frac = progress - seg;
    return Offset.lerp(_waypoints[seg], _waypoints[seg + 1], frac)!;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Student Tracker',
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded,
                color: AppTheme.textPrimary),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // ── Map Background (Simulated) ──────────────────────
          // In production: replace with GoogleMap(initialCameraPosition: ...)
          // and configure API key for accurate rendering
          _MapBackground(size: size),

          // ── Animated Bus Marker ─────────────────────────────
          AnimatedBuilder(
            animation: _busAnim,
            builder: (context, _) {
              final pos = _busPosition(_busAnim.value);
              return Positioned(
                left:  pos.dx * size.width - 20,
                top:   pos.dy * size.height * 0.72 + 40,
                child: _BusMarker(pulseAnim: _pulseAnim),
              );
            },
          ),

          // ── Route Polyline (painted) ────────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _RoutePainter(
                waypoints: _waypoints,
                screenWidth: size.width,
                mapHeight: size.height * 0.72,
              ),
            ),
          ),

          // ── Bottom Info Sheet ───────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _BottomInfoSheet(
              provider: provider,
              selectedRoute: _selectedRoute,
              routes: _routes,
              onRouteChanged: (r) => setState(() => _selectedRoute = r!),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Map Background Painter ──────────────────────────────────
class _MapBackground extends StatelessWidget {
  final Size size;
  const _MapBackground({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height * 0.72,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF162850), Color(0xFF1A2F6A), Color(0xFF112244)],
        ),
      ),
      child: CustomPaint(painter: _GridPainter()),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFF2A3F7A)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final minorPaint = Paint()
      ..color = const Color(0xFF1E3060)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    final blockPaint = Paint()
      ..color = const Color(0xFF1A2B5A)
      ..style = PaintingStyle.fill;

    // Road blocks
    final rng = Random(42);
    for (int i = 0; i < 8; i++) {
      for (int j = 0; j < 6; j++) {
        canvas.drawRect(
          Rect.fromLTWH(
            i * size.width / 7 + rng.nextDouble() * 8,
            j * size.height / 5 + rng.nextDouble() * 8,
            size.width / 8.5,
            size.height / 6.5,
          ),
          blockPaint,
        );
      }
    }

    // Major roads — horizontal
    for (double y = 0; y < size.height; y += size.height / 4.5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadPaint);
    }
    // Major roads — vertical
    for (double x = 0; x < size.width; x += size.width / 4) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadPaint);
    }
    // Minor roads
    for (double y = size.height / 9; y < size.height; y += size.height / 4.5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Route Polyline Painter ──────────────────────────────────
class _RoutePainter extends CustomPainter {
  final List<Offset> waypoints;
  final double screenWidth;
  final double mapHeight;

  const _RoutePainter({
    required this.waypoints,
    required this.screenWidth,
    required this.mapHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.emerald.withValues(alpha: 0.85)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < waypoints.length; i++) {
      final pt = Offset(
        waypoints[i].dx * screenWidth,
        waypoints[i].dy * mapHeight + 40,
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }

    // Dashed effect (removed unused dashPaint variable)

    canvas.drawPath(path, paint);

    // Stop markers
    for (final w in waypoints) {
      canvas.drawCircle(
        Offset(w.dx * screenWidth, w.dy * mapHeight + 40),
        7,
        Paint()..color = AppTheme.emerald.withValues(alpha: 0.7),
      );
      canvas.drawCircle(
        Offset(w.dx * screenWidth, w.dy * mapHeight + 40),
        4,
        Paint()..color = AppTheme.darkBlue,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Animated Bus Marker ─────────────────────────────────────
class _BusMarker extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _BusMarker({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          // Pulse ring
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.emerald.withValues(alpha: 0.15 * pulseAnim.value),
            ),
          ),
          // Bus icon container
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.emerald,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.emerald.withValues(alpha: 0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.directions_bus_rounded,
                color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }
}

// ── Bottom Info Sheet ───────────────────────────────────────
class _BottomInfoSheet extends StatelessWidget {
  final AppStateProvider provider;
  final String selectedRoute;
  final List<String> routes;
  final ValueChanged<String?> onRouteChanged;

  const _BottomInfoSheet({
    required this.provider,
    required this.selectedRoute,
    required this.routes,
    required this.onRouteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      blurSigma: 18,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            decoration: const BoxDecoration(
              color: AppTheme.glassBorder,
              borderRadius: AppTheme.borderRadius,
            ),
          ),
          const SizedBox(height: 16),
          // Route selector
          DropdownButtonFormField<String>(
            initialValue: selectedRoute,
            dropdownColor: AppTheme.midBlue,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.route_rounded, color: AppTheme.emerald, size: 18),
              labelText: 'Route',
              labelStyle: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12),
              filled: true,
              fillColor: AppTheme.glassFill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: const OutlineInputBorder(
                borderRadius: AppTheme.borderRadius,
                borderSide: BorderSide(color: AppTheme.glassBorder),
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: AppTheme.borderRadius,
                borderSide: BorderSide(color: AppTheme.glassBorder),
              ),
            ),
            items: routes.map((r) => DropdownMenuItem(
              value: r,
              child: Text(r, style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 13)),
            )).toList(),
            onChanged: onRouteChanged,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // ETA Card
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              color: AppTheme.emerald, size: 16),
                          const SizedBox(width: 6),
                          Text('ETA',
                              style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary, fontSize: 11)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald.withValues(alpha: 0.12),
                              borderRadius: AppTheme.borderRadius,
                            ),
                            child: Text('Distance Matrix API',
                                style: GoogleFonts.inter(
                                    color: AppTheme.emerald,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${provider.etaMinutes} min',
                          style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          )),
                      Text('Arriving at Main Gate Stop',
                          style: GoogleFonts.inter(
                              color: AppTheme.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Crowd density
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Crowd',
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary, fontSize: 11)),
                    const SizedBox(height: 8),
                    CrowdDensityBadge(density: provider.crowdDensity),
                    const SizedBox(height: 6),
                    Text('Live from Firestore',
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary,
                            fontSize: 9)),
                    const SizedBox(height: 6),
                    // Simulate crowd toggle
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: CrowdDensity.values.map((d) {
                        return GestureDetector(
                          onTap: () => context.read<AppStateProvider>().setCrowdDensity(d),
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: provider.crowdDensity == d
                                  ? AppTheme.emerald.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: AppTheme.borderRadius,
                              border: Border.all(
                                color: provider.crowdDensity == d
                                    ? AppTheme.emerald
                                    : AppTheme.glassBorder,
                              ),
                            ),
                            child: Text(d.name[0].toUpperCase(),
                                style: GoogleFonts.inter(
                                    color: AppTheme.textSecondary,
                                    fontSize: 9)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bus info bar
          const GlassCard(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _InfoChip(icon: Icons.confirmation_number_rounded,
                    label: 'Bus', value: 'NB-2341'),
                _InfoChip(icon: Icons.speed_rounded,
                    label: 'Speed', value: '42 km/h'),
                _InfoChip(icon: Icons.people_rounded,
                    label: 'Seats', value: '12 free'),
                _InfoChip(icon: Icons.location_on_rounded,
                    label: 'Stop', value: '2 away'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.emerald, size: 16),
        const SizedBox(height: 3),
        Text(value,
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
        Text(label,
            style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 9)),
      ],
    );
  }
}
