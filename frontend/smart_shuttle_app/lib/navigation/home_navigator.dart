import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.15),
                            borderRadius: AppTheme.borderRadius,
                          ),
                          child: Icon(Icons.directions_bus_rounded,
                              color: AppTheme.accent, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Smart Shuttle',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                )),
                            Text('Role Access Gateway',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                        const Spacer(),
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
                    Expanded(
                      child: Column(
                        children: [
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 3),
                Text(subtitle,
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
