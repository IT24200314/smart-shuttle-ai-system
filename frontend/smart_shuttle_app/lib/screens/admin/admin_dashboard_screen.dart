// ============================================================
// Smart Shuttle — Admin Dashboard (Overflow-fixed)
// Fixed: alert item height, rule 1/3/6/9 compliance
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/kpi_card.dart';
import 'revenue_dashboard_screen.dart';
import 'admin_lost_found_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/api_config.dart';
import '../../providers/app_state_provider.dart';
import 'package:provider/provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<Map<String, dynamic>> _adminSummary;

  @override
  void initState() {
    super.initState();
    _adminSummary = fetchAdminSummary();
  }

  Future<Map<String, dynamic>> fetchAdminSummary() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/summary'),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(res.body));
      }
      throw Exception('Server error: ${res.statusCode}');
    } catch (e) {
      throw Exception('Admin API unreachable: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _adminSummary,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(child: Text('Admin Sync Failed: ${snapshot.error}', style: GoogleFonts.inter(color: AppTheme.danger))),
          );
        }

        final data = snapshot.data!;
        final stats = Map<String, dynamic>.from(data['stats'] ?? {});
        final alerts = (data['alerts'] as List?) ?? [];

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
                Text('Control Center',
                    style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                Text('Admin Dashboard',
                    style: GoogleFonts.inter(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.search_rounded,
                          color: AppTheme.accent, size: 15),
                      label: Text('Lost & Found',
                          style: GoogleFonts.inter(
                              color: AppTheme.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                        backgroundColor: AppTheme.accent.withOpacity(0.10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.chipRadius),
                      ),
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AdminLostFoundScreen())),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.bar_chart_rounded,
                          color: AppTheme.positive, size: 15),
                      label: Text('Revenue',
                          style: GoogleFonts.inter(
                              color: AppTheme.positive,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                        backgroundColor: AppTheme.positive.withOpacity(0.10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.chipRadius),
                      ),
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RevenueDashboardScreen())),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _buildMainContent(context, stats),
                      ),
                    ),
                    Container(width: 1, color: AppTheme.border),
                    Expanded(
                      flex: 2,
                      child: _AlertFeedSidebar(alerts: alerts),
                    ),
                  ],
                );
              } else {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMainContent(context, stats),
                      const SizedBox(height: 28),
                      _AlertFeedSidebar(isScrollable: false, alerts: alerts),
                    ],
                  ),
                );
              }
            },
          ),
        );
      }
    );
  }

  Widget _buildMainContent(BuildContext context, Map<String, dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── System Status Banner ──────────────────────────────
        GlassCard(
          fillColor: AppTheme.accent.withOpacity(0.08),
          borderColor: AppTheme.accent.withOpacity(0.25),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.15),
                  borderRadius: AppTheme.chipRadius,
                ),
                child: const Icon(Icons.router_rounded,
                    color: AppTheme.accent, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Fleet Operations — All Systems Nominal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        )),
                    Text(
                      'AI: Passenger Tracking · Drowsiness Detection',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: AppTheme.textSecondary, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.positive.withOpacity(0.15),
                  borderRadius: AppTheme.chipRadius,
                ),
                child: Text('LIVE',
                    style: GoogleFonts.inter(
                        color: AppTheme.positive,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Section: Overview ─────────────────────────────────
        _SectionHeader('Overview'),
        const SizedBox(height: 12),

        // Rule 1 & 6: 4 cards → only most important first (2 primary, 2 secondary)
        SizedBox(
          height: 136,
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55, // wider for readability
            physics: const NeverScrollableScrollPhysics(),
            children: [
              KpiCard(
                icon: Icons.directions_bus_rounded,
                label: 'Active Buses',
                value: '${stats['active_buses'] ?? 0} / 5',
                subtitle: 'Operational fleet',
                isPositive: true,
                accentColor: AppTheme.accent,
              ),
              KpiCard(
                icon: Icons.warning_amber_rounded,
                label: 'Risk Alerts',
                value: '${stats['risk_alerts'] ?? 0}',
                subtitle: 'Pending review',
                isPositive: (stats['risk_alerts'] ?? 0) == 0,
                accentColor: AppTheme.warning,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 136,
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              KpiCard(
                icon: Icons.dns_rounded,
                label: 'System Health',
                value: '${stats['system_health'] ?? 100}%',
                subtitle: 'API Performance',
                isPositive: true,
                accentColor: AppTheme.positive,
              ),
              KpiCard(
                icon: Icons.school_rounded,
                label: 'Users Registered',
                value: '${stats['registered_users'] ?? 0}',
                subtitle: 'Total system scale',
                isPositive: true,
                accentColor: const Color(0xFF8B5CF6),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Section: Fleet Map ────────────────────────────────
        _SectionHeader('Live Fleet Position'),
        const SizedBox(height: 12),

        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.map_rounded,
                      color: AppTheme.accent, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Campus Route Map',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.positive.withOpacity(0.12),
                      borderRadius: AppTheme.chipRadius,
                    ),
                    child: Text('GPS ACTIVE',
                        style: GoogleFonts.inter(
                            color: AppTheme.positive,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 170,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh,
                  borderRadius: AppTheme.chipRadius,
                  border: Border.all(color: AppTheme.border),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.public_rounded,
                          color: AppTheme.accent.withOpacity(0.35),
                          size: 42),
                      const SizedBox(height: 10),
                      Text('Google Maps — API key required',
                          style: GoogleFonts.inter(
                              color: AppTheme.textMuted, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('12 buses · 3 active routes',
                          style: GoogleFonts.inter(
                              color: AppTheme.textSecondary, fontSize: 11)),
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

// ── Section Header Helper ────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: AppTheme.border)),
      ],
    );
  }
}

// ── Alert Feed Sidebar ───────────────────────────────────────
class _AlertFeedSidebar extends StatelessWidget {
  final bool isScrollable;
  final List<dynamic> alerts;
  const _AlertFeedSidebar({this.isScrollable = true, required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_rounded,
                  color: AppTheme.warning, size: 15),
              const SizedBox(width: 8),
              Text('Real-Time Alerts',
                  style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              const _LiveDot(),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.border),
        isScrollable
            ? Expanded(child: _buildList())
            : _buildList(),
      ],
    );
  }

  Widget _buildList() {
    if (alerts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text('No active alerts', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: !isScrollable,
      physics: isScrollable ? null : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _AlertItem(
            time: alert['time'] ?? '--:--',
            title: alert['type'] ?? 'System Alert',
            desc: alert['description'] ?? 'No details provided',
            severity: (alert['severity'] ?? 'warning') == 'critical'
                ? _AlertSeverity.critical
                : _AlertSeverity.warning,
            icon: (alert['type'] ?? '').toString().contains('Drowsiness')
                ? Icons.remove_red_eye_rounded
                : (alert['type'] ?? '').toString().contains('Speed')
                    ? Icons.speed_rounded
                    : Icons.notifications_none_rounded,
          ),
        );
      },
    );
  }
}

enum _AlertSeverity { critical, warning }

class _AlertItem extends StatelessWidget {
  final String time;
  final String title;
  final String desc;
  final _AlertSeverity severity;
  final IconData icon;

  const _AlertItem({
    required this.time,
    required this.title,
    required this.desc,
    required this.severity,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = severity == _AlertSeverity.critical
        ? AppTheme.danger
        : AppTheme.warning;

    return ClipRRect(
      borderRadius: AppTheme.cardRadius,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: AppTheme.cardRadius,
          border: Border.all(color: AppTheme.border),
        ),
        child: IntrinsicHeight(  // ← FIX: left stripe matches actual content height
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Severity left stripe — no fixed height
              Container(width: 3, color: color),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: AppTheme.chipRadius,
                  ),
                  child: Icon(icon, color: color, size: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                )),
                          ),
                          const SizedBox(width: 6),
                          Text(time,
                              style: GoogleFonts.inter(
                                color: AppTheme.textMuted,
                                fontSize: 10,
                              )),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppTheme.danger,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppTheme.danger, blurRadius: 5)],
        ),
      ),
    );
  }
}
