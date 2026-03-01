// ============================================================
// Smart Shuttle — System Control Center (Admin)
//
// Primary Focus: Fleet status and Driver Safety.
// Theme: Deep Blue professional theme with 'Warning Orange' for alerts.
// Layout: Technical monitoring style.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/kpi_card.dart';
import 'revenue_dashboard_screen.dart';
import 'audit_log_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('System Control Center',
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.blueAccent),
            tooltip: 'View Audit Logs',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AuditLogScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white70),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.darkBlue,
                  shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadius),
                  title: Text('System Settings', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  content: Text('Manage Bus Ticket Prices and Alert Thresholds here.\n\n(Settings module coming soon)', 
                    style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
                  actions: [
                    TextButton(
                      child: Text('Close', style: GoogleFonts.inter(color: Colors.blueAccent)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.bar_chart_rounded, color: AppTheme.emerald, size: 18),
            label: Text('Financial Intelligence',
                style: GoogleFonts.inter(color: AppTheme.emerald, fontSize: 12)),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RevenueDashboardScreen())),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            // Tablet / Desktop view with Sidebar Alert Feed
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildMainContent(context),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                    ),
                    // Wrap the shrink-wrapped sidebar in a scroll view for desktop
                    child: const SingleChildScrollView(
                      child: _AlertFeedSidebar(),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Mobile (Stacked) View
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                   _buildMainContent(context),
                   const SizedBox(height: 24),
                   const _AlertFeedSidebar(),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderColor: Colors.blueAccent.withValues(alpha: 0.4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.15),
                  borderRadius: AppTheme.borderRadius,
                ),
                child: const Icon(Icons.router_rounded, color: Colors.blueAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fleet Operations active — All systems nominal',
                        style: GoogleFonts.inter(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )),
                    Text(
                      'Monitoring AI nodes: Passenger Tracking & Driver Drowsiness Systems.',
                      style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            const Icon(Icons.dashboard_customize_rounded, color: Colors.blueAccent, size: 18),
            const SizedBox(width: 8),
            Text('System Overview',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 16),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: const [
            KpiCard(
              icon: Icons.directions_bus_rounded,
              label: 'Active Buses',
              value: '2 / 2',
              subtitle: 'Fleet fully operational',
              isPositive: true,
              accentColor: Colors.blueAccent,
            ),
            KpiCard(
              icon: Icons.warning_rounded,
              label: 'High-Risk Drivers',
              value: '2 Alerts',
              subtitle: 'Drowsiness Detected',
              isPositive: false,
              accentColor: Colors.orangeAccent,
            ),
            KpiCard(
              icon: Icons.dns_rounded,
              label: 'System Server Health',
              value: '99.8%',
              subtitle: 'Latency: 12ms (Stable)',
              isPositive: true,
              accentColor: AppTheme.emerald,
            ),
            KpiCard(
              icon: Icons.school_rounded,
              label: 'Total Active Students',
              value: '840',
              subtitle: '210 currently transiting',
              isPositive: true,
              accentColor: Color(0xFF7C4DFF),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: AppTheme.borderRadius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               Row(
                children: [
                  const Icon(Icons.map_rounded, color: Colors.blueAccent, size: 18),
                  const SizedBox(width: 8),
                  Text('Active Fleet Map',
                      style: GoogleFonts.inter(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('LIVE GPS', style: GoogleFonts.inter(color: AppTheme.emerald, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: AppTheme.borderRadius,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.public_rounded, color: Colors.blueAccent, size: 40),
                      const SizedBox(height: 8),
                      Text('System Map (Radar View active)', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Alert Feed Sidebar (Real-time AI Alerts) ──────────────────
// CORRECTED: No Expanded widgets. Always shrink-wraps to fit content.
class _AlertFeedSidebar extends StatelessWidget {
  const _AlertFeedSidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // MUST be MainAxisSize.min to allow SingleChildScrollView to calculate height
        mainAxisSize: MainAxisSize.min, 
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Colors.orangeAccent, size: 18),
                const SizedBox(width: 8),
                Text('Real-Time Alert Feed',
                    style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                const _PulseIndicator(),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          // IMPORTANT: shrinkWrap: true and NeverScrollableScrollPhysics 
          // to prevent internal scrolling conflicts
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: const [
              _AlertItem(
                time: '10:42 AM',
                title: 'Drowsiness Detected',
                desc: 'Driver: Kamal (Bus 08) - Repeated micro-sleep detected by AI camera.',
                isCritical: true,
                icon: Icons.remove_red_eye_rounded,
              ),
              SizedBox(height: 12),
              _AlertItem(
                time: '10:15 AM',
                title: 'Unauthorized Access Attempt',
                desc: 'Bus 04 - passenger without valid RFID scan recognized by YOLO model.',
                isCritical: false,
                icon: Icons.no_accounts_rounded,
              ),
              SizedBox(height: 12),
              _AlertItem(
                time: '09:30 AM',
                title: 'Speed Limit Exceeded',
                desc: 'Driver: Nimal (Bus 02) reached 75 kmph (limit 60 kmph).',
                isCritical: true,
                icon: Icons.speed_rounded,
              ),
              SizedBox(height: 12),
              _AlertItem(
                time: '09:05 AM',
                title: 'Route Deviation',
                desc: 'Bus 11 deviated from standard route. Likely traffic evasion.',
                isCritical: false,
                icon: Icons.alt_route_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertItem extends StatelessWidget {
  final String time;
  final String title;
  final String desc;
  final bool isCritical;
  final IconData icon;

  const _AlertItem({
    required this.time,
    required this.title,
    required this.desc,
    required this.isCritical,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCritical ? Colors.orangeAccent : Colors.amber;
    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderColor: color.withValues(alpha: 0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title,
                        style: GoogleFonts.inter(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        )),
                    Text(time,
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        )),
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc,
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary.withValues(alpha: 0.8),
                      fontSize: 11,
                      height: 1.4,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseIndicator extends StatefulWidget {
  const _PulseIndicator();
  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8, height: 8,
        decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.orangeAccent, blurRadius: 4)]),
      ),
    );
  }
}
