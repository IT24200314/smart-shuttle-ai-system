import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../providers/app_state_provider.dart';
import '../../utils/api_config.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/theme_toggle_button.dart';
import 'admin_feedback_screen.dart';
import 'admin_lost_found_screen.dart';
import 'admin_users_screen.dart';
import 'audit_log_screen.dart';
import 'revenue_dashboard_screen.dart';

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
      final res = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/admin/summary'),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(res.body));
      }
      throw Exception('Server error: ${res.statusCode}');
    } catch (e) {
      return {
        'stats': {
          'active_buses': 0,
          'risk_alerts': 0,
          'system_health': 0,
          'registered_users': 0,
        },
        'alerts': [],
        '_sync_error': 'Admin API unreachable: $e',
      };
    }
  }

  void _reloadAdminSummary() {
    setState(() {
      _adminSummary = fetchAdminSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider to rebuild on theme toggle
    context.watch<AppStateProvider>();
    return FutureBuilder<Map<String, dynamic>>(
      future: _adminSummary,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          );
        }

        final data = Map<String, dynamic>.from(snapshot.data ?? {});
        final stats = Map<String, dynamic>.from(data['stats'] ?? {});
        final alerts =
            List<Map<String, dynamic>>.from(data['alerts'] ?? const []);
        final syncError = data['_sync_error']?.toString();

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shuttle Operations Dashboard',
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Web-first admin control center',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            actions: [
              const ThemeToggleButton(compact: true),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _reloadAdminSummary,
                icon:
                    Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1120;
              final isMedium = constraints.maxWidth >= 800;

              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (syncError != null) ...[
                    _SyncWarning(
                      message: syncError,
                      onRetry: _reloadAdminSummary,
                    ),
                    const SizedBox(height: 16),
                  ],
                  // ── Compact Status Row (replaces hero) ─────────
                  _CompactStatusRow(stats: stats),
                  const SizedBox(height: 16),
                  // ── KPI Strip ──────────────────────────────────
                  _KpiStrip(stats: stats),
                  const SizedBox(height: 16),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionLabel('Quick Actions'),
                              const SizedBox(height: 12),
                              const _ModuleGrid(columnCount: 2),
                              const SizedBox(height: 16),
                              _PriorityQueue(alerts: alerts),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              _RecentAlertsPanel(alerts: alerts),
                              const SizedBox(height: 16),
                              _OpsSnapshot(stats: stats, alerts: alerts),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    const _SectionLabel('Quick Actions'),
                    const SizedBox(height: 12),
                    _ModuleGrid(columnCount: isMedium ? 2 : 1),
                    const SizedBox(height: 16),
                    _RecentAlertsPanel(alerts: alerts),
                    const SizedBox(height: 16),
                    _PriorityQueue(alerts: alerts),
                    const SizedBox(height: 16),
                    _OpsSnapshot(stats: stats, alerts: alerts),
                  ],
                ],
              );

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 28 : 20,
                  vertical: 20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: content,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COMPACT STATUS ROW — replaces the large hero section
// ═══════════════════════════════════════════════════════════════
class _CompactStatusRow extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _CompactStatusRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final riskAlerts = stats['risk_alerts'] ?? 0;
    final health = stats['system_health'] ?? 0;
    final isStable = riskAlerts == 0;

    return GlassCard(
      fillColor: isStable
          ? AppTheme.positive.withOpacity(0.06)
          : AppTheme.warning.withOpacity(0.06),
      borderColor: isStable
          ? AppTheme.positive.withOpacity(0.20)
          : AppTheme.warning.withOpacity(0.20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isStable
                  ? AppTheme.positive.withOpacity(0.12)
                  : AppTheme.warning.withOpacity(0.12),
              borderRadius: AppTheme.chipRadius,
            ),
            child: Icon(
              isStable
                  ? Icons.check_circle_rounded
                  : Icons.warning_amber_rounded,
              color: isStable ? AppTheme.positive : AppTheme.warning,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isStable
                      ? 'All Systems Operational'
                      : '$riskAlerts Active Alert${riskAlerts > 1 ? 's' : ''} — Review Required',
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'System health: $health%  •  '
                  'Revenue, feedback, users, and fleet operations in one control center.',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// KPI STRIP — compact horizontal row
// ═══════════════════════════════════════════════════════════════
class _KpiStrip extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _KpiStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;
        final crossAxisCount = isWide ? 4 : 2;
        final childAspectRatio = isWide ? 2.4 : 1.6;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: childAspectRatio,
          children: [
            KpiCard(
              icon: Icons.directions_bus_rounded,
              label: 'Fleet Active',
              value: '${stats['active_buses'] ?? 0}',
              subtitle: 'Buses currently online',
              accentColor: AppTheme.accent,
            ),
            KpiCard(
              icon: Icons.warning_amber_rounded,
              label: 'Risk Alerts',
              value: '${stats['risk_alerts'] ?? 0}',
              subtitle: 'Needs admin review',
              isPositive: (stats['risk_alerts'] ?? 0) == 0,
              accentColor: AppTheme.warning,
            ),
            KpiCard(
              icon: Icons.dns_rounded,
              label: 'API Health',
              value: '${stats['system_health'] ?? 0}%',
              subtitle: 'Monitoring and sync status',
              accentColor: AppTheme.positive,
            ),
            KpiCard(
              icon: Icons.manage_accounts_rounded,
              label: 'Users',
              value: '${stats['registered_users'] ?? 0}',
              subtitle: 'Students, drivers, admins',
              accentColor: AppTheme.secondaryAccent,
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MODULE GRID — quick action cards
// ═══════════════════════════════════════════════════════════════
class _ModuleGrid extends StatelessWidget {
  final int columnCount;

  const _ModuleGrid({required this.columnCount});

  @override
  Widget build(BuildContext context) {
    final modules = [
      _ModuleCardData(
        title: 'Revenue',
        subtitle: 'Track profits, leakage, and AI passenger totals.',
        icon: Icons.bar_chart_rounded,
        accent: AppTheme.positive,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RevenueDashboardScreen()),
        ),
      ),
      _ModuleCardData(
        title: 'Feedback',
        subtitle: 'Review ratings by trip and inspect low-score comments.',
        icon: Icons.rate_review_rounded,
        accent: AppTheme.accent,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminFeedbackScreen()),
        ),
      ),
      _ModuleCardData(
        title: 'Users',
        subtitle: 'Edit users, disable accounts, and manage roles safely.',
        icon: Icons.manage_accounts_rounded,
        accent: AppTheme.warning,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
        ),
      ),
      _ModuleCardData(
        title: 'Lost & Found',
        subtitle: 'Resolve claim verification and handover workflow.',
        icon: Icons.search_rounded,
        accent: AppTheme.textSecondary,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminLostFoundScreen()),
        ),
      ),
      _ModuleCardData(
        title: 'Audit Logs',
        subtitle: 'Inspect timeline events across users and system modules.',
        icon: Icons.history_rounded,
        accent: AppTheme.info,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AuditLogScreen()),
        ),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: columnCount >= 2 ? 2.6 : 2.8,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final module = modules[index];
        return _ModuleCard(module: module);
      },
    );
  }
}

class _ModuleCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _ModuleCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
}

class _ModuleCard extends StatelessWidget {
  final _ModuleCardData module;

  const _ModuleCard({required this.module});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: module.onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: module.accent.withOpacity(0.14),
              borderRadius: AppTheme.chipRadius,
            ),
            child: Icon(module.icon, color: module.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  module.title,
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  module.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_rounded,
              color: AppTheme.textMuted, size: 16),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// OPS SNAPSHOT
// ═══════════════════════════════════════════════════════════════
class _OpsSnapshot extends StatelessWidget {
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> alerts;

  const _OpsSnapshot({
    required this.stats,
    required this.alerts,
  });

  @override
  Widget build(BuildContext context) {
    final criticalAlerts =
        alerts.where((alert) => alert['severity'] == 'critical').length;
    final warningAlerts =
        alerts.where((alert) => alert['severity'] != 'critical').length;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operations Snapshot',
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _SnapshotRow(
            label: 'System health',
            value: '${stats['system_health'] ?? 0}%',
            color: AppTheme.positive,
          ),
          const SizedBox(height: 8),
          _SnapshotRow(
            label: 'Critical alerts',
            value: '$criticalAlerts',
            color: criticalAlerts > 0 ? AppTheme.danger : AppTheme.textMuted,
          ),
          const SizedBox(height: 8),
          _SnapshotRow(
            label: 'Warning alerts',
            value: '$warningAlerts',
            color: warningAlerts > 0 ? AppTheme.warning : AppTheme.textMuted,
          ),
          const SizedBox(height: 8),
          _SnapshotRow(
            label: 'User footprint',
            value: '${stats['registered_users'] ?? 0}',
            color: AppTheme.accent,
          ),
        ],
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SnapshotRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PRIORITY QUEUE — improved spacing and severity badges
// ═══════════════════════════════════════════════════════════════
class _PriorityQueue extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;

  const _PriorityQueue({required this.alerts});

  @override
  Widget build(BuildContext context) {
    final visibleAlerts = alerts.take(4).toList();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Priority Queue',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (visibleAlerts.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.10),
                    borderRadius: AppTheme.chipRadius,
                  ),
                  child: Text(
                    '${visibleAlerts.length} pending',
                    style: GoogleFonts.inter(
                      color: AppTheme.danger,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Highest-signal issues first. Open the correct module from Quick Actions above.',
            style: GoogleFonts.inter(
              color: AppTheme.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (visibleAlerts.isEmpty)
            const _EmptyState(
                message: 'No active issues are waiting for admin review.')
          else
            Column(
              children: visibleAlerts
                  .map((alert) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PriorityItem(alert: alert),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _PriorityItem extends StatelessWidget {
  final Map<String, dynamic> alert;

  const _PriorityItem({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isCritical = alert['severity'] == 'critical';
    final color = isCritical ? AppTheme.danger : AppTheme.warning;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: AppTheme.chipRadius,
            ),
            child: Text(
              isCritical ? 'CRIT' : 'WARN',
              style: GoogleFonts.inter(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert['type']?.toString() ?? 'System alert',
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  alert['description']?.toString() ??
                      'No additional details provided.',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            alert['time']?.toString() ?? '--:--',
            style: GoogleFonts.inter(
              color: AppTheme.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// REAL-TIME ALERTS PANEL
// ═══════════════════════════════════════════════════════════════
class _RecentAlertsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;

  const _RecentAlertsPanel({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sensors_rounded,
                  color: AppTheme.danger, size: 16),
              const SizedBox(width: 6),
              Text(
                'Real-time Alerts',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh,
                  borderRadius: AppTheme.chipRadius,
                ),
                child: Text(
                  '${alerts.length} total',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (alerts.isEmpty)
            const _EmptyState(
                message:
                    'Alert traffic will appear here when the backend reports new issues.')
          else
            Column(
              children: alerts
                  .take(5)
                  .map((alert) => _AlertListTile(alert: alert))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _AlertListTile extends StatelessWidget {
  final Map<String, dynamic> alert;

  const _AlertListTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isCritical = alert['severity'] == 'critical';
    final color = isCritical ? AppTheme.danger : AppTheme.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: AppTheme.chipRadius,
            ),
            child: Icon(
              isCritical
                  ? Icons.priority_high_rounded
                  : Icons.notifications_none_rounded,
              color: color,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert['type']?.toString() ?? 'System alert',
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  alert['description']?.toString() ?? 'No details provided.',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            alert['time']?.toString() ?? '--:--',
            style: GoogleFonts.inter(
              color: AppTheme.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SYNC WARNING
// ═══════════════════════════════════════════════════════════════
class _SyncWarning extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SyncWarning({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      fillColor: AppTheme.warning.withOpacity(0.08),
      borderColor: AppTheme.warning.withOpacity(0.22),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, color: AppTheme.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin summary is temporarily unavailable',
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SHARED UTILITY WIDGETS
// ═══════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: AppTheme.border)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          color: AppTheme.textSecondary,
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }
}
