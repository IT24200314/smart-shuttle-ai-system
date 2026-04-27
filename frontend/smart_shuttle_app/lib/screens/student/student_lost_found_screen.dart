import 'dart:async';
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

class StudentLostFoundScreen extends StatefulWidget {
  const StudentLostFoundScreen({super.key});

  @override
  State<StudentLostFoundScreen> createState() => _StudentLostFoundScreenState();
}

class _StudentLostFoundScreenState extends State<StudentLostFoundScreen> {
  late Future<_LostFoundStudentData> _dataFuture;
  _LostFoundStudentData _latestData = _LostFoundStudentData.empty();

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchData();
  }

  Future<_LostFoundStudentData> _fetchData() async {
    final studentId =
        context.read<AppStateProvider>().userEmail ?? 'student-01';
    final itemsRes = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/lost-found/items/available'))
        .timeout(const Duration(seconds: 10));
    final claimsRes = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/lost-found/claims'))
        .timeout(const Duration(seconds: 10));
    if (itemsRes.statusCode != 200 || claimsRes.statusCode != 200) {
      throw Exception('Lost & Found refresh failed');
    }

    final itemsBody = Map<String, dynamic>.from(json.decode(itemsRes.body));
    final claimsBody = Map<String, dynamic>.from(json.decode(claimsRes.body));
    final items = List<dynamic>.from(itemsBody['items'] ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final claims = List<dynamic>.from(claimsBody['claims'] ?? const [])
        .map((claim) => Map<String, dynamic>.from(claim as Map))
        .where((claim) =>
            (claim['studentId'] ?? claim['student_id'])?.toString() ==
            studentId)
        .toList();
    final data = _LostFoundStudentData(items: items, claims: claims);
    _latestData = data;
    return data;
  }

  Future<void> _reload() async {
    setState(() => _dataFuture = _fetchData());
    await _dataFuture;
  }

  Future<void> _refreshInBackground() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final data = await _fetchData();
      if (!mounted) return;
      setState(() => _dataFuture = Future.value(data));
    } catch (exc) {
      debugPrint('Lost & Found background refresh failed: $exc');
      if (mounted) {
        setState(() => _dataFuture = Future.value(_latestData));
      }
    }
  }

  Future<void> _handleClaim(String itemId) async {
    final provider = context.read<AppStateProvider>();
    final studentId = provider.userEmail ?? 'student-01';
    final studentName = provider.userName ?? 'Student';

    http.Response res;
    try {
      res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/lost-found/items/$itemId/claim'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'studentId': studentId,
          'studentEmail': studentId,
          'studentName': studentName,
          'message': 'I believe this item belongs to me.',
        }),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Network error while sending claim request.',
            style: GoogleFonts.inter(color: AppTheme.onAccent),
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    if (!mounted) return;
    final ok = res.statusCode == 200;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? _messageFromResponse(res, 'Claim request sent to admin.')
              : _messageFromResponse(res, 'Unable to send claim request.'),
          style: GoogleFonts.inter(color: AppTheme.onAccent),
        ),
        backgroundColor: ok ? AppTheme.positive : AppTheme.danger,
      ),
    );

    if (ok) {
      _applyClaimLocally(res, itemId);
      unawaited(_refreshInBackground());
    }
  }

  void _applyClaimLocally(http.Response response, String itemId) {
    final claim = _claimFromResponse(response);
    if (claim == null) return;
    final items = _latestData.items
        .where((item) => (item['itemId'] ?? item['id']).toString() != itemId)
        .toList();
    final claims = [
      claim,
      ..._latestData.claims.where((existing) =>
          (existing['itemId'] ?? existing['item_id']).toString() != itemId),
    ];
    final data = _LostFoundStudentData(items: items, claims: claims);
    _latestData = data;
    if (mounted) {
      setState(() => _dataFuture = Future.value(data));
    }
  }

  Map<String, dynamic>? _claimFromResponse(http.Response response) {
    try {
      final payload = json.decode(response.body);
      if (payload is Map<String, dynamic> && payload['claim'] is Map) {
        return Map<String, dynamic>.from(payload['claim'] as Map);
      }
    } catch (_) {}
    return null;
  }

  String _messageFromResponse(http.Response response, String fallback) {
    try {
      final payload = json.decode(response.body);
      if (payload is Map<String, dynamic>) {
        return payload['message']?.toString() ??
            payload['detail']?.toString() ??
            fallback;
      }
    } catch (_) {}
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
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
            Text('Available items and your claim status',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          const ThemeToggleButton(compact: true),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<_LostFoundStudentData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: AppTheme.accent));
          }
          if (snapshot.hasError) {
            return const _EmptyState(
              title: 'Lost & Found is unavailable',
              subtitle: 'Please refresh after the backend is running.',
            );
          }

          final data = snapshot.data ?? _latestData;
          final activeClaims = {
            for (final claim in data.claims)
              if ({'pending', 'pending_verification', 'approved'}
                  .contains((claim['status'] ?? '').toString().toLowerCase()))
                (claim['itemId'] ?? claim['item_id']).toString(): claim,
          };

          return RefreshIndicator(
            onRefresh: _reload,
            color: AppTheme.accent,
            backgroundColor: AppTheme.surfaceHigh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                GlassCard(
                  fillColor: AppTheme.accent.withValues(alpha: 0.07),
                  borderColor: AppTheme.accent.withValues(alpha: 0.22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Available Lost Items',
                          style: GoogleFonts.inter(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(
                        'Items detected by the shuttle AI appear here after the driver ends a trip.',
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
                if (data.items.isEmpty)
                  const _EmptyState(
                    title: 'No available items',
                    subtitle:
                        'Detected items will appear here after the demo video runs.',
                  )
                else
                  ...data.items.map((item) {
                    final itemId =
                        (item['itemId'] ?? item['id'] ?? '').toString();
                    final activeClaim = activeClaims[itemId];
                    return _StudentItemCard(
                      item: item,
                      activeClaim: activeClaim,
                      onClaim: () => _handleClaim(itemId),
                    );
                  }),
                if (data.claims.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('My Requests',
                      style: GoogleFonts.inter(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ...data.claims.map((claim) => _ClaimStatusCard(claim: claim)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LostFoundStudentData {
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> claims;

  const _LostFoundStudentData({required this.items, required this.claims});

  factory _LostFoundStudentData.empty() =>
      const _LostFoundStudentData(items: [], claims: []);
}

class _StudentItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Map<String, dynamic>? activeClaim;
  final VoidCallback onClaim;

  const _StudentItemCard({
    required this.item,
    required this.activeClaim,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = activeClaim != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHigh,
                    borderRadius: AppTheme.cardRadius,
                  ),
                  child: Icon(Icons.inventory_2_outlined,
                      color: AppTheme.textMuted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (item['itemName'] ?? item['name'] ?? 'Item').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (item['description'] ?? item['notes'] ?? 'Found on bus')
                            .toString(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Detected: ${item['detectedAt'] ?? item['foundedAt'] ?? '--'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: AppTheme.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: disabled ? null : onClaim,
                icon: Icon(
                  disabled
                      ? Icons.hourglass_top_rounded
                      : Icons.assignment_rounded,
                  size: 16,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      disabled ? AppTheme.surfaceHigh : AppTheme.accent,
                  foregroundColor:
                      disabled ? AppTheme.textSecondary : AppTheme.onAccent,
                  elevation: 0,
                ),
                label: Text(
                  disabled
                      ? 'Request ${activeClaim?['status'] ?? 'pending'}'
                      : 'Request Claim',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimStatusCard extends StatelessWidget {
  final Map<String, dynamic> claim;

  const _ClaimStatusCard({required this.claim});

  @override
  Widget build(BuildContext context) {
    final status = (claim['status'] ?? 'pending').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: AppTheme.accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${claim['itemName'] ?? claim['itemId'] ?? 'Item'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              status.toUpperCase(),
              style: GoogleFonts.inter(
                  color: _statusColor(status),
                  fontSize: 10,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'collected':
        return AppTheme.positive;
      case 'rejected':
      case 'cancelled':
        return AppTheme.danger;
      default:
        return AppTheme.warning;
    }
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: AppTheme.textMuted, size: 34),
          const SizedBox(height: 12),
          Text(title,
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary, fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }
}
