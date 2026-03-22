// ============================================================
// Smart Shuttle — Admin Lost & Found Screen
// Fixed: Claim verification, status updates via FastAPI
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

class AdminLostFoundScreen extends StatefulWidget {
  const AdminLostFoundScreen({super.key});

  @override
  State<AdminLostFoundScreen> createState() => _AdminLostFoundScreenState();
}

class _AdminLostFoundScreenState extends State<AdminLostFoundScreen> {
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

  Future<void> _handleAction(String endpoint, String itemId) async {
    final adminId = context.read<AppStateProvider>().userEmail ?? 'admin-01';
    
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/lost-found/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'item_id': itemId, 'admin_id': adminId}),
      );
      
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item $endpoint success'), backgroundColor: AppTheme.positive)
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
        title: Text('Lost & Found Admin', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
          }
          final items = (snapshot.data ?? []).where((i) => i['status'] != 'claimed').toList();
          
          if (items.isEmpty) {
            return Center(child: Text('No pending requests', style: GoogleFonts.inter(color: AppTheme.textMuted)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final status = item['status'] ?? 'found';
              final isRequested = status == 'claimRequested';
              final isVerified = status == 'verified';

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(color: AppTheme.surfaceHigh, borderRadius: AppTheme.cardRadius),
                            child: const Icon(Icons.inventory_2_outlined, color: AppTheme.textMuted),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['name'] ?? 'Item', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                                Text('By: ${item['claimedBy'] ?? 'Unknown'}', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isVerified ? AppTheme.positive.withOpacity(0.1) : AppTheme.warning.withOpacity(0.1),
                              borderRadius: AppTheme.chipRadius,
                            ),
                            child: Text(status.toUpperCase(), style: GoogleFonts.inter(color: isVerified ? AppTheme.positive : AppTheme.warning, fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: AppTheme.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isRequested)
                            ElevatedButton(
                              onPressed: () => _handleAction('verify', item['id']),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.positive, elevation: 0),
                              child: Text('Verify Ownership', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          if (isVerified)
                            ElevatedButton(
                              onPressed: () => _handleAction('handover', item['id']),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, elevation: 0),
                              child: Text('Mark Handed Over', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                        ],
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
