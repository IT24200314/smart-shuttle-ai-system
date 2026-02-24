// ============================================================
// Smart Shuttle — Home Navigator (Role Selector)
// Hub screen: Student | Driver | Admin
// Integrated System Prototype entry hub
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../screens/student/student_map_screen.dart';
import '../screens/driver/driver_dashboard_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';

class HomeNavigator extends StatelessWidget {
  const HomeNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.darkBlue, AppTheme.deepBlue, Color(0xFF1B3A6B)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withValues(alpha: 0.15),
                        borderRadius: AppTheme.borderRadius,
                      ),
                      child: const Icon(Icons.directions_bus_rounded,
                          color: AppTheme.emerald, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Smart Shuttle',
                            style: GoogleFonts.inter(
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            )),
                        Text('AI Transport System',
                            style: GoogleFonts.inter(
                              color: AppTheme.emerald,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.10),
                    borderRadius: AppTheme.borderRadius,
                    border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                  ),
                  child: Text('Integrated System Prototype',
                      style: GoogleFonts.inter(
                        color: AppTheme.emerald,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      )),
                ),
                const SizedBox(height: 40),
                Text('Select your role to continue',
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    )),
                const SizedBox(height: 20),
                // Role Cards
                Expanded(
                  child: Column(
                    children: [
                      _RoleCard(
                        icon: Icons.school_rounded,
                        title: 'Student',
                        subtitle: 'Track bus, ETA & crowd density',
                        memberIds: 'IT24100100 • IT24100215',
                        accentColor: AppTheme.emerald,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const StudentMapScreen())),
                      ),
                      const SizedBox(height: 16),
                      _RoleCard(
                        icon: Icons.airline_seat_recline_normal_rounded,
                        title: 'Driver',
                        subtitle: 'Session control & AI safety alerts',
                        memberIds: 'IT24100624 • IT24100043',
                        accentColor: AppTheme.amber,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const DriverDashboardScreen())),
                      ),
                      const SizedBox(height: 16),
                      _RoleCard(
                        icon: Icons.admin_panel_settings_rounded,
                        title: 'Admin',
                        subtitle: 'Revenue forecasting & audit logs',
                        memberIds: 'IT24200314 (Individual)',
                        accentColor: const Color(0xFF7C4DFF),
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
                      ),
                    ],
                  ),
                ),
              ],
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
  final String memberIds;
  final Color accentColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.memberIds,
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
              color: accentColor.withValues(alpha: 0.15),
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
                const SizedBox(height: 6),
                Text(memberIds,
                    style: GoogleFonts.inter(
                      color: accentColor.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: AppTheme.textSecondary, size: 16),
        ],
      ),
    );
  }
}
