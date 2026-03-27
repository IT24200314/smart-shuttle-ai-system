// ============================================================
// Smart Shuttle — Driver Dashboard (Overflow-fixed)
// SessionButton Column wrapped, StatTile value FittedBox
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/alert_card.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/api_config.dart';
import '../auth/login_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _btnCtrl;
  late Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();
    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
    _btnScale = _btnCtrl;

    _fetchSafetyScore();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final p = context.read<AppStateProvider>();
      if (p.sessionActive) {
        p.tickSecond();
        if (p.tripDurationSeconds % 10 == 0) {
          _fetchLiveTelemetry();
          _fetchSafetyScore();
        }
      }
    });
  }

  Future<void> _fetchSafetyScore() async {
    try {
      final provider = context.read<AppStateProvider>();
      final driverEmail = provider.userEmail ?? 'driver-01';
      final encoded = Uri.encodeComponent(driverEmail);
      final res = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/driver/safety-score/$encoded'),
          )
          .timeout(const Duration(seconds: 3));

      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        final score = (data['safety_score'] as num?)?.toDouble() ?? 100.0;
        provider.setSafetyScore(score);
      }
    } catch (_) {}
  }

  Future<void> _fetchLiveTelemetry() async {
    try {
      final res = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/map/live-location/NB-2341'),
          )
          .timeout(const Duration(seconds: 2));

      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        // Speed and passengers are in data
        // For now we trust the backend's status, but keep local toggle too
      }
    } catch (_) {}
  }

  Future<void> _handleSessionToggle() async {
    final provider = context.read<AppStateProvider>();
    if (!provider.sessionActive) {
      // START TRIP
      final tripType = await _showStartDialog();
      if (tripType == null) return;

      try {
        final res = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/driver/start-trip'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'bus_id': 'NB-2341',
            'trip_type': tripType,
            'driver_id': provider.userEmail ?? 'driver-01'
          }),
        );
        if (res.statusCode == 200) {
          provider.toggleSession();
        }
      } catch (e) {
        _showError('Server connection failed');
      }
    } else {
      // END TRIP
      final counts = await _showEndDialog();
      if (counts == null) return;

      try {
        final res = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/driver/end-trip'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'bus_id': 'NB-2341',
            'trip_type': 'Standard', // or store from start
            'tickets_75': counts['75'] ?? 0,
            'tickets_100': counts['100'] ?? 0,
            'tickets_150': counts['150'] ?? 0,
            'tickets_200': counts['200'] ?? 0,
          }),
        );
        if (res.statusCode == 200) {
          provider.toggleSession();
          _showSuccess('Trip data synced to revenue engine');
        }
      } catch (e) {
        _showError('Failed to finalize trip');
      }
    }
  }

  Future<String?> _showStartDialog() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        title: Text('Start New Trip',
            style: GoogleFonts.inter(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Morning', 'Evening', 'Special']
              .map((t) => ListTile(
                    title:
                        Text(t, style: GoogleFonts.inter(color: Colors.white)),
                    onTap: () => Navigator.pop(ctx, t),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Future<Map<String, int>?> _showEndDialog() async {
    final c75 = TextEditingController(text: '0');
    final c100 = TextEditingController(text: '0');
    final c150 = TextEditingController(text: '0');
    final c200 = TextEditingController(text: '0');
    return showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        title: Text('Finalize Tickets',
            style: GoogleFonts.inter(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TicketField(label: '75 LKR Tickets', controller: c75),
            _TicketField(label: '100 LKR Tickets', controller: c100),
            _TicketField(label: '150 LKR Tickets', controller: c150),
            _TicketField(label: '200 LKR Tickets', controller: c200),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, {
                    '75': int.tryParse(c75.text) ?? 0,
                    '100': int.tryParse(c100.text) ?? 0,
                    '150': int.tryParse(c150.text) ?? 0,
                    '200': int.tryParse(c200.text) ?? 0,
                  }),
              child: const Text('Submit')),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.danger));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.positive));
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        title: Text('Logout',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Logout',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _btnCtrl.dispose();
    super.dispose();
  }

  String _fmt(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color _scoreColor(double score) {
    if (score >= 85) return AppTheme.positive;
    if (score >= 60) return AppTheme.warning;
    return AppTheme.danger;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();

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
            Text('Driver Dashboard',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text('AI Safety Dashboard',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          _DutyBadge(active: provider.sessionActive),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.power_settings_new_rounded,
                color: AppTheme.danger, size: 22),
            onPressed: _logout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Session Toggle ────────────────────────────────
            GestureDetector(
              onTapDown: (_) => _btnCtrl.reverse(),
              onTapUp: (_) {
                _btnCtrl.forward();
                _handleSessionToggle();
              },
              onTapCancel: () => _btnCtrl.forward(),
              child: AnimatedBuilder(
                animation: _btnScale,
                builder: (_, child) =>
                    Transform.scale(scale: _btnScale.value, child: child),
                child: _SessionButton(isActive: provider.sessionActive),
              ),
            ),
            const SizedBox(height: 20),

            // ── Live Stats – Rule 9: big numbers ─────────────
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.timer_rounded,
                      label: 'Duration',
                      value: _fmt(provider.tripDurationSeconds),
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.speed_rounded,
                      label: 'Speed',
                      value: provider.sessionActive ? '38 km/h' : '—',
                      color: provider.sessionActive
                          ? AppTheme.positive
                          : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.people_rounded,
                      label: 'Passengers',
                      value: provider.sessionActive ? '24' : '—',
                      color: provider.sessionActive
                          ? AppTheme.positive
                          : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Safety Score ──────────────────────────────────
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_rounded,
                          color: AppTheme.accent, size: 17),
                      const SizedBox(width: 8),
                      Text('Safety Score',
                          style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          )),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.15),
                          borderRadius: AppTheme.chipRadius,
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withOpacity(0.35),
                          ),
                        ),
                        child: Text('Admin',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF8B5CF6),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Circular gauge — fixed size, no overflow
                      SizedBox(
                        width: 86,
                        height: 86,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: provider.safetyScore / 100,
                              strokeWidth: 7,
                              backgroundColor: AppTheme.border,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _scoreColor(provider.safetyScore),
                              ),
                              strokeCap: StrokeCap.round,
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  provider.safetyScore.toStringAsFixed(0),
                                  style: GoogleFonts.inter(
                                    color: _scoreColor(provider.safetyScore),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text('%',
                                    style: GoogleFonts.inter(
                                        color: AppTheme.textMuted,
                                        fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              provider.safetyScore >= 85
                                  ? 'Excellent — Keep it up!'
                                  : provider.safetyScore >= 60
                                      ? 'Caution — Check alerts'
                                      : 'Poor — Needs attention',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: _scoreColor(provider.safetyScore),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Visible to admin for review.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary, fontSize: 11),
                            ),
                            const SizedBox(height: 10),
                            _DeductRow('Yawn detection', '–1 pts',
                                const Color.fromARGB(255, 234, 203, 26)),
                            const SizedBox(height: 4),
                            _DeductRow('Phone use event', '–2 pts',
                                const Color.fromARGB(255, 203, 98, 12)),
                            const SizedBox(height: 4),
                            _DeductRow('Drowsiness detection', '–5 pts',
                                const Color.fromARGB(255, 206, 11, 11))
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Section: AI Alerts ────────────────────────────
            _SectionLabel('AI Safety Monitoring'),
            const SizedBox(height: 12),

            AlertCard(
              icon: Icons.sentiment_very_satisfied_rounded,
              title: 'Yawn Detected',
              subtitle: 'AI monitors mouth opening',
              isActive: provider.yawnAlert,
              alertColor: const Color.fromARGB(255, 234, 203, 26),
              onSimulate: provider.sessionActive
                  ? () => context
                      .read<AppStateProvider>()
                      .triggerYawn(!provider.yawnAlert)
                  : null,
            ),
            const SizedBox(height: 10),
            AlertCard(
              icon: Icons.phone_android_rounded,
              title: 'Phone Use Detected',
              subtitle: 'Vision model: handheld device detection',
              isActive: provider.phoneUseAlert,
              alertColor: const Color.fromARGB(255, 203, 98, 12),
              onSimulate: provider.sessionActive
                  ? () => context
                      .read<AppStateProvider>()
                      .triggerPhoneUse(!provider.phoneUseAlert)
                  : null,
            ),
            const SizedBox(height: 10),
            AlertCard(
              icon: Icons.remove_red_eye_rounded,
              title: 'Drowsiness Detected',
              subtitle: 'AI monitors eye closure & head position',
              isActive: provider.drowsinessAlert,
              alertColor: const Color.fromARGB(255, 206, 11, 11),
              onSimulate: provider.sessionActive
                  ? () => context
                      .read<AppStateProvider>()
                      .triggerDrowsiness(!provider.drowsinessAlert)
                  : null,
            ),

            if (!provider.sessionActive) ...[
              const SizedBox(height: 14),
              GlassCard(
                fillColor: AppTheme.surfaceHigh,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppTheme.textMuted, size: 17),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Start a session to enable AI monitoring.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Session Button ───────────────────────────────────────────
class _SessionButton extends StatelessWidget {
  final bool isActive;
  const _SessionButton({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.danger : AppTheme.positive;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: AppTheme.cardRadius,
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 14,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.stop_circle_rounded : Icons.play_circle_rounded,
              color: color,
              size: 36,
            ),
            const SizedBox(width: 14),
            // Column inside a flexible container — no fixed height = no overflow
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isActive ? 'Stop Session' : 'Start Session',
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  isActive ? 'Tap to end trip' : 'Tap to begin AI monitoring',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Duty Badge ───────────────────────────────────────────────
class _DutyBadge extends StatelessWidget {
  final bool active;
  const _DutyBadge({required this.active});
  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.positive : AppTheme.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: AppTheme.chipRadius,
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(active ? 'ON DUTY' : 'OFF DUTY',
              style: GoogleFonts.inter(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Stat Tile (FittedBox prevents overflow on narrow tiles) ──
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Score Deduction Row ──────────────────────────────────────
class _DeductRow extends StatelessWidget {
  final String label;
  final String pts;
  final Color color;
  const _DeductRow(this.label, this.pts, this.color);
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ),
          Text(pts,
              style: GoogleFonts.inter(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      );
}

class _TicketField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _TicketField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: GoogleFonts.inter(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: AppTheme.textSecondary),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.border)),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(title.toUpperCase(),
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              )),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: AppTheme.border)),
        ],
      );
}
