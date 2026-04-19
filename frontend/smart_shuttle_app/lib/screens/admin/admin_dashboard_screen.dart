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
                  constraints.maxWidth >= 1120 ? 28.0 : 20.0;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (syncError != null) ...[
                          _SyncWarning(
                            message: syncError,
                            onRetry: _reloadAdminSummary,
                          ),
                          const SizedBox(height: 16),
                        ],
                        _DashboardHero(stats: stats),
                        const SizedBox(height: 18),
                        _KpiStrip(stats: stats),
                        const SizedBox(height: 22),
                        const _SectionLabel('Operations Modules'),
                        const SizedBox(height: 12),
                        const _ModuleGrid(),
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

class _DashboardHero extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _DashboardHero({required this.stats});

  @override
  Widget build(BuildContext context) {
    final activeBuses = stats['active_buses'] ?? 0;
    final registeredUsers = stats['registered_users'] ?? 0;

    return GlassCard(
      fillColor: AppTheme.accent.withValues(alpha: 0.07),
      borderColor: AppTheme.accent.withValues(alpha: 0.20),
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useColumn = constraints.maxWidth < 760;
          final headline = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Control Center',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage revenue, rider feedback, users, lost-and-found operations, and audit visibility from one focused workspace.',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
            ],
          );
          final badges = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeaderBadge(
                icon: Icons.directions_bus_rounded,
                label: '$activeBuses fleet online',
                color: AppTheme.accent,
              ),
              _HeaderBadge(
                icon: Icons.manage_accounts_rounded,
                label: '$registeredUsers accounts visible',
                color: AppTheme.secondaryAccent,
              ),
              _HeaderBadge(
                icon: Icons.dashboard_customize_rounded,
                label: 'Web admin workspace',
                color: AppTheme.info,
              ),
            ],
          );

          if (useColumn) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headline,
                const SizedBox(height: 14),
                badges,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: headline),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: badges),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HeaderBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppTheme.chipRadius,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _KpiStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          KpiCard(
            icon: Icons.manage_accounts_rounded,
            label: 'Users',
            value: '${stats['registered_users'] ?? 0}',
            subtitle: 'Students, drivers, and admins in the system',
            accentColor: AppTheme.secondaryAccent,
            compact: true,
          ),
          KpiCard(
            icon: Icons.directions_bus_rounded,
            label: 'Fleet Active',
            value: '${stats['active_buses'] ?? 0}',
            subtitle: 'Buses currently available in live operations',
            accentColor: AppTheme.accent,
            compact: true,
          ),
        ];

        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid();

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width >= 1220
            ? (width - 24) / 3
            : width >= 760
                ? (width - 12) / 2
                : width;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final module in modules)
              SizedBox(
                width: cardWidth,
                child: _ModuleCard(module: module),
              ),
          ],
        );
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 116),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: module.accent.withValues(alpha: 0.14),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    module.subtitle,
                    maxLines: 3,
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
            Icon(
              Icons.arrow_forward_rounded,
              color: AppTheme.textMuted,
              size: 16,
            ),
          ],
        ),
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
      fillColor: AppTheme.warning.withValues(alpha: 0.08),
      borderColor: AppTheme.warning.withValues(alpha: 0.22),
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackActions = constraints.maxWidth < 620;

          final content = Expanded(
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
          );

          if (stackActions) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: AppTheme.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    content,
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                color: AppTheme.warning,
                size: 18,
              ),
              const SizedBox(width: 10),
              content,
              const SizedBox(width: 10),
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          );
        },
      ),
    );
  }
}

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
