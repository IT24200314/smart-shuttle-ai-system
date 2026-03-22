// ============================================================
// Smart Shuttle — Revenue Dashboard (Overflow-fixed)
// Chart row header wrapped, live tag Flexible, table safe
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/kpi_card.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/api_config.dart';

class RevenueDashboardScreen extends StatefulWidget {
  const RevenueDashboardScreen({super.key});

  @override
  State<RevenueDashboardScreen> createState() => _RevenueDashboardScreenState();
}

class _RevenueDashboardScreenState extends State<RevenueDashboardScreen> {
  late Future<Map<String, dynamic>> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = fetchDashboardSummary();
  }

  Future<Map<String, dynamic>> fetchDashboardSummary() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/dashboard/revenue-summary'),
      ).timeout(const Duration(seconds: 5));
      
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(res.body));
      }
      throw Exception('Server error: ${res.statusCode}');
    } catch (e) {
      throw Exception('Failed to connect: $e');
    }
  }

  static const List<FlSpot> _aiForecast = [
    FlSpot(0, 42), FlSpot(1, 44), FlSpot(2, 43), FlSpot(3, 48),
    FlSpot(4, 52), FlSpot(5, 55), FlSpot(6, 60), FlSpot(7, 63),
    FlSpot(8, 65), FlSpot(9, 68), FlSpot(10, 72), FlSpot(11, 75),
    FlSpot(12, 79), FlSpot(13, 85), FlSpot(14, 88), FlSpot(15, 92),
  ];
  static const List<FlSpot> _upperBound = [
    FlSpot(0, 48), FlSpot(4, 58), FlSpot(10, 80), FlSpot(15, 102),
  ];
  static const List<FlSpot> _lowerBound = [
    FlSpot(0, 38), FlSpot(4, 46), FlSpot(10, 64), FlSpot(15, 82),
  ];

  static const List<_TripRow> _trips = [
    _TripRow('T-001', 'Kandy', 52, 2600),
    _TripRow('T-002', 'Lewella', 43, 2150),
    _TripRow('T-003', 'SLIIT Kandy', 65, 3250),
    _TripRow('T-004', 'Peradeniya', 34, 1700),
    _TripRow('T-005', 'Katugastota', 75, 3750),
    _TripRow('T-006', 'Kandy', 48, 2400),
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: Text(
                'Sync Error: ${snapshot.error}',
                style: GoogleFonts.inter(color: AppTheme.danger),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final summary = data['summary'] ?? {};
        final trips = (data['recent_trips'] as List?)?.map((t) => _TripRow(
          t['trip_id'] ?? '?',
          t['route_id'] ?? 'Main',
          t['passenger_count'] ?? 0,
          t['revenue']?.toInt() ?? 0
        )).toList() ?? [];

        return _buildUI(context, summary, trips);
      }
    );
  }

  Widget _buildUI(BuildContext context, Map<String, dynamic> summary, List<_TripRow> trips) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue Intelligence',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text('Financial Analytics',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.auto_awesome_rounded,
                  color: AppTheme.positive, size: 19),
              tooltip: 'AI Report',
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.positive.withOpacity(0.10),
                shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.chipRadius),
              ),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── AI Status Bar ─────────────────────────────────
            GlassCard(
              fillColor: AppTheme.positive.withOpacity(0.06),
              borderColor: AppTheme.positive.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  const Icon(Icons.auto_graph_rounded,
                      color: AppTheme.positive, size: 15),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI Forecasting Active — route & passenger flow model',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.positive.withOpacity(0.15),
                      borderRadius: AppTheme.chipRadius,
                    ),
                    child: Text('95% CI',
                        style: GoogleFonts.inter(
                            color: AppTheme.positive,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Live Bus Stream ───────────────────────────────
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('LIVE-STATUS')
                  .doc('bus_001')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    !snapshot.data!.exists) {
                  return const SizedBox.shrink();
                }
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final pax = data['passenger_count'] ?? 0;
                final rev = data['estimated_revenue'] ?? 0;
                return GlassCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.podcasts_rounded,
                          color: AppTheme.positive, size: 13),
                      const SizedBox(width: 8),
                      Text('BUS 001 · LIVE',
                          style: GoogleFonts.inter(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 10),
                      _LiveTag('$pax pax', AppTheme.accent),
                      const SizedBox(width: 6),
                      Flexible(
                        child: _LiveTag('LKR $rev', AppTheme.positive),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // ── Section: KPIs ─────────────────────────────────
            _SectionHeader("Today's Performance"),
            const SizedBox(height: 12),

            // Rule 1 & 2: Big numbers first → Daily Earnings is hero metric
            _HeroMetricCard(
              label: 'Daily Earnings',
              value: 'LKR ${summary['total_revenue']?.toInt() ?? 0}',
              change: '${summary['revenue_growth'] ?? '+0'}% vs yesterday',
              isPositive: (summary['revenue_growth'] ?? 0) >= 0,
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 136,
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.55,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  KpiCard(
                    icon: Icons.trending_up_rounded,
                    label: '30-Day Forecast',
                    value: '${summary['forecast_30d'] ?? '0'}K',
                    subtitle: 'AI Projection',
                    isPositive: true,
                    accentColor: AppTheme.positive,
                  ),
                  KpiCard(
                    icon: Icons.groups_rounded,
                    label: 'Leakage',
                    value: '${summary['leakage_percent']?.toStringAsFixed(1) ?? '0'}%',
                    subtitle: 'LKR ${summary['leakage_amount']?.toInt() ?? 0}',
                    isPositive: false,
                    accentColor: AppTheme.danger,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Section: Chart ────────────────────────────────
            _SectionHeader('AI Income Forecast'),
            const SizedBox(height: 12),

            GlassCard(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Chart title row — wrapped to prevent overflow
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Predicted Revenue · 30 Days',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _LegendChip('Forecast (LKR k)', AppTheme.positive),
                          const SizedBox(width: 10),
                          _LegendChip('Confidence band', AppTheme.positive,
                              dashed: true),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 20,
                          getDrawingHorizontalLine: (_) => const FlLine(
                            color: AppTheme.border,
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 44,
                              interval: 20,
                              getTitlesWidget: (v, _) => Text(
                                '${v.toInt()}k',
                                style: GoogleFonts.inter(
                                    color: AppTheme.textMuted, fontSize: 9),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 3,
                              reservedSize: 20,
                              getTitlesWidget: (v, _) => Text(
                                'D${v.toInt()}',
                                style: GoogleFonts.inter(
                                    color: AppTheme.textMuted, fontSize: 9),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0, maxX: 15,
                        minY: 30, maxY: 110,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _upperBound,
                            isCurved: true,
                            color: Colors.transparent,
                            barWidth: 0,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: false),
                          ),
                          LineChartBarData(
                            spots: _lowerBound,
                            isCurved: true,
                            color: Colors.transparent,
                            barWidth: 0,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppTheme.positive.withOpacity(0.06),
                            ),
                          ),
                          LineChartBarData(
                            spots: _aiForecast,
                            isCurved: true,
                            curveSmoothness: 0.35,
                            color: AppTheme.positive,
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppTheme.positive.withOpacity(0.18),
                                  AppTheme.positive.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Section: Trip Table ───────────────────────────
            _SectionHeader('Revenue by Trip'),
            const SizedBox(height: 12),

            GlassCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: AppTheme.cardRadius,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Trip Breakdown',
                              style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            'Passenger counts via YOLO Vision AI',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                color: AppTheme.textSecondary,
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Table header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      color: AppTheme.surfaceHigh,
                      child: const Row(
                        children: [
                          Expanded(flex: 1, child: _TableHeader('Trip')),
                          Expanded(flex: 2, child: _TableHeader('Route')),
                          Expanded(flex: 1, child: _TableHeader('Pax')),
                          Expanded(
                              flex: 2,
                              child: _TableHeader('Revenue', right: true)),
                        ],
                      ),
                    ),
                    // Rows
                    ...trips.asMap().entries.map((e) => _TripTableRow(
                          trip: e.value,
                          isEven: e.key.isEven,
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Hero metric — Rule 2: big number = main data ─────────────
class _HeroMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String change;
  final bool isPositive;

  const _HeroMetricCard({
    required this.label,
    required this.value,
    required this.change,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final changeColor = isPositive ? AppTheme.positive : AppTheme.danger;
    return GlassCard(
      fillColor: AppTheme.positive.withOpacity(0.05),
      borderColor: AppTheme.positive.withOpacity(0.2),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label.toUpperCase(),
                    style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8)),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      )),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isPositive
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: changeColor,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(change,
                        style: GoogleFonts.inter(
                            color: changeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.positive.withOpacity(0.12),
              borderRadius: AppTheme.chipRadius,
            ),
            child: const Icon(Icons.monetization_on_rounded,
                color: AppTheme.positive, size: 28),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title.toUpperCase(),
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            )),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: AppTheme.border)),
      ],
    );
  }
}

class _LiveTag extends StatelessWidget {
  final String label;
  final Color color;
  const _LiveTag(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: AppTheme.chipRadius,
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool dashed;
  const _LegendChip(this.label, this.color, {this.dashed = false});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 14, height: 2,
              color: dashed ? color.withOpacity(0.3) : color),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.inter(
                  color: AppTheme.textMuted, fontSize: 10)),
        ],
      );
}

class _TableHeader extends StatelessWidget {
  final String label;
  final bool right;
  const _TableHeader(this.label, {this.right = false});
  @override
  Widget build(BuildContext context) => Text(
        label,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: GoogleFonts.inter(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _TripTableRow extends StatelessWidget {
  final _TripRow trip;
  final bool isEven;
  const _TripTableRow({required this.trip, required this.isEven});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isEven
          ? AppTheme.surfaceHigh.withOpacity(0.5)
          : Colors.transparent,
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(trip.tripId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 2,
            child: Text(trip.route,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary, fontSize: 12)),
          ),
          Expanded(
            flex: 1,
            child: Text('${trip.pax}',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ),
          Expanded(
            flex: 2,
            child: Text('${trip.total}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  color: AppTheme.positive,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );
  }
}

class _TripRow {
  final String tripId;
  final String route;
  final int pax;
  final int total;
  const _TripRow(this.tripId, this.route, this.pax, this.total);
}
