import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../providers/app_state_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/crowd_density_badge.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../utils/api_config.dart';
import 'student_lost_found_screen.dart';
import 'student_feedback_screen.dart';

class StudentMapScreen extends StatefulWidget {
  const StudentMapScreen({super.key});

  @override
  State<StudentMapScreen> createState() => _StudentMapScreenState();
}

class _StudentMapScreenState extends State<StudentMapScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  Timer? _pollTimer;

  Offset _busPos = const Offset(0.10, 0.70); // Default to start
  String _busId = 'NB-2341';
  int _currentSpeed = 0;
  String _stopStatus = 'En route';
  String? _feedbackTripId;
  String? _feedbackTripType;
  String? _feedbackTripEndedAt;

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
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _refreshStudentData();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (t) => _refreshStudentData(),
    );
  }

  Future<void> _refreshStudentData() async {
    await _fetchLiveLocation();
    await _fetchFeedbackEligibility();
  }

  Future<void> _fetchLiveLocation() async {
    try {
      final res = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/map/live-location'),
          )
          .timeout(const Duration(seconds: 2));

      if (res.statusCode == 200 && mounted) {
        final data = Map<String, dynamic>.from(json.decode(res.body));
        setState(() {
          _busPos = Offset(
            (data['lat_percent'] ?? 0.5).toDouble(),
            (data['lng_percent'] ?? 0.5).toDouble(),
          );
          _busId = data['bus_id'] ?? 'NB-2341';
          _currentSpeed = data['speed'] ?? 0;
          _stopStatus = data['status'] ?? 'Active';

          // Sync ETA if provided by backend
          if (data['eta_min'] != null) {
            context.read<AppStateProvider>().setEta(data['eta_min']);
          }
        });
      }
    } catch (_) {
      // Fail silently for polling
    }
  }

  Future<void> _fetchFeedbackEligibility() async {
    final appState = context.read<AppStateProvider>();
    final token = appState.jwtToken;
    if (token == null ||
        token.isEmpty ||
        appState.currentRole != UserRole.student) {
      if (!mounted) return;
      setState(() {
        _feedbackTripId = null;
        _feedbackTripType = null;
        _feedbackTripEndedAt = null;
      });
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/feedback/eligible-trip'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 4));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(json.decode(res.body));
        setState(() {
          _feedbackTripId = data['trip_id']?.toString();
          _feedbackTripType = data['trip_type']?.toString();
          _feedbackTripEndedAt = data['actual_end_time']?.toString();
        });
      } else {
        setState(() {
          _feedbackTripId = null;
          _feedbackTripType = null;
          _feedbackTripEndedAt = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedbackTripId = null;
        _feedbackTripType = null;
        _feedbackTripEndedAt = null;
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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

  void _openFeedback() {
    if (_feedbackTripId == null || _feedbackTripId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Feedback becomes available after the most recently completed trip.',
            style: GoogleFonts.inter(color: AppTheme.onAccent),
          ),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentFeedbackScreen(
          tripId: _feedbackTripId!,
          tripType: _feedbackTripType,
          completedAt: _feedbackTripEndedAt,
        ),
      ),
    );
  }

  void _openLostFound() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StudentLostFoundScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider to rebuild on theme toggle
    context.watch<AppStateProvider>();
    final provider = context.watch<AppStateProvider>();
    final size = MediaQuery.of(context).size;
    final mapH = size.height * (size.width < 700 ? 0.46 : 0.56);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
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
          const ThemeToggleButton(compact: true),
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: AppTheme.textSecondary, size: 20),
            onPressed: _refreshStudentData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // ── Map Background ──────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: mapH,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.background,
                    AppTheme.surface,
                    AppTheme.background,
                  ],
                ),
              ),
              child: CustomPaint(painter: _GridPainter()),
            ),
          ),

          // ── Route Polyline ──────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: mapH,
            child: CustomPaint(
              painter: _RoutePainter(
                waypoints: _waypoints,
                screenWidth: size.width,
                mapHeight: mapH,
              ),
            ),
          ),

          // ── Real-time Bus Marker ───────────────────────────
          Positioned(
            left: (_busPos.dx * size.width - 20).clamp(0.0, size.width - 44),
            top: (_busPos.dy * mapH).clamp(0.0, mapH - 44),
            child: _BusMarker(pulseAnim: _pulseAnim),
          ),

          // ── Bottom Info Sheet ───────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomSheet(
              provider: provider,
              selectedRoute: _selectedRoute,
              routes: _routes,
              onRouteChanged: (r) => setState(() => _selectedRoute = r!),
              busId: _busId,
              currentSpeed: _currentSpeed,
              stopStatus: _stopStatus,
              feedbackTripId: _feedbackTripId,
              feedbackTripType: _feedbackTripType,
              onOpenFeedback: _openFeedback,
              onOpenLostFound: _openLostFound,
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
      ..color = AppTheme.borderStrong
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final minorPaint = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    final blockPaint = Paint()
      ..color = AppTheme.surfaceHigh
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
      ..color = AppTheme.positive.withOpacity(0.9)
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
                color: AppTheme.positive.withOpacity(0.12 * pulseAnim.value),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.positive,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.positive.withOpacity(0.40),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(Icons.directions_bus_rounded,
                  color: AppTheme.onPositive, size: 16),
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
  final String busId;
  final int currentSpeed;
  final String stopStatus;
  final String? feedbackTripId;
  final String? feedbackTripType;
  final VoidCallback onOpenFeedback;
  final VoidCallback onOpenLostFound;

  const _BottomSheet({
    required this.provider,
    required this.selectedRoute,
    required this.routes,
    required this.onRouteChanged,
    required this.busId,
    required this.currentSpeed,
    required this.stopStatus,
    required this.feedbackTripId,
    required this.feedbackTripType,
    required this.onOpenFeedback,
    required this.onOpenLostFound,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final maxSheetHeight = media.height * (media.width < 700 ? 0.62 : 0.54);

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedRoute,
                dropdownColor: AppTheme.surfaceHigh,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.route_rounded,
                      color: AppTheme.positive, size: 17),
                  labelText: 'Route',
                ),
                items: routes
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(
                            r,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: GoogleFonts.inter(
                                color: AppTheme.textPrimary, fontSize: 13),
                          ),
                        ))
                    .toList(),
                onChanged: onRouteChanged,
              ),
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stackStats = constraints.maxWidth < 360;

                    final etaBlock = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Estimated Arrival',
                            style: GoogleFonts.inter(
                                color: AppTheme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${provider.etaMinutes}',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                )),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text('min',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('to Main Gate stop',
                            style: GoogleFonts.inter(
                                color: AppTheme.textMuted, fontSize: 11)),
                      ],
                    );
                    final crowdBlock = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Crowd',
                            style: GoogleFonts.inter(
                                color: AppTheme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 8),
                        CrowdDensityBadge(density: provider.crowdDensity),
                      ],
                    );

                    if (stackStats) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          etaBlock,
                          const SizedBox(height: 14),
                          crowdBlock,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: etaBlock),
                        const SizedBox(width: 10),
                        crowdBlock,
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                        icon: Icons.confirmation_number_rounded,
                        label: 'Bus',
                        value: busId),
                    _InfoChip(
                        icon: Icons.speed_rounded,
                        label: 'Speed',
                        value: '$currentSpeed km/h'),
                    _InfoChip(
                        icon: Icons.location_on_rounded,
                        label: 'Status',
                        value: stopStatus),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 420;
                  final feedbackButton = ElevatedButton.icon(
                    onPressed: onOpenFeedback,
                    icon: const Icon(Icons.rate_review_rounded, size: 18),
                    label: Text(
                      feedbackTripId == null
                          ? 'Feedback Unavailable'
                          : 'Rate Latest Trip',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: feedbackTripId == null
                          ? AppTheme.surfaceHigh
                          : AppTheme.accent,
                      foregroundColor: feedbackTripId == null
                          ? AppTheme.textSecondary
                          : AppTheme.onAccent,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  );

                  final lostFoundButton = OutlinedButton.icon(
                    onPressed: onOpenLostFound,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(
                      'Lost & Found',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  );

                  if (!isWide) {
                    return Column(
                      children: [
                        SizedBox(width: double.infinity, child: feedbackButton),
                        const SizedBox(height: 8),
                        SizedBox(
                            width: double.infinity, child: lostFoundButton),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: feedbackButton),
                      const SizedBox(width: 8),
                      Expanded(child: lostFoundButton),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                feedbackTripId == null
                    ? 'Feedback opens after your latest completed trip is posted.'
                    : 'Feedback target: ${feedbackTripType ?? 'Completed Trip'}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: AppTheme.chipRadius,
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.positive, size: 14),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
