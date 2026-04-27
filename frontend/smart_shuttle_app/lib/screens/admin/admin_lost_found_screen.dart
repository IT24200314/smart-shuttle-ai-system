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
  late Future<_LostFoundAdminData> _dataFuture;
  _LostFoundAdminData _latestData = _LostFoundAdminData.empty();
  final Set<String> _busyActions = <String>{};
  bool _hasLoadedData = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchData();
  }

  Future<_LostFoundAdminData> _fetchData() async {
    final itemsRes = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/lost-found/items'))
        .timeout(const Duration(seconds: 10));
    final claimsRes = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/lost-found/claims'))
        .timeout(const Duration(seconds: 10));
    if (itemsRes.statusCode != 200 || claimsRes.statusCode != 200) {
      throw Exception('Lost & Found refresh failed');
    }
    final itemsBody = Map<String, dynamic>.from(json.decode(itemsRes.body));
    final claimsBody = Map<String, dynamic>.from(json.decode(claimsRes.body));
    final data = _LostFoundAdminData(
      items: List<dynamic>.from(itemsBody['items'] ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      claims: List<dynamic>.from(claimsBody['claims'] ?? const [])
          .map((claim) => Map<String, dynamic>.from(claim as Map))
          .toList(),
    );
    _latestData = data;
    _hasLoadedData = true;
    return data;
  }

  Future<void> _reload() async {
    setState(() {
      _dataFuture = _fetchData();
    });
    await _dataFuture;
  }

  Future<void> _claimAction(Map<String, dynamic> claim, String action) async {
    final claimId =
        (claim['claimId'] ?? claim['id'] ?? claim['claim_id']).toString();
    final adminId = context.read<AppStateProvider>().userEmail ?? 'admin-01';
    await _performPostAction(
      actionKey: '$claimId:$action',
      successMessage: 'Claim $action completed.',
      path: '/lost-found/claims/$claimId/$action',
      body: {'adminId': adminId, 'adminNote': 'Updated from admin dashboard'},
      onSuccess: (res) => _applyClaimActionLocally(res, action, claim),
    );
  }

  Future<void> _markCollected(String itemId, String? claimId) async {
    final adminId = context.read<AppStateProvider>().userEmail ?? 'admin-01';
    await _performPostAction(
      actionKey: '$itemId:collected',
      successMessage: 'Item marked as collected.',
      path: '/lost-found/items/$itemId/mark-collected',
      body: {'adminId': adminId, if (claimId != null) 'claimId': claimId},
      onSuccess: (res) => _applyCollectedLocally(res, itemId),
    );
  }

  Future<void> _performPostAction({
    required String actionKey,
    required String successMessage,
    required String path,
    required Map<String, dynamic> body,
    void Function(http.Response response)? onSuccess,
  }) async {
    if (_busyActions.contains(actionKey)) return;
    setState(() {
      _busyActions.add(actionKey);
    });

    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        throw Exception(
          _messageFromResponse(res, 'Unable to update Lost & Found status.'),
        );
      }

      onSuccess?.call(res);

      if (!mounted) return;
      setState(() {
        _busyActions.remove(actionKey);
      });
      _showMessage(successMessage, success: true);

      try {
        final freshData =
            await _fetchData().timeout(const Duration(seconds: 12));
        if (!mounted) return;
        _setLatestData(freshData);
      } catch (refreshError) {
        debugPrint('Lost & Found refresh failed after action: $refreshError');
        if (mounted) {
          setState(() {
            _dataFuture = Future.value(_latestData);
          });
        }
      }
    } catch (exc) {
      if (!mounted) return;
      _showMessage('Action failed: $exc', success: false);
    } finally {
      if (mounted && _busyActions.contains(actionKey)) {
        setState(() {
          _busyActions.remove(actionKey);
        });
      }
    }
  }

  void _showMessage(String message, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: AppTheme.onAccent),
        ),
        backgroundColor: success ? AppTheme.positive : AppTheme.danger,
      ),
    );
  }

  void _setLatestData(_LostFoundAdminData data) {
    _latestData = data;
    _hasLoadedData = true;
    if (mounted) {
      setState(() {
        _dataFuture = Future.value(data);
      });
    }
  }

  void _applyClaimActionLocally(
    http.Response response,
    String fallbackAction,
    Map<String, dynamic> fallbackClaim,
  ) {
    final responseClaim = _claimFromResponse(response);
    final status = _statusForAction(
      (responseClaim?['status'] ?? fallbackAction).toString(),
    );
    final claim = {
      ...fallbackClaim,
      if (responseClaim != null) ...responseClaim,
      'status': status,
    };

    final claimId =
        (claim['claimId'] ?? claim['id'] ?? claim['claim_id']).toString();
    final itemId = (claim['itemId'] ?? claim['item_id'] ?? '').toString();
    final updatedClaims = _latestData.claims.map((existing) {
      final existingId =
          (existing['claimId'] ?? existing['id'] ?? existing['claim_id'])
              .toString();
      if (existingId != claimId) return existing;
      return {...existing, ...claim, 'status': status};
    }).toList();

    final updatedItems = _latestData.items.map((item) {
      final existingItemId = (item['itemId'] ?? item['id']).toString();
      if (existingItemId != itemId) return item;
      final itemStatus =
          status == 'cancelled' || status == 'rejected' ? 'available' : status;
      return {
        ...item,
        'status': itemStatus,
        'claimRequestId':
            status == 'cancelled' || status == 'rejected' ? null : claimId,
        'claimedBy': status == 'cancelled' || status == 'rejected'
            ? null
            : claim['studentId'],
      };
    }).toList();

    _setLatestData(
        _LostFoundAdminData(items: updatedItems, claims: updatedClaims));
  }

  void _applyCollectedLocally(http.Response response, String itemId) {
    final claim = _claimFromResponse(response);
    final claimId =
        (claim?['claimId'] ?? claim?['id'] ?? claim?['claim_id'] ?? '')
            .toString();

    final updatedClaims = _latestData.claims.map((existing) {
      final existingId =
          (existing['claimId'] ?? existing['id'] ?? existing['claim_id'])
              .toString();
      if (claimId.isEmpty || existingId != claimId) return existing;
      return {...existing, ...?claim, 'status': 'collected'};
    }).toList();

    final updatedItems = _latestData.items.map((item) {
      final existingItemId = (item['itemId'] ?? item['id']).toString();
      if (existingItemId != itemId) return item;
      return {...item, 'status': 'collected'};
    }).toList();

    _setLatestData(
        _LostFoundAdminData(items: updatedItems, claims: updatedClaims));
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

  String _statusForAction(String actionOrStatus) {
    switch (actionOrStatus.toLowerCase()) {
      case 'approve':
        return 'approved';
      case 'reject':
        return 'rejected';
      case 'cancel':
        return 'cancelled';
      default:
        return actionOrStatus.toLowerCase();
    }
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
            Text('Lost And Found Operations',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text('Detected items and claim approvals',
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
      body: FutureBuilder<_LostFoundAdminData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: AppTheme.accent));
          }
          if (snapshot.hasError) {
            return const _EmptyState(
              title: 'Lost & Found is unavailable',
              subtitle: 'Start the FastAPI backend and refresh this screen.',
            );
          }

          final data =
              _hasLoadedData ? _latestData : (snapshot.data ?? _latestData);
          final pendingClaims = data.claims
              .where((claim) => {'pending', 'pending_verification'}
                  .contains((claim['status'] ?? '').toString().toLowerCase()))
              .toList();

          return RefreshIndicator(
            onRefresh: _reload,
            color: AppTheme.accent,
            backgroundColor: AppTheme.surfaceHigh,
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                _SummaryPanel(
                  items: data.items.length,
                  available: data.items
                      .where((item) =>
                          (item['status'] ?? '').toString().toLowerCase() ==
                          'available')
                      .length,
                  pendingClaims: pendingClaims.length,
                  collected: data.items
                      .where((item) =>
                          (item['status'] ?? '').toString().toLowerCase() ==
                          'collected')
                      .length,
                ),
                const SizedBox(height: 18),
                Text('Pending Claim Requests',
                    style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                if (pendingClaims.isEmpty)
                  const _EmptyState(
                    title: 'No pending claims',
                    subtitle: 'Student requests will appear here.',
                  )
                else
                  ...pendingClaims.map((claim) => _ClaimCard(
                        claim: claim,
                        busyAction: _busyActionForClaim(claim),
                        onApprove: () => _claimAction(claim, 'approve'),
                        onReject: () => _claimAction(claim, 'reject'),
                        onCancel: () => _claimAction(claim, 'cancel'),
                      )),
                const SizedBox(height: 18),
                Text('Detected Items',
                    style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                if (data.items.isEmpty)
                  const _EmptyState(
                    title: 'No detected items yet',
                    subtitle: 'End a driver trip to launch the demo AI.',
                  )
                else
                  ...data.items.map((item) => _ItemCard(
                        item: item,
                        isCollecting: _busyActions.contains(
                          '${(item['itemId'] ?? item['id']).toString()}:collected',
                        ),
                        onCollected: () => _markCollected(
                          (item['itemId'] ?? item['id']).toString(),
                          item['claimRequestId']?.toString(),
                        ),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  String? _busyActionForClaim(Map<String, dynamic> claim) {
    final claimId =
        (claim['claimId'] ?? claim['id'] ?? claim['claim_id']).toString();
    for (final action in const ['approve', 'reject', 'cancel']) {
      if (_busyActions.contains('$claimId:$action')) return action;
    }
    return null;
  }
}

class _LostFoundAdminData {
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> claims;

  const _LostFoundAdminData({required this.items, required this.claims});

  factory _LostFoundAdminData.empty() =>
      const _LostFoundAdminData(items: [], claims: []);
}

class _SummaryPanel extends StatelessWidget {
  final int items;
  final int available;
  final int pendingClaims;
  final int collected;

  const _SummaryPanel({
    required this.items,
    required this.available,
    required this.pendingClaims,
    required this.collected,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      fillColor: AppTheme.accent.withValues(alpha: 0.07),
      borderColor: AppTheme.accent.withValues(alpha: 0.22),
      padding: const EdgeInsets.all(18),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _SummaryChip(
              label: 'Detected', value: '$items', color: AppTheme.info),
          _SummaryChip(
              label: 'Available',
              value: '$available',
              color: AppTheme.positive),
          _SummaryChip(
              label: 'Pending Claims',
              value: '$pendingClaims',
              color: AppTheme.warning),
          _SummaryChip(
              label: 'Collected',
              value: '$collected',
              color: AppTheme.textMuted),
        ],
      ),
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
        color: color.withValues(alpha: 0.10),
        borderRadius: AppTheme.chipRadius,
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(value,
              style: GoogleFonts.inter(
                  color: color, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  final Map<String, dynamic> claim;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancel;
  final String? busyAction;

  const _ClaimCard({
    required this.claim,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
    required this.busyAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: busyAction == null ? onApprove : null,
                  icon: _ActionIcon(
                    loading: busyAction == 'approve',
                    icon: Icons.verified_rounded,
                  ),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.positive,
                      foregroundColor: AppTheme.onPositive),
                  label: const Text('Approve'),
                ),
                OutlinedButton.icon(
                  onPressed: busyAction == null ? onReject : null,
                  icon: _ActionIcon(
                    loading: busyAction == 'reject',
                    icon: Icons.close_rounded,
                  ),
                  label: const Text('Reject'),
                ),
                OutlinedButton.icon(
                  onPressed: busyAction == null ? onCancel : null,
                  icon: _ActionIcon(
                    loading: busyAction == 'cancel',
                    icon: Icons.cancel_outlined,
                  ),
                  label: const Text('Cancel'),
                ),
              ],
            );
            final details = _DetailsBlock(
              title:
                  (claim['itemName'] ?? claim['itemId'] ?? 'Item').toString(),
              status: (claim['status'] ?? 'pending').toString(),
              lines: [
                'Student: ${claim['studentName'] ?? claim['studentId'] ?? '--'}',
                'Email: ${claim['studentEmail'] ?? claim['studentId'] ?? '--'}',
                'Message: ${claim['message'] ?? claim['reason'] ?? '--'}',
              ],
            );
            if (constraints.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [details, const SizedBox(height: 12), actions],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                const SizedBox(width: 14),
                Flexible(
                    child:
                        Align(alignment: Alignment.topRight, child: actions)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onCollected;
  final bool isCollecting;

  const _ItemCard({
    required this.item,
    required this.onCollected,
    required this.isCollecting,
  });

  @override
  Widget build(BuildContext context) {
    final status = (item['status'] ?? 'available').toString();
    final itemId = (item['itemId'] ?? item['id'] ?? '').toString();
    final canCollect =
        {'approved', 'claim_requested'}.contains(status.toLowerCase());
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final details = _DetailsBlock(
              title: (item['itemName'] ?? item['name'] ?? 'Item').toString(),
              status: status,
              lines: [
                'Item ID: $itemId',
                'Bus: ${item['busId'] ?? '--'}',
                'Trip: ${item['tripId'] ?? '--'}',
                'Detected: ${item['detectedAt'] ?? item['foundedAt'] ?? '--'}',
              ],
            );
            final action = ElevatedButton.icon(
              onPressed: canCollect && !isCollecting ? onCollected : null,
              icon: _ActionIcon(
                loading: isCollecting,
                icon: Icons.assignment_turned_in_rounded,
              ),
              label: const Text('Mark Collected'),
            );
            if (constraints.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [details, const SizedBox(height: 12), action],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                const SizedBox(width: 14),
                Flexible(
                    child: Align(alignment: Alignment.topRight, child: action)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DetailsBlock extends StatelessWidget {
  final String title;
  final String status;
  final List<String> lines;

  const _DetailsBlock({
    required this.title,
    required this.status,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
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
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 8),
              ...lines.map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final bool loading;
  final IconData icon;

  const _ActionIcon({required this.loading, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (!loading) {
      return Icon(icon, size: 16);
    }
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppTheme.chipRadius,
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(
            color: color, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
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
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, color: AppTheme.textMuted, size: 34),
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
