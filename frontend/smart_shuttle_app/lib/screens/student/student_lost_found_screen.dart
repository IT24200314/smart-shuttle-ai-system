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
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/lost-found/items'));
      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(json.decode(res.body));
        return data['items'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  Future<void> _handleClaim(String itemId) async {
    final studentId = context.read<AppStateProvider>().userEmail ?? 'student-01';
    
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/lost-found/claim'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'item_id': itemId, 'student_id': studentId}),
      );
      
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim request sent to admin'), backgroundColor: AppTheme.positive)
        );
        setState(() {
          _itemsFuture = _fetchItems();
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Lost & Found', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(child: Text('No found items reported', style: GoogleFonts.inter(color: AppTheme.textMuted)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final status = item['status'] ?? 'found';
              final isClaimed = status == 'claimRequested' || status == 'verified' || status == 'claimed';

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(color: AppTheme.surfaceHigh, borderRadius: AppTheme.cardRadius),
                        child: const Icon(Icons.inventory_2_outlined, color: AppTheme.textMuted),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['name'] ?? 'Item', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                            Text(item['description'] ?? 'Found on bus', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('Date: ${item['foundedAt'] ?? 'Today'}', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: isClaimed ? null : () => _handleClaim(item['id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isClaimed ? Colors.transparent : AppTheme.accent,
                          shape: RoundedRectangleBorder(borderRadius: AppTheme.chipRadius),
                          elevation: 0,
                        ),
                        child: Text(isClaimed ? 'Claimed' : 'Claim', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
