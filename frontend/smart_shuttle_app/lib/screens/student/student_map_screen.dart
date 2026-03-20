// ============================================================
// Smart Shuttle — Student Map Screen (Overflow-fixed)
// Bottom sheet: Expanded ETA card, crowd card fixed-width
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

  final List<Offset> _waypoints = const [
    Offset(0.10, 0.70),
    Offset(0.25, 0.52),
    Offset(0.42, 0.40),
    Offset(0.58, 0.36),
    Offset(0.74, 0.48),
    Offset(0.88, 0.58),
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
    _busAnim = CurvedAnimation(parent: _busCtrl, curve: Curves.linear);
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
    final mapH = size.height * 0.50;   // slightly shorter to leave more room for bottom sheet

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Bus Tracker',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text('Student View',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded,
                color: AppTheme.textSecondary, size: 20),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // ── Map Background ──────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: mapH,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0E1825),
                    Color(0xFF101B30),
                    Color(0xFF0B1520),
                  ],
                ),
              ),
              child: CustomPaint(painter: _GridPainter()),
            ),
          ),

          // ── Route Polyline ──────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: mapH,
            child: CustomPaint(
              painter: _RoutePainter(
                waypoints: _waypoints,
                screenWidth: size.width,
                mapHeight: mapH,
              ),
            ),
          ),

          // ── Animated Bus Marker ─────────────────────────────
          AnimatedBuilder(
            animation: _busAnim,
            builder: (context, _) {
              final pos = _busPosition(_busAnim.value);
              return Positioned(
                left: (pos.dx * size.width - 20).clamp(0.0, size.width - 44),
                top: (pos.dy * mapH).clamp(0.0, mapH - 44),
                child: _BusMarker(pulseAnim: _pulseAnim),
              );
            },
          ),

          // ── Bottom Info Sheet ───────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _BottomSheet(
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

// ── Grid Painter ─────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFF1E3050)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final minorPaint = Paint()
      ..color = const Color(0xFF172540)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    final blockPaint = Paint()
      ..color = const Color(0xFF131E35)
      ..style = PaintingStyle.fill;

    final rng = Random(42);
    for (int i = 0; i < 8; i++) {
      for (int j = 0; j < 6; j++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              i * size.width / 7 + rng.nextDouble() * 8,
              j * size.height / 5 + rng.nextDouble() * 8,
              size.width / 9,
              size.height / 7,
            ),
            const Radius.circular(4),
          ),
          blockPaint,
        );
      }
    }
    for (double y = 0; y < size.height; y += size.height / 4.5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadPaint);
    }
    for (double x = 0; x < size.width; x += size.width / 4) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadPaint);
    }
    for (double y = size.height / 9; y < size.height; y += size.height / 4.5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minorPaint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Route Painter ─────────────────────────────────────────────
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
      ..color = AppTheme.positive.withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < waypoints.length; i++) {
      final pt = Offset(
        waypoints[i].dx * screenWidth,
        waypoints[i].dy * mapHeight,
      );
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path, paint);

    for (final w in waypoints) {
      canvas.drawCircle(Offset(w.dx * screenWidth, w.dy * mapHeight), 5,
          Paint()..color = AppTheme.positive);
      canvas.drawCircle(Offset(w.dx * screenWidth, w.dy * mapHeight), 3,
          Paint()..color = AppTheme.background);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Bus Marker ────────────────────────────────────────────────
class _BusMarker extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _BusMarker({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) => SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.positive
                    .withValues(alpha: 0.12 * pulseAnim.value),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.positive,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.positive.withValues(alpha: 0.40),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.directions_bus_rounded,
                  color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Sheet ──────────────────────────────────────────────
class _BottomSheet extends StatelessWidget {
  final AppStateProvider provider;
  final String selectedRoute;
  final List<String> routes;
  final ValueChanged<String?> onRouteChanged;

  const _BottomSheet({
    required this.provider,
    required this.selectedRoute,
    required this.routes,
    required this.onRouteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Route Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonFormField<String>(
                initialValue: selectedRoute,
                dropdownColor: AppTheme.surfaceHigh,
                isExpanded: true, // ← Prevents dropdown overflow
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.route_rounded,
                      color: AppTheme.positive, size: 17),
                  hintText: 'Select route',
                  hintStyle: GoogleFonts.inter(
                      color: AppTheme.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.surfaceHigh,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: AppTheme.inputRadius,
                    borderSide:
                        const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppTheme.inputRadius,
                    borderSide:
                        const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppTheme.inputRadius,
                    borderSide: const BorderSide(
                        color: AppTheme.accent, width: 1.5),
                  ),
                ),
                items: routes
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13)),
                        ))
                    .toList(),
                onChanged: onRouteChanged,
              ),
            ),
            const SizedBox(height: 12),

            // ETA + Crowd Row — ETA is hero, crowd is secondary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ETA Card — Expanded takes remaining space
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  color: AppTheme.positive, size: 13),
                              const SizedBox(width: 5),
                              Text('ETA',
                                  style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Rule 2: big number = main data
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('${provider.etaMinutes}',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textPrimary,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                    height: 1,
                                  )),
                              const SizedBox(width: 4),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text('min',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    )),
                              ),
                            ],
                          ),
                          Text('to Main Gate Stop',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  color: AppTheme.textMuted, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Crowd Card — Fixed width, not Expanded, so it can't overflow ETA
                  SizedBox(
                    width: 130,
                    child: GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Crowd Level',
                              maxLines: 1,
                              style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11)),
                          const SizedBox(height: 8),
                          CrowdDensityBadge(density: provider.crowdDensity),
                          const SizedBox(height: 10),
                          // Crowd selector buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: CrowdDensity.values.map((d) {
                              final selected = provider.crowdDensity == d;
                              return GestureDetector(
                                onTap: () => context
                                    .read<AppStateProvider>()
                                    .setCrowdDensity(d),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppTheme.positive
                                            .withValues(alpha: 0.18)
                                        : AppTheme.surfaceHigh,
                                    borderRadius: AppTheme.chipRadius,
                                    border: Border.all(
                                      color: selected
                                          ? AppTheme.positive
                                              .withValues(alpha: 0.6)
                                          : AppTheme.border,
                                    ),
                                  ),
                                  child: Text(d.name[0].toUpperCase(),
                                      style: GoogleFonts.inter(
                                        color: selected
                                            ? AppTheme.positive
                                            : AppTheme.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      )),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Bus Info Bar — Flexible chips prevent overflow on narrow screens
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: const [
                    _InfoChip(icon: Icons.confirmation_number_rounded,
                        label: 'Bus', value: 'NB-2341'),
                    _Vdivider(),
                    _InfoChip(icon: Icons.speed_rounded,
                        label: 'Speed', value: '42 km/h'),
                    _Vdivider(),
                    _InfoChip(icon: Icons.people_rounded,
                        label: 'Seats', value: '12 free'),
                    _Vdivider(),
                    _InfoChip(icon: Icons.location_on_rounded,
                        label: 'Stop', value: '2 away'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.positive, size: 14),
        const SizedBox(height: 3),
        Text(value,
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
        Text(label,
            style: GoogleFonts.inter(
                color: AppTheme.textSecondary, fontSize: 9)),
      ],
    );
  }
}

class _Vdivider extends StatelessWidget {
  const _Vdivider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1, height: 28, color: AppTheme.border);
}
