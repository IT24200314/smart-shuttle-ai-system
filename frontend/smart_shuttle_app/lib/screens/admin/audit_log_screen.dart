// ============================================================
// Smart Shuttle — Audit Logs
//
// Primary Focus: Tracking system activities and user actions.
// Theme: Deep Blue professional theme.
// Columns: Time, User, Module, Activity, Device
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _auditLogsStream() {
    return FirebaseFirestore.instance
        .collection('audit_logs')
        // Pull all recent docs without requiring a single indexed timestamp field.
        .limit(200)
        .snapshots();
  }

  int _timestampPriorityValue(Map<String, dynamic> data) {
    final dynamic value = data['action_timestamp'] ?? data['timestamp'] ?? data['createdAt'];

    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }

    if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    }

    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed.millisecondsSinceEpoch;
      }
    }

    return 0;
  }

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }

    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    return 'N/A';
  }

  DataRow _buildLiveRow(Map<String, dynamic> data) {
    final time = _formatTimestamp(data['action_timestamp'] ?? data['timestamp'] ?? data['createdAt']);
    final user = (data['user_id'] ?? data['user'] ?? data['actor'] ?? 'Unknown User').toString();
    final role = (data['user_role'] ?? 'unknown').toString();
    final module = (data['module_name'] ?? data['module'] ?? 'General').toString();
    final actionType = (data['action_type'] ?? 'activity').toString();
    final activity = (data['action_details'] ?? data['activity'] ?? data['action'] ?? data['action_type'] ?? 'No activity details').toString();
    final device = (data['device_info'] ?? data['device'] ?? data['source'] ?? 'Unknown Device').toString();

    return _buildLogEntry(time, user, role, module, actionType, activity, device);
  }

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
                      Text('Live Firebase login and system activity records.',
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

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _auditLogsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Text(
                    'Unable to load live audit logs. Check Firestore rules/collection setup.',
                    style: GoogleFonts.inter(color: Colors.orangeAccent, fontSize: 12),
                  );
                }

                final docs = [...(snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])];
                docs.sort((a, b) => _timestampPriorityValue(b.data()).compareTo(_timestampPriorityValue(a.data())));

                if (docs.isEmpty) {
                  return Text(
                    'No audit log records found yet. Perform a login to generate Firebase audit data.',
                    style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12),
                  );
                }

                return GlassCard(
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
                          columnSpacing: 16,
                          headingRowColor: WidgetStateProperty.resolveWith(
                            (states) => Colors.blueAccent.withValues(alpha: 0.1),
                          ),
                          columns: [
                            DataColumn(label: Text('Time', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('User', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('Role', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('Module', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('Type', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('Activity', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('Device', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                          rows: docs.map((doc) => _buildLiveRow(doc.data())).toList(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildLogEntry(String time, String user, String role, String module, String actionType, String activity, String device) {
    return DataRow(
      cells: [
        DataCell(Text(time, style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12))),
        DataCell(Text(user, style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 12))),
        DataCell(Text(role, style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12))),
        DataCell(Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
            child: Text(module, style: GoogleFonts.inter(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
        )),
        DataCell(Text(actionType, style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11))),
        DataCell(Text(activity, style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 12))),
        DataCell(Text(device, style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11))),
      ],
    );
  }
}
