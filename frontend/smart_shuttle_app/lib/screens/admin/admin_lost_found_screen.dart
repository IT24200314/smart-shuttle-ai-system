import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_config.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/theme_toggle_button.dart';

class AdminLostFoundScreen extends StatefulWidget {
  const AdminLostFoundScreen({super.key});

  @override
  State<AdminLostFoundScreen> createState() => _AdminLostFoundScreenState();
}

class _AdminLostFoundScreenState extends State<AdminLostFoundScreen> {
  late Future<List<Map<String, dynamic>>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _fetchItems();
  }

  Future<List<Map<String, dynamic>>> _fetchItems() async {
    try {
      final res = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/lost-found/items'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(json.decode(res.body));
        final items = List<dynamic>.from(data['items'] ?? const []);
        return items
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
    } catch (_) {
      // Keep fallback list empty for resilient UI.
    }
    return [];
  }

  Future<void> _reloadItems() async {
    setState(() {
      _itemsFuture = _fetchItems();
    });
    await _itemsFuture;
  }

  Future<void> _handleAction(String endpoint, String itemId) async {
    final adminId = context.read<AppStateProvider>().userEmail ?? 'admin-01';

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/lost-found/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'item_id': itemId, 'admin_id': adminId}),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              endpoint == 'verify'
                  ? 'Ownership verified successfully.'
                  : 'Handover marked successfully.',
              style: GoogleFonts.inter(color: AppTheme.onAccent),
            ),
            backgroundColor: AppTheme.positive,
          ),
        );
        await _reloadItems();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to update item status.',
              style: GoogleFonts.inter(color: AppTheme.onAccent),
            ),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Network error while updating item status.',
            style: GoogleFonts.inter(color: AppTheme.onAccent),
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
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
            Text('Lost And Found Operations',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text('Verify ownership and close pending requests',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          const ThemeToggleButton(compact: true),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reloadItems,
            icon: Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: AppTheme.accent));
          }

          final allItems = snapshot.data ?? const [];
          final pendingItems =
              allItems.where((item) => item['status'] != 'claimed').toList();
          final claimRequested = pendingItems
              .where((item) => (item['status'] ?? '') == 'claimRequested')
              .length;
          final verified = pendingItems
              .where((item) => (item['status'] ?? '') == 'verified')
              .length;
          final handedOver = allItems
              .where((item) => (item['status'] ?? '') == 'claimed')
              .length;

          return RefreshIndicator(
            onRefresh: _reloadItems,
            color: AppTheme.accent,
            backgroundColor: AppTheme.surfaceHigh,
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1360),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LostFoundHero(
                          totalReported: allItems.length,
                          totalPending: pendingItems.length,
                          claimRequested: claimRequested,
                          verified: verified,
                          handedOver: handedOver,
                        ),
                        const SizedBox(height: 16),
                        if (pendingItems.isEmpty)
                          GlassCard(
                            padding: const EdgeInsets.symmetric(
                                vertical: 48, horizontal: 24),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color:
                                          AppTheme.positive.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: AppTheme.positive,
                                      size: 44,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'All Clear',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No pending claim requests in queue.\nNew ownership verification requests will appear here automatically.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                      height: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceHigh,
                                      borderRadius: AppTheme.chipRadius,
                                      border:
                                          Border.all(color: AppTheme.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.info_outline_rounded,
                                            size: 14,
                                            color: AppTheme.textMuted),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Students can report items from the Lost & Found screen',
                                          style: GoogleFonts.inter(
                                            color: AppTheme.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...pendingItems.map((item) {
                            final status =
                                item['status']?.toString() ?? 'found';
                            final isRequested = status == 'claimRequested';
                            final isVerified = status == 'verified';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                padding: const EdgeInsets.all(16),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isWide = constraints.maxWidth > 900;
                                    final content = _ItemDetails(item: item);
                                    final actions = _ItemActions(
                                      status: status,
                                      isRequested: isRequested,
                                      isVerified: isVerified,
                                      onVerify: () => _handleAction(
                                        'verify',
                                        item['id']?.toString() ?? '',
                                      ),
                                      onHandover: () => _handleAction(
                                        'handover',
                                        item['id']?.toString() ?? '',
                                      ),
                                    );

                                    if (!isWide) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          content,
                                          const SizedBox(height: 14),
                                          actions,
                                        ],
                                      );
                                    }

                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: content),
                                        const SizedBox(width: 16),
                                        Flexible(
                                          child: Align(
                                            alignment: Alignment.topRight,
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 260,
                                              ),
                                              child: actions,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LostFoundHero extends StatelessWidget {
  final int totalReported;
  final int totalPending;
  final int claimRequested;
  final int verified;
  final int handedOver;

  const _LostFoundHero({
    required this.totalReported,
    required this.totalPending,
    required this.claimRequested,
    required this.verified,
    required this.handedOver,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      fillColor: AppTheme.accent.withOpacity(0.07),
      borderColor: AppTheme.accent.withOpacity(0.22),
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 820;

          final summary = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryChip(
                  label: 'Total Reported',
                  value: '$totalReported',
                  color: AppTheme.info),
              _SummaryChip(
                  label: 'Pending',
                  value: '$totalPending',
                  color: AppTheme.accent),
              _SummaryChip(
                  label: 'Claims Requested',
                  value: '$claimRequested',
                  color: AppTheme.warning),
              _SummaryChip(
                  label: 'Verified',
                  value: '$verified',
                  color: AppTheme.positive),
              _SummaryChip(
                  label: 'Handed Over',
                  value: '$handedOver',
                  color: AppTheme.textMuted),
            ],
          );

          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeroText(),
                const SizedBox(height: 14),
                summary,
              ],
            );
          }

          return Row(
            children: [
              const Expanded(child: _HeroText()),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: summary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Claim verification queue',
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Review ownership requests quickly, verify valid claims, and complete handover without switching screens.',
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: AppTheme.chipRadius,
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemDetails extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ItemDetails({required this.item});

  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString() ?? 'found';
    final badgeColor =
        status == 'verified' ? AppTheme.positive : AppTheme.warning;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh,
            borderRadius: AppTheme.cardRadius,
          ),
          child: Icon(Icons.inventory_2_outlined, color: AppTheme.textMuted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item['name']?.toString() ?? 'Item',
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: AppTheme.chipRadius,
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: badgeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item['description']?.toString() ?? 'No description provided.',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _MetaItem(
                    icon: Icons.person_outline_rounded,
                    text: 'Claimed by: ${item['claimedBy'] ?? 'Unknown'}',
                  ),
                  _MetaItem(
                    icon: Icons.badge_outlined,
                    text: 'Item ID: ${item['id'] ?? '--'}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemActions extends StatelessWidget {
  final String status;
  final bool isRequested;
  final bool isVerified;
  final VoidCallback onVerify;
  final VoidCallback onHandover;

  const _ItemActions({
    required this.status,
    required this.isRequested,
    required this.isVerified,
    required this.onVerify,
    required this.onHandover,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Actions',
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (isRequested)
          ElevatedButton.icon(
            onPressed: onVerify,
            icon: const Icon(Icons.verified_user_rounded, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.positive,
              foregroundColor: AppTheme.onPositive,
            ),
            label: const Text('Verify Ownership'),
          )
        else if (isVerified)
          ElevatedButton.icon(
            onPressed: onHandover,
            icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
            label: const Text('Mark Handed Over'),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: AppTheme.chipRadius,
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              'Waiting for a claim request. Current status: $status',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }
}
