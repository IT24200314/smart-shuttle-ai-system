import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../providers/app_state_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/theme_toggle_button.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  String _searchQuery = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _auditLogsStream() {
    return FirebaseFirestore.instance
        .collection('audit_logs')
        .limit(200)
        .snapshots();
  }

  int _timestampPriorityValue(Map<String, dynamic> data) {
    final value =
        data['action_timestamp'] ?? data['timestamp'] ?? data['createdAt'];

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

  Color _actionTypeColor(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('login') || lower.contains('auth')) {
      return AppTheme.accent;
    }
    if (lower.contains('create') || lower.contains('add') || lower.contains('register')) {
      return AppTheme.positive;
    }
    if (lower.contains('delete') || lower.contains('remove') || lower.contains('disable')) {
      return AppTheme.danger;
    }
    if (lower.contains('update') || lower.contains('edit') || lower.contains('modify')) {
      return AppTheme.warning;
    }
    if (lower.contains('view') || lower.contains('read') || lower.contains('access')) {
      return AppTheme.info;
    }
    return AppTheme.textSecondary;
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchQuery.isEmpty) return true;
    final lower = _searchQuery.toLowerCase();
    final fields = [
      data['user_id'],
      data['user'],
      data['actor'],
      data['user_role'],
      data['module_name'],
      data['module'],
      data['action_type'],
      data['action_details'],
      data['activity'],
      data['action'],
      data['device_info'],
      data['device'],
      data['source'],
    ];
    return fields.any((f) => f != null && f.toString().toLowerCase().contains(lower));
  }

  DataRow _buildLiveRow(Map<String, dynamic> data) {
    final time = _formatTimestamp(
        data['action_timestamp'] ?? data['timestamp'] ?? data['createdAt']);
    final user =
        (data['user_id'] ?? data['user'] ?? data['actor'] ?? 'Unknown User')
            .toString();
    final role = (data['user_role'] ?? 'unknown').toString();
    final module =
        (data['module_name'] ?? data['module'] ?? 'General').toString();
    final actionType = (data['action_type'] ?? 'activity').toString();
    final activity = (data['action_details'] ??
            data['activity'] ??
            data['action'] ??
            data['action_type'] ??
            'No activity details')
        .toString();
    final device = (data['device_info'] ??
            data['device'] ??
            data['source'] ??
            'Unknown Device')
        .toString();

    return _buildLogEntry(
        time, user, role, module, actionType, activity, device);
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider to rebuild on theme toggle
    context.watch<AppStateProvider>();
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audit Logs',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text('Recent system and user activity timeline',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        actions: const [
          ThemeToggleButton(compact: true),
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassCard(
                  fillColor: AppTheme.accent.withOpacity(0.07),
                  borderColor: AppTheme.accent.withOpacity(0.22),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Activity Ledger',
                          style: GoogleFonts.inter(
                              color: AppTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(
                        'Monitor account actions, module-level events, and operational changes in near real time.',
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ── Search / Filter Bar ───────────────────────────
                GlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded,
                          color: AppTheme.textMuted, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Search by user, module, action type, or device...',
                            hintStyle: GoogleFonts.inter(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _searchQuery = ''),
                          child: Icon(Icons.close_rounded,
                              color: AppTheme.textMuted, size: 16),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _auditLogsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.accent));
                    }

                    if (snapshot.hasError) {
                      return GlassCard(
                        fillColor: AppTheme.danger.withOpacity(0.12),
                        borderColor: AppTheme.danger.withOpacity(0.28),
                        child: Text(
                          'Unable to load live audit logs. Check Firestore rules or collection setup.',
                          style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }

                    final docs = [
                      ...(snapshot.data?.docs ??
                          const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    ];
                    docs.sort((a, b) => _timestampPriorityValue(b.data())
                        .compareTo(_timestampPriorityValue(a.data())));

                    // Apply search filter
                    final filteredDocs = docs
                        .where((doc) => _matchesSearch(doc.data()))
                        .toList();

                    if (filteredDocs.isEmpty) {
                      return GlassCard(
                        padding: const EdgeInsets.symmetric(
                            vertical: 36, horizontal: 20),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.search_off_rounded,
                                  color: AppTheme.textMuted, size: 32),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No logs match "$_searchQuery"'
                                    : 'No audit log records found yet.',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              if (_searchQuery.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'New entries appear after user or system actions.',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }

                    return GlassCard(
                      padding: const EdgeInsets.all(8),
                      child: Scrollbar(
                        thickness: 4,
                        radius: const Radius.circular(4),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: AppTheme.border,
                            ),
                            child: DataTable(
                              columnSpacing: 16,
                              headingTextStyle: GoogleFonts.inter(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                              dataTextStyle: GoogleFonts.inter(
                                color: AppTheme.textPrimary,
                                fontSize: 12,
                              ),
                              columns: const [
                                DataColumn(label: Text('Time')),
                                DataColumn(label: Text('User')),
                                DataColumn(label: Text('Role')),
                                DataColumn(label: Text('Module')),
                                DataColumn(label: Text('Type')),
                                DataColumn(label: Text('Activity')),
                                DataColumn(label: Text('Device')),
                              ],
                              rows: filteredDocs
                                  .map((doc) => _buildLiveRow(doc.data()))
                                  .toList(),
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
        ),
      ),
    );
  }

  DataRow _buildLogEntry(
    String time,
    String user,
    String role,
    String module,
    String actionType,
    String activity,
    String device,
  ) {
    final typeColor = _actionTypeColor(actionType);

    return DataRow(
      cells: [
        DataCell(SizedBox(
          width: 72,
          child: Text(time,
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        )),
        DataCell(Text(user,
            style:
                GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 12))),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh,
            borderRadius: AppTheme.chipRadius,
          ),
          child: Text(role,
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        )),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.14),
            borderRadius: AppTheme.chipRadius,
          ),
          child: Text(module,
              style: GoogleFonts.inter(
                  color: AppTheme.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        )),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.12),
            borderRadius: AppTheme.chipRadius,
          ),
          child: Text(actionType,
              style: GoogleFonts.inter(
                  color: typeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        )),
        DataCell(Text(activity,
            style:
                GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 12))),
        DataCell(Text(device,
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11))),
      ],
    );
  }
}
