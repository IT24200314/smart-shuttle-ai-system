// ============================================================
// Smart Shuttle — Financial Intelligence Dashboard
//
// Primary Focus: AI-powered financial forecasting.
// Theme: Deep Blue with 'Emerald Green' accents for growth.
// Layout: Glassmorphism cards, premium financial tool aesthetics.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/kpi_card.dart';

class RevenueDashboardScreen extends StatelessWidget {
  const RevenueDashboardScreen({super.key});

  // Example data representing AI Income forecast vs Actual
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

  static const List<_TripBreakdown> _breakdowns = [
    _TripBreakdown('T-001', 'Kaduwela', 52, 2600),
    _TripBreakdown('T-002', 'Malabe', 43, 2150),
    _TripBreakdown('T-003', 'Athurugiriya', 65, 3250),
    _TripBreakdown('T-004', 'Kottawa', 34, 1700),
    _TripBreakdown('T-005', 'Malabe', 75, 3750),
    _TripBreakdown('T-006', 'Kaduwela', 48, 2400),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Financial Intelligence',
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: AppTheme.emerald),
            tooltip: 'Run AI Report',
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // AI Status
            Row(
              children: [
                const Icon(Icons.bar_chart_rounded, color: AppTheme.emerald, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Financial Forecasting Active',
                          style: GoogleFonts.inter(color: AppTheme.emerald, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('Predictive models trained on passenger flow & route behavior.',
                          style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Financial KPIs
            LayoutBuilder(
              builder: (context, constraints) {
                // Determine grid parameters based on screen width
                int crossAxisCount;
                double childAspectRatio;

                if (constraints.maxWidth < 600) {
                  // Mobile view: 1 column
                  crossAxisCount = 1;
                  childAspectRatio = 2.5; 
                } else if (constraints.maxWidth < 900) {
                  // Tablet view: 2 columns
                  crossAxisCount = 2;
                  childAspectRatio = 1.6;
                } else {
                  // Desktop view: 3 columns
                  crossAxisCount = 3;
                  childAspectRatio = 1.4;
                }

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: childAspectRatio,
                  children: const [
                    KpiCard(
                      icon: Icons.monetization_on_rounded,
                      label: 'Daily Earnings (LKR)',
                      value: '18,450',
                      subtitle: '+12% vs last week',
                      isPositive: true,
                      accentColor: AppTheme.emerald,
                    ),
                    KpiCard(
                      icon: Icons.trending_up_rounded,
                      label: '30-Day Predicted Profit',
                      value: '420,000',
                      subtitle: 'High Confidence',
                      isPositive: true,
                      accentColor: AppTheme.emerald,
                    ),
                    KpiCard(
                      icon: Icons.groups_rounded,
                      label: 'Peak Demand Avg',
                      value: '82 p/hr',
                      subtitle: 'Correlates to +15% revenue',
                      isPositive: true,
                      accentColor: Colors.blueAccent,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Large Line Chart
            GlassCard(
              padding: const EdgeInsets.all(24),
              borderColor: AppTheme.emerald.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('AI Predicted Income',
                          style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.emerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text('95% Confidence Interval',
                            style: GoogleFonts.inter(color: AppTheme.emerald, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 280,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 20,
                          getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 1),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 45,
                              interval: 20,
                              getTitlesWidget: (v, _) => Text('LKR ${v.toInt()}k', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 10)),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 3,
                              getTitlesWidget: (v, _) => Text('Day ${v.toInt()}', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 10)),
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0, maxX: 15,
                        minY: 30, maxY: 110,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _upperBound,
                            isCurved: true,
                            color: AppTheme.emerald.withValues(alpha: 0.0),
                            barWidth: 0,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: false),
                          ),
                          LineChartBarData(
                            spots: _lowerBound,
                            isCurved: true,
                            color: AppTheme.emerald.withValues(alpha: 0.0),
                            barWidth: 0,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppTheme.emerald.withValues(alpha: 0.1),
                              applyCutOffY: false,
                            ),
                          ),
                          LineChartBarData(
                            spots: _aiForecast,
                            isCurved: true,
                            curveSmoothness: 0.35,
                            color: AppTheme.emerald,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppTheme.emerald.withValues(alpha: 0.25),
                                  AppTheme.emerald.withValues(alpha: 0.0),
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
            const SizedBox(height: 24),

            // Data Table
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Revenue per Trip Breakdown',
                      style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Passenger counts verified by YOLO Computer Vision Model',
                      style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11)),
                  const SizedBox(height: 16),
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1),
                      1: FlexColumnWidth(1.2),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.1),
                          borderRadius: AppTheme.borderRadius,
                        ),
                        children: ['Trip ID', 'Route', 'Passenger Count', 'Ticket Totals (LKR)']
                            .map((h) => Padding(padding: const EdgeInsets.all(12), child: Text(h, style: GoogleFonts.inter(color: AppTheme.emerald, fontSize: 11, fontWeight: FontWeight.bold))))
                            .toList(),
                      ),
                      ..._breakdowns.asMap().entries.map((e) => TableRow(
                        decoration: BoxDecoration(color: e.key.isEven ? Colors.white.withValues(alpha: 0.03) : Colors.transparent),
                        children: [
                          _DataCell(e.value.tripId, isBold: true),
                          _DataCell(e.value.route),
                          _DataCell('${e.value.pax} pax'),
                          _DataCell(e.value.total.toString(), isHighlight: true),
                        ],
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripBreakdown {
  final String tripId;
  final String route;
  final int pax;
  final int total;
  const _TripBreakdown(this.tripId, this.route, this.pax, this.total);
}

class _DataCell extends StatelessWidget {
  final String text;
  final bool isBold;
  final bool isHighlight;
  const _DataCell(this.text, {this.isBold = false, this.isHighlight = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(text,
      style: GoogleFonts.inter(
        color: isHighlight ? AppTheme.emerald : AppTheme.textPrimary,
        fontSize: 12,
        fontWeight: isBold || isHighlight ? FontWeight.bold : FontWeight.w500,
      )),
  );
}
