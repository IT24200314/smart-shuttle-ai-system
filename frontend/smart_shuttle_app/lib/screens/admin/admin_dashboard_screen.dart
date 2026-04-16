import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';
import '../../theme/app_theme.dart';
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
          .get(Uri.parse('${ApiConfig.baseUrl}/admin/summary'))
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
                  'Admin Control Center',
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Operational overview for Smart Shuttle',
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
                icon: Icon(
                  Icons.refresh_rounded,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding =
                  constraints.maxWidth >= 1100 ? 24.0 : 16.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (syncError != null) ...[
                          _SyncWarning(
                            message: syncError,
                            onRetry: _reloadAdminSummary,
                          ),
                          const SizedBox(height: 14),
                        ],
                        _DashboardHeader(alerts: alerts),
                        const SizedBox(height: 18),
                        const _SectionLabel('Key Metrics'),
                        const SizedBox(height: 10),
                        _KpiSection(stats: stats),
                        const SizedBox(height: 18),
                        const _SectionLabel('Quick Actions'),
                        const SizedBox(height: 12),
                        _ActionGrid(),
                        const SizedBox(height: 18),
                        const _SectionLabel('Real-time Alerts'),
                        const SizedBox(height: 10),
                        _AlertsPanel(alerts: alerts),
                      ],
                    ),
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

class _DashboardHeader extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;

  const _DashboardHeader({required this.alerts});

  @override
  Widget build(BuildContext context) {
    final criticalAlerts =
        alerts.where((alert) => alert['severity'] == 'critical').length;
    final summaryText = alerts.isEmpty
        ? 'Operations are steady right now. Use quick actions below to move between finance, support, and account workflows.'
        : 'Live issues are coming in. Review quick actions and the alert feed below to respond without extra dashboard clutter.';

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 820;
          final narrative = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentDim,
                  borderRadius: AppTheme.cardRadius,
                ),
                child: Text(
                  'Operational admin panel',
                  style: GoogleFonts.inter(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Keep the admin workspace focused on the decisions that matter.',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                summaryText,
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  height: 1.55,
                ),
              ),
            ],
          );

          final summaryCard = Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh.withOpacity(0.82),
              borderRadius: AppTheme.cardRadius,
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live signal',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _HeaderStat(
                  label: 'Open alerts',
                  value: '${alerts.length}',
                  color: alerts.isEmpty ? AppTheme.positive : AppTheme.warning,
                ),
                const SizedBox(height: 8),
                _HeaderStat(
                  label: 'Critical',
                  value: '$criticalAlerts',
                  color:
                      criticalAlerts > 0 ? AppTheme.danger : AppTheme.textMuted,
                ),
                const SizedBox(height: 8),
                _HeaderStat(
                  label: 'Modules ready',
                  value: '5',
                  color: AppTheme.accent,
                ),
              ],
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                narrative,
                const SizedBox(height: 16),
                summaryCard,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: narrative),
              const SizedBox(width: 16),
              SizedBox(width: 248, child: summaryCard),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeaderStat({
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
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _KpiSection extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _KpiSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        return GridView.count(
          crossAxisCount: isWide ? 2 : 1,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isWide ? 2.85 : 2.55,
          children: [
            KpiCard(
              icon: Icons.warning_amber_rounded,
              label: 'Risk Alerts',
              value: '${stats['risk_alerts'] ?? 0}',
              subtitle: (stats['risk_alerts'] ?? 0) == 0
                  ? 'No current escalations need review.'
                  : 'Active incidents require admin attention.',
              isPositive: (stats['risk_alerts'] ?? 0) == 0,
              accentColor: AppTheme.warning,
              compact: true,
            ),
            KpiCard(
              icon: Icons.manage_accounts_rounded,
              label: 'Users',
              value: '${stats['registered_users'] ?? 0}',
              subtitle: 'Registered students, drivers, and admins.',
              accentColor: AppTheme.accent,
              compact: true,
            ),
          ],
        );
      },
    );
  }
}

class _ActionGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionCardData(
        title: 'Revenue',
        subtitle:
            'Review trip revenue, ticket breakdowns, and business trends.',
        icon: Icons.bar_chart_rounded,
        accent: AppTheme.positive,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RevenueDashboardScreen()),
        ),
      ),
      _ActionCardData(
        title: 'Feedback',
        subtitle: 'Inspect rider comments, ratings, and experience issues.',
        icon: Icons.rate_review_rounded,
        accent: AppTheme.accent,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminFeedbackScreen()),
        ),
      ),
      _ActionCardData(
        title: 'Lost & Found',
        subtitle: 'Manage claim resolution and item handover workflows.',
        icon: Icons.search_rounded,
        accent: AppTheme.warning,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminLostFoundScreen()),
        ),
      ),
      _ActionCardData(
        title: 'Users',
        subtitle: 'Control access, account status, and role assignments.',
        icon: Icons.people_alt_rounded,
        accent: AppTheme.secondaryAccent,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
        ),
      ),
      _ActionCardData(
        title: 'Audit Log',
        subtitle: 'Trace important user actions and system activity.',
        icon: Icons.history_rounded,
        accent: AppTheme.info,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AuditLogScreen()),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1220
            ? 5
            : width >= 980
                ? 3
                : width >= 760
                    ? 2
                    : 1;
        final aspectRatio = columns == 1
            ? 2.65
            : columns == 2
                ? 2.05
                : columns == 3
                    ? 1.72
                    : 1.34;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            return _ActionCard(action: actions[index]);
          },
        );
      },
    );
  }
}

class _ActionCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _ActionCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
}

class _ActionCard extends StatelessWidget {
  final _ActionCardData action;

  const _ActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: action.onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: action.accent.withOpacity(
                    AppTheme.isDarkMode ? 0.16 : 0.11,
                  ),
                  borderRadius: AppTheme.cardRadius,
                ),
                child: Icon(action.icon, color: action.accent, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh,
                  borderRadius: AppTheme.cardRadius,
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Open',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_outward_rounded,
                      color: AppTheme.textMuted,
                      size: 13,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            action.title,
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              action.subtitle,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;

  const _AlertsPanel({required this.alerts});

  @override
  Widget build(BuildContext context) {
    final criticalAlerts =
        alerts.where((alert) => alert['severity'] == 'critical').length;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sensors_rounded, color: AppTheme.danger, size: 17),
              const SizedBox(width: 8),
              Text(
                'Real-time Alerts',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh,
                  borderRadius: AppTheme.cardRadius,
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  '${alerts.length} total',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            criticalAlerts == 0
                ? 'The live alert feed stays here for backend incidents and operational checks as they happen.'
                : '$criticalAlerts critical issue${criticalAlerts == 1 ? '' : 's'} need attention in the live feed.',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 11.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            const _EmptyState(
              message:
                  'Alert traffic will appear here when the backend reports new issues.',
            )
          else
            Column(
              children: alerts
                  .take(5)
                  .map(
                    (alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _AlertTile(alert: alert),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final Map<String, dynamic> alert;

  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isCritical = alert['severity'] == 'critical';
    final tone = isCritical ? AppTheme.danger : AppTheme.warning;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tone.withOpacity(AppTheme.isDarkMode ? 0.08 : 0.07),
        borderRadius: AppTheme.cardRadius,
        border: Border.all(
          color: tone.withOpacity(AppTheme.isDarkMode ? 0.20 : 0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.withOpacity(AppTheme.isDarkMode ? 0.16 : 0.12),
              borderRadius: AppTheme.cardRadius,
            ),
            child: Icon(
              isCritical
                  ? Icons.priority_high_rounded
                  : Icons.notifications_active_outlined,
              color: tone,
              size: 17,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert['type']?.toString() ?? 'System alert',
                        style: GoogleFonts.inter(
                          color: AppTheme.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tone.withOpacity(
                          AppTheme.isDarkMode ? 0.14 : 0.10,
                        ),
                        borderRadius: AppTheme.cardRadius,
                      ),
                      child: Text(
                        isCritical ? 'Critical' : 'Warning',
                        style: GoogleFonts.inter(
                          color: tone,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alert['description']?.toString() ??
                      'No additional details provided.',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  alert['time']?.toString() ?? '--:--',
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
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
                    height: 1.5,
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

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: AppTheme.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          color: AppTheme.textSecondary,
          fontSize: 11.5,
          height: 1.55,
        ),
      ),
    );
  }
}
