// ============================================================
// Smart Shuttle — Audit Logs
//
// Primary Focus: Tracking system activities and user actions.
// Theme: Deep Blue professional theme.
// Columns: Time, User, Module, Activity, Device
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('System Audit Logs',
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, color: Colors.blueAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recent Activity Logs',
                          style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('Comprehensive view of all system actions.',
                          style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppTheme.emerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text('LIVE',
                      style: GoogleFonts.inter(color: AppTheme.emerald, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Audit Log Table wrapped in a GlassCard
            GlassCard(
              padding: const EdgeInsets.all(2),
              borderColor: Colors.blueAccent.withValues(alpha: 0.3),
              child: Scrollbar(
                thickness: 4,
                radius: const Radius.circular(4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.white10,
                    ),
                    child: DataTable(
                      columnSpacing: 16, // Reduced spacing to fit more columns
                      headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.blueAccent.withValues(alpha: 0.1)),
                      columns: [
                        DataColumn(label: Text('Time', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('User', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Module', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Activity', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Device', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                      rows: [
                        _buildLogEntry('10:45 AM', 'Admin (Kamal)', 'Dashboard', 'Updated Alert Thresholds', 'Windows Desktop'),
                        _buildLogEntry('10:30 AM', 'System AI', 'Fleet', 'Flagged Bus 08', 'AI Server Node'),
                        _buildLogEntry('09:15 AM', 'Driver (Nimal)', 'Mobile', 'Started Route K-01', 'Android (Pixel 7)'),
                        _buildLogEntry('08:50 AM', 'Rev. Mgr', 'Finance', 'Generated Weekly Report', 'MacBook Air'),
                        _buildLogEntry('08:00 AM', 'System', 'Auth', 'Daily system startup routine completed', 'Main Server'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildLogEntry(String time, String user, String module, String activity, String device) {
    return DataRow(
      cells: [
        DataCell(Text(time, style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12))),
        DataCell(Text(user, style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 12))),
        DataCell(Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
            child: Text(module, style: GoogleFonts.inter(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
        )),
        DataCell(Text(activity, style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 12))),
        DataCell(Text(device, style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11))),
      ],
    );
  }
}
