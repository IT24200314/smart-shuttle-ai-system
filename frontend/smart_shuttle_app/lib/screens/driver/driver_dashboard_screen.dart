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

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      context.read<AppStateProvider>().tickSecond();
    });
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
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _DutyBadge(active: provider.sessionActive),
          ),
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
                context.read<AppStateProvider>().toggleSession();
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
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          borderRadius: AppTheme.chipRadius,
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
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
                                  color: AppTheme.textSecondary,
                                  fontSize: 11),
                            ),
                            const SizedBox(height: 10),
                            _DeductRow('Drowsiness event',
                                '–8 pts', AppTheme.warning),
                            const SizedBox(height: 4),
                            _DeductRow('Phone use event',
                                '–5 pts', AppTheme.danger),
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
              icon: Icons.remove_red_eye_rounded,
              title: 'Drowsiness Detected',
              subtitle: 'AI monitors eye closure & head position',
              isActive: provider.drowsinessAlert,
              alertColor: AppTheme.warning,
              onSimulate: provider.sessionActive
                  ? () => context
                      .read<AppStateProvider>()
                      .triggerDrowsiness(!provider.drowsinessAlert)
                  : null,
            ),
            const SizedBox(height: 10),
            AlertCard(
              icon: Icons.phone_android_rounded,
              title: 'Phone Use Detected',
              subtitle: 'Vision model: handheld device detection',
              isActive: provider.phoneUseAlert,
              alertColor: AppTheme.danger,
              onSimulate: provider.sessionActive
                  ? () => context
                      .read<AppStateProvider>()
                      .triggerPhoneUse(!provider.phoneUseAlert)
                  : null,
            ),

            if (!provider.sessionActive) ...[
              const SizedBox(height: 14),
              GlassCard(
                fillColor: AppTheme.surfaceHigh,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
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
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
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
        color: color.withValues(alpha: 0.10),
        borderRadius: AppTheme.chipRadius,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
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
              width: 5, height: 5,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
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
