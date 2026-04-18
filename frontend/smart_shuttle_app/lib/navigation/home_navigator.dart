import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/theme_toggle_button.dart';
import '../screens/student/student_map_screen.dart';
import '../screens/driver/driver_dashboard_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';

class HomeNavigator extends StatelessWidget {
  const HomeNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.background,
              AppTheme.surface,
              AppTheme.gradientAccent.withOpacity(0.35),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 560;
              final horizontalPadding = isCompact ? 18.0 : 24.0;
              final verticalPadding = isCompact ? 20.0 : 26.0;
              final minContentHeight = math.max(
                0.0,
                constraints.maxHeight - (verticalPadding * 2),
              );

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minContentHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isCompact) ...[
                            Row(
                              children: [
                                _GatewayBadge(),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _GatewayTitleBlock(compact: true),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Align(
                              alignment: Alignment.centerRight,
                              child: ThemeToggleButton(compact: true),
                            ),
                          ] else
                            Row(
                              children: [
                                _GatewayBadge(),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: _GatewayTitleBlock(compact: false),
                                ),
                                const ThemeToggleButton(),
                              ],
                            ),
                          const SizedBox(height: 28),
                          Text('Select your workspace',
                              style: GoogleFonts.inter(
                                color: AppTheme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              )),
                          const SizedBox(height: 6),
                          Text(
                              'Choose a role to continue to the correct operational view.',
                              style: GoogleFonts.inter(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              )),
                          const SizedBox(height: 20),
                          _RoleCard(
                            icon: Icons.school_rounded,
                            title: 'Student',
                            subtitle:
                                'Live tracker, ETA visibility, and trip feedback.',
                            accentColor: AppTheme.emerald,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const StudentMapScreen())),
                          ),
                          const SizedBox(height: 14),
                          _RoleCard(
                            icon: Icons.airline_seat_recline_normal_rounded,
                            title: 'Driver',
                            subtitle:
                                'Session controls and AI safety monitoring.',
                            accentColor: AppTheme.amber,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const DriverDashboardScreen())),
                          ),
                          const SizedBox(height: 14),
                          _RoleCard(
                            icon: Icons.admin_panel_settings_rounded,
                            title: 'Admin',
                            subtitle:
                                'Operations, finance, feedback, and account control.',
                            accentColor: AppTheme.accent,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AdminDashboardScreen())),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GatewayBadge extends StatelessWidget {
  const _GatewayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.15),
        borderRadius: AppTheme.borderRadius,
      ),
      child: Icon(
        Icons.directions_bus_rounded,
        color: AppTheme.accent,
        size: 28,
      ),
    );
  }
}

class _GatewayTitleBlock extends StatelessWidget {
  final bool compact;

  const _GatewayTitleBlock({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Smart Shuttle',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: compact ? 20 : 22,
              fontWeight: FontWeight.w800,
            )),
        Text('Role Access Gateway',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: AppTheme.borderRadius,
            ),
            child: Icon(icon, color: accentColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 3),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    )),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              color: AppTheme.textSecondary, size: 16),
        ],
      ),
    );
  }
}
