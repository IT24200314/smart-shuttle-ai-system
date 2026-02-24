// ============================================================
// Smart Shuttle — Driver Dashboard Screen
// Members: IT24100624 & IT24100043
//
// Features:
//  - Start/Stop Session toggle
//  - Drowsiness Detected alert card (amber pulse + glow)
//  - Phone Use alert card (red pulse + glow)
//  - Safety Score gauge (Admin performance metric)
//  - Trip timer, speed, passenger count
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/alert_card.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _startBtnCtrl;
  late Animation<double> _startBtnScale;

  @override
  void initState() {
    super.initState();
    _startBtnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _startBtnScale = _startBtnCtrl;

    // Trip timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      context.read<AppStateProvider>().tickSecond();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _startBtnCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color _safetyColor(double score) {
    if (score >= 85) return AppTheme.emerald;
    if (score >= 60) return AppTheme.amber;
    return AppTheme.danger;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();

    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Driver Dashboard',
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: provider.sessionActive
                  ? AppTheme.emerald.withValues(alpha: 0.15)
                  : AppTheme.danger.withValues(alpha: 0.15),
              borderRadius: AppTheme.borderRadius,
              border: Border.all(
                color: provider.sessionActive ? AppTheme.emerald : AppTheme.danger,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: provider.sessionActive ? AppTheme.emerald : AppTheme.danger,
                  ),
                ),
                const SizedBox(width: 6),
                Text(provider.sessionActive ? 'ON DUTY' : 'OFF DUTY',
                    style: GoogleFonts.inter(
                      color: provider.sessionActive ? AppTheme.emerald : AppTheme.danger,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Session Button ────────────────────────────────
            _SessionToggleButton(
              isActive: provider.sessionActive,
              scaleAnim: _startBtnScale,
              controller: _startBtnCtrl,
              onToggle: () => context.read<AppStateProvider>().toggleSession(),
            ),
            const SizedBox(height: 20),

            // ── Live Stats Row ────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.timer_rounded,
                    label: 'Trip Duration',
                    value: _formatDuration(provider.tripDurationSeconds),
                    color: AppTheme.emerald,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.speed_rounded,
                    label: 'Speed',
                    value: provider.sessionActive ? '38 km/h' : '— km/h',
                    color: AppTheme.emerald,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.people_rounded,
                    label: 'Passengers',
                    value: provider.sessionActive ? '24' : '—',
                    color: AppTheme.emerald,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Safety Score Card (Admin Performance Metric) ──
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_rounded,
                          color: AppTheme.emerald, size: 20),
                      const SizedBox(width: 8),
                      Text('Safety Score',
                          style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          )),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                          borderRadius: AppTheme.borderRadius,
                          border: Border.all(
                              color: const Color(0xFF7C4DFF).withValues(alpha: 0.4)),
                        ),
                        child: Text('Admin Metric',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF7C4DFF),
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
                      // Circular gauge
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: provider.safetyScore / 100,
                              strokeWidth: 8,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _safetyColor(provider.safetyScore),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  provider.safetyScore.toStringAsFixed(0),
                                  style: GoogleFonts.inter(
                                    color: _safetyColor(provider.safetyScore),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text('%',
                                    style: GoogleFonts.inter(
                                        color: AppTheme.textSecondary,
                                        fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.safetyScore >= 85
                                  ? 'Excellent — Keep it up!'
                                  : provider.safetyScore >= 60
                                      ? 'Caution — Check alerts'
                                      : 'Poor — Immediate attention',
                              style: GoogleFonts.inter(
                                color: _safetyColor(provider.safetyScore),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Score shown to Admin for driver performance review. Each triggered alert deducts points.',
                              style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary, fontSize: 11),
                            ),
                            const SizedBox(height: 10),
                            const _ScoreBreakRow('Drowsiness event', '-8 pts',
                                AppTheme.amber),
                            const SizedBox(height: 3),
                            const _ScoreBreakRow(
                                'Phone use event', '-5 pts', AppTheme.danger),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── AI Safety Alerts ──────────────────────────────
            Text('AI Safety Alerts',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                )),
            const SizedBox(height: 10),
            AlertCard(
              icon: Icons.remove_red_eye_rounded,
              title: 'Drowsiness Detected',
              subtitle: 'AI model monitoring eye closure & head position',
              isActive: provider.drowsinessAlert,
              alertColor: AppTheme.amber,
              onSimulate: provider.sessionActive
                  ? () => context
                      .read<AppStateProvider>()
                      .triggerDrowsiness(!provider.drowsinessAlert)
                  : null,
            ),
            const SizedBox(height: 12),
            AlertCard(
              icon: Icons.phone_android_rounded,
              title: 'Phone Use Detected',
              subtitle: 'Vision model detecting handheld device usage',
              isActive: provider.phoneUseAlert,
              alertColor: AppTheme.danger,
              onSimulate: provider.sessionActive
                  ? () => context
                      .read<AppStateProvider>()
                      .triggerPhoneUse(!provider.phoneUseAlert)
                  : null,
            ),
            const SizedBox(height: 20),

            // ── Session Required Notice ───────────────────────
            if (!provider.sessionActive)
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppTheme.textSecondary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Start a session to enable AI monitoring and alert simulation.',
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Session Toggle Button ────────────────────────────────────
class _SessionToggleButton extends StatelessWidget {
  final bool isActive;
  final Animation<double> scaleAnim;
  final AnimationController controller;
  final VoidCallback onToggle;

  const _SessionToggleButton({
    required this.isActive,
    required this.scaleAnim,
    required this.controller,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => controller.reverse(),
      onTapUp: (_) {
        controller.forward();
        onToggle();
      },
      onTapCancel: () => controller.forward(),
      child: AnimatedBuilder(
        animation: scaleAnim,
        builder: (_, child) => Transform.scale(scale: scaleAnim.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: AppTheme.borderRadius,
            color: isActive ? AppTheme.danger.withValues(alpha: 0.12) : AppTheme.emerald.withValues(alpha: 0.12),
            border: Border.all(
              color: isActive ? AppTheme.danger : AppTheme.emerald,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isActive ? AppTheme.danger : AppTheme.emerald).withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? Icons.stop_circle_rounded : Icons.play_circle_rounded,
                color: isActive ? AppTheme.danger : AppTheme.emerald,
                size: 36,
              ),
              const SizedBox(width: 14),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActive ? 'Stop Session' : 'Start Session',
                    style: GoogleFonts.inter(
                      color: isActive ? AppTheme.danger : AppTheme.emerald,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    isActive ? 'Tap to end your current trip' : 'Tap to begin AI monitoring',
                    style: GoogleFonts.inter(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat Tile ────────────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          Text(label,
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary, fontSize: 9)),
        ],
      ),
    );
  }
}

// ── Score Breakdown Row ──────────────────────────────────────
class _ScoreBreakRow extends StatelessWidget {
  final String label;
  final String deduction;
  final Color color;
  const _ScoreBreakRow(this.label, this.deduction, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(
                color: AppTheme.textSecondary, fontSize: 10)),
        const Spacer(),
        Text(deduction,
            style: GoogleFonts.inter(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
