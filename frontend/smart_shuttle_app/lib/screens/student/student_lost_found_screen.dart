// ============================================================
// Smart Shuttle — Student Lost & Found Screen
// Fixed: Data fetching from FastAPI, claim request flow
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_config.dart';
import '../../providers/app_state_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/theme_toggle_button.dart';

class StudentLostFoundScreen extends StatefulWidget {
  const StudentLostFoundScreen({super.key});

  @override
  State<StudentLostFoundScreen> createState() => _StudentLostFoundScreenState();
}

class _StudentLostFoundScreenState extends State<StudentLostFoundScreen> {
  late Future<List<dynamic>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _fetchItems();
  }

  Future<List<dynamic>> _fetchItems() async {
    try {
      final res =
          await http.get(Uri.parse('${ApiConfig.baseUrl}/lost-found/items'));
      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(json.decode(res.body));
        return data['items'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  Future<void> _handleClaim(String itemId) async {
    final studentId =
        context.read<AppStateProvider>().userEmail ?? 'student-01';

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/lost-found/claim'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'item_id': itemId, 'student_id': studentId}),
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Claim request sent to admin'),
            backgroundColor: AppTheme.positive));
        setState(() {
          _itemsFuture = _fetchItems();
        });
      }
    } catch (_) {}
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
            Text('Lost & Found',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text('Submit and track your item claims',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        actions: const [
          ThemeToggleButton(compact: true),
          SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: AppTheme.accent));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
                child: Text('No found items reported',
                    style: GoogleFonts.inter(color: AppTheme.textMuted)));
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GlassCard(
                fillColor: AppTheme.accent.withOpacity(0.07),
                borderColor: AppTheme.accent.withOpacity(0.22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reported Items',
                        style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      'Review item descriptions and submit a claim request. Admin approval is required before handover.',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ...items.map((item) {
                final status = item['status'] ?? 'found';
                final isClaimed = status == 'claimRequested' ||
                    status == 'verified' ||
                    status == 'claimed';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                  color: AppTheme.surfaceHigh,
                                  borderRadius: AppTheme.cardRadius),
                              child: Icon(Icons.inventory_2_outlined,
                                  color: AppTheme.textMuted),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'] ?? 'Item',
                                      style: GoogleFonts.inter(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text(item['description'] ?? 'Found on bus',
                                      style: GoogleFonts.inter(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text('Date: ${item['foundedAt'] ?? 'Today'}',
                                      style: GoogleFonts.inter(
                                          color: AppTheme.textMuted,
                                          fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isClaimed
                                ? null
                                : () => _handleClaim(item['id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isClaimed
                                  ? AppTheme.surfaceHigh
                                  : AppTheme.accent,
                              foregroundColor: isClaimed
                                  ? AppTheme.textSecondary
                                  : AppTheme.onAccent,
                              elevation: 0,
                            ),
                            child: Text(
                                isClaimed
                                    ? 'Claim In Progress'
                                    : 'Request Claim',
                                style: GoogleFonts.inter(
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
