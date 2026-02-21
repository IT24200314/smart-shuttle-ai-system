// ============================================================
// Smart Shuttle — Revenue Management Dashboard
// Member: IT24200314 (Individual Contribution)
//
// Full management-focused screen with:
//  - 4 KPI cards (Daily Revenue, Forecasted Profit,
//    Peak Passengers, Trip Efficiency)
//  - AI-Powered Revenue Forecast Line Chart (30-day)
//  - Passenger Count per Hour Bar Chart
//  - Detailed trip data table
//
// Design: Glassmorphism, 8px radius, Inter font, Deep Blue + Emerald
// AI Emphasis: "AI-Powered Prediction" language throughout
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/kpi_card.dart';

class RevenueDashboardScreen extends StatelessWidget {
  const RevenueDashboardScreen({super.key});

  // ── Extended 30-day forecast data ────────────────────────
  static const List<FlSpot> _forecast = [
    FlSpot(0,  38), FlSpot(1,  41), FlSpot(2,  40), FlSpot(3,  44),
    FlSpot(4,  47), FlSpot(5,  46), FlSpot(6,  51), FlSpot(7,  53),
    FlSpot(8,  52), FlSpot(9,  56), FlSpot(10, 59), FlSpot(11, 57),
    FlSpot(12, 62), FlSpot(13, 64), FlSpot(14, 66), FlSpot(15, 65),
    FlSpot(16, 69), FlSpot(17, 71), FlSpot(18, 70), FlSpot(19, 74),
    FlSpot(20, 77), FlSpot(21, 76), FlSpot(22, 79), FlSpot(23, 81),
    FlSpot(24, 83), FlSpot(25, 82), FlSpot(26, 85), FlSpot(27, 88),
    FlSpot(28, 87), FlSpot(29, 91),
  ];

  static const List<FlSpot> _actual = [
    FlSpot(0,  37), FlSpot(1,  39), FlSpot(2,  42), FlSpot(3,  41),
    FlSpot(4,  45), FlSpot(5,  48), FlSpot(6,  50), FlSpot(7,  51),
    FlSpot(8,  54), FlSpot(9,  55), FlSpot(10, 58), FlSpot(11, 60),
    FlSpot(12, 61), FlSpot(13, 63),
  ];

  static const List<double> _hourly = [
    6, 12, 28, 55, 88, 95, 77, 42, 31, 47, 90, 92,
    70, 33, 20, 52, 88, 86, 62, 37, 19, 11, 5, 2,
  ];

  static const List<_TripEntry> _trips = [
    _TripEntry('TRP-001', 'NB-2341', 45, 1350),
    _TripEntry('TRP-002', 'NB-1892', 38, 1140),
    _TripEntry('TRP-003', 'NB-3010', 52, 1560),
    _TripEntry('TRP-004', 'NB-2341', 29,  870),
    _TripEntry('TRP-005', 'NB-4455', 61, 1830),
    _TripEntry('TRP-006', 'NB-1892', 44, 1320),
    _TripEntry('TRP-007', 'NB-3010', 37, 1110),
    _TripEntry('TRP-008', 'NB-2341', 55, 1650),
    _TripEntry('TRP-009', 'NB-4455', 48, 1440),
    _TripEntry('TRP-010', 'NB-1892', 62, 1860),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue Management',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text('AI-Powered Dashboard · IT24200314',
                style: GoogleFonts.inter(
                    color: AppTheme.emerald, fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded,
                color: AppTheme.textSecondary),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.emerald),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── AI Model Status Banner ────────────────────────
            _ModelStatusBanner(),
            const SizedBox(height: 16),

            // ── KPI Cards ────────────────────────────────────
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: const [
                KpiCard(
                  icon: Icons.attach_money_rounded,
                  label: 'Total Daily Revenue (Est.)',
                  value: 'LKR 12,840',
                  subtitle: '+8.3% vs yesterday',
                  isPositive: true,
                ),
                KpiCard(
                  icon: Icons.trending_up_rounded,
                  label: '30-Day Forecasted Profit',
                  value: 'LKR 3.2M',
                  subtitle: 'AI confidence: 91%',
                  isPositive: true,
                ),
                KpiCard(
                  icon: Icons.groups_rounded,
                  label: 'Peak Hour Passengers',
                  value: '95 / trip',
                  subtitle: '08:00–09:00 AM peak',
                  isPositive: true,
                ),
                KpiCard(
                  icon: Icons.bolt_rounded,
                  label: 'Trip Efficiency %',
                  value: '87.4%',
                  subtitle: '+2.1% this week',
                  isPositive: true,
                  accentColor: Color(0xFF7C4DFF),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Revenue Forecast Line Chart ───────────────────
            GlassCard(
              padding: const EdgeInsets.all(18),
              borderColor: AppTheme.emerald.withOpacity(0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with AI badge
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome_rounded,
                                    color: AppTheme.emerald, size: 16),
                                const SizedBox(width: 6),
                                Text('AI-Powered Revenue Forecasting',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    )),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '30-day prediction vs actual revenue · Shaded area = confidence interval',
                              style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const _Badge('91% Confidence', AppTheme.emerald),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(
                    height: 200,
                    child: _ForecastLineChart(
                        forecast: _forecast, actual: _actual),
                  ),
                  const SizedBox(height: 12),
                  // Legend
                  Row(
                    children: [
                      const _LegendLine(label: 'AI Forecast', color: AppTheme.emerald, dashed: false),
                      const SizedBox(width: 16),
                      const _LegendLine(label: 'Actual Revenue', color: Color(0xFF7C4DFF), dashed: false),
                      const SizedBox(width: 16),
                      _LegendLine(label: 'Confidence Band', color: AppTheme.emerald.withOpacity(0.3), dashed: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Bar Chart ─────────────────────────────────────
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Passenger Count per Hour',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                )),
                            Text(
                              'Peak demand windows identified for bus scheduling',
                              style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      const _Badge('Today', Color(0xFF7C4DFF)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(
                    height: 180,
                    child: _HourlyBarChart(data: _hourly),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(width: 12, height: 12,
                          decoration: BoxDecoration(
                            color: AppTheme.emerald,
                            borderRadius: BorderRadius.circular(3),
                          )),
                      const SizedBox(width: 5),
                      Text('Peak demand (≥ 80 pax)',
                          style: GoogleFonts.inter(
                              color: AppTheme.textSecondary, fontSize: 10)),
                      const SizedBox(width: 16),
                      Container(width: 12, height: 12,
                          decoration: BoxDecoration(
                            color: AppTheme.emerald.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(3),
                          )),
                      const SizedBox(width: 5),
                      Text('Normal demand',
                          style: GoogleFonts.inter(
                              color: AppTheme.textSecondary, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Trip Data Table ───────────────────────────────
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.table_chart_rounded,
                          color: AppTheme.emerald, size: 18),
                      const SizedBox(width: 8),
                      Text('Trip Revenue Breakdown',
                          style: GoogleFonts.inter(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      const _Badge('Firestore', Color(0xFFF57C00)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Estimated ticket revenue = Passenger Count × LKR 30',
                      style: GoogleFonts.inter(
                          color: AppTheme.textSecondary, fontSize: 10)),
                  const SizedBox(height: 16),
                  const _TripDataTable(entries: _trips),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── AI Model Status Banner ───────────────────────────────────
class _ModelStatusBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderColor: AppTheme.emerald.withOpacity(0.5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withOpacity(0.15),
              borderRadius: AppTheme.borderRadius,
            ),
            child: const Icon(Icons.memory_rounded,
                color: AppTheme.emerald, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Revenue Prediction Model: Active',
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    )),
                Text(
                  'LSTM-based model · Trained on 180-day ticket dataset · Last updated 21 Feb 2026',
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.emerald,
                ),
              ),
              const SizedBox(width: 5),
              Text('LIVE',
                  style: GoogleFonts.inter(
                      color: AppTheme.emerald,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Revenue Forecast Line Chart ───────────────────────────────
class _ForecastLineChart extends StatelessWidget {
  final List<FlSpot> forecast;
  final List<FlSpot> actual;
  const _ForecastLineChart({required this.forecast, required this.actual});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Colors.white10, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}k',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              getTitlesWidget: (v, _) => Text(
                'D${v.toInt() + 1}',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 9),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0, maxX: 29,
        minY: 28, maxY: 105,
        lineBarsData: [
          // AI Forecast
          LineChartBarData(
            spots: forecast,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppTheme.emerald,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            dashArray: null,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.emerald.withOpacity(0.20),
                  AppTheme.emerald.withOpacity(0.0),
                ],
              ),
            ),
          ),
          // Actual Revenue (partial — days elapsed)
          LineChartBarData(
            spots: actual,
            isCurved: true,
            curveSmoothness: 0.35,
            color: const Color(0xFF7C4DFF),
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3,
                color: const Color(0xFF7C4DFF),
                strokeWidth: 0,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.midBlue,
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
              'LKR ${(s.y * 1000).toStringAsFixed(0)}',
              GoogleFonts.inter(
                  color: AppTheme.emerald,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            )).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Hourly Bar Chart ──────────────────────────────────────────
class _HourlyBarChart extends StatelessWidget {
  final List<double> data;
  const _HourlyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 110,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppTheme.midBlue,
            getTooltipItem: (g, _, rod, __) => BarTooltipItem(
              '${rod.toY.toInt()} pax',
              GoogleFonts.inter(
                  color: AppTheme.emerald,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text(
                v.toInt() % 4 == 0 ? '${v.toInt()}h' : '',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 8),
              ),
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Colors.white10, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((e) {
          final isPeak = e.value >= 80;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value,
                color: isPeak
                    ? AppTheme.emerald
                    : AppTheme.emerald.withOpacity(0.35),
                width: 7,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: 110,
                  color: Colors.white.withOpacity(0.03),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Trip Data Table ───────────────────────────────────────────
class _TripDataTable extends StatelessWidget {
  final List<_TripEntry> entries;
  const _TripDataTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(1.1),
        2: FlexColumnWidth(0.9),
        3: FlexColumnWidth(1.2),
      },
      children: [
        // Header row
        TableRow(
          decoration: BoxDecoration(
            color: AppTheme.emerald.withOpacity(0.08),
            borderRadius: AppTheme.borderRadius,
          ),
          children: ['Trip ID', 'Bus No.', 'Pax', 'Est. Revenue']
              .map((h) => _HeaderCell(h))
              .toList(),
        ),
        ...entries.asMap().entries.map((e) => TableRow(
          decoration: BoxDecoration(
            color: e.key.isEven
                ? Colors.white.withOpacity(0.03)
                : Colors.transparent,
          ),
          children: [
            _DataCell(e.value.tripId, bold: true),
            _DataCell(e.value.busNo),
            _DataCell(e.value.passengers.toString()),
            _DataCell(
              'LKR ${e.value.revenue.toString().replaceAllMapped(
                RegExp(r'\B(?=(\d{3})+(?!\d))'),
                (m) => ',',
              )}',
              isRevenue: true,
            ),
          ],
        )),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    child: Text(text,
        style: GoogleFonts.inter(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        )),
  );
}

class _DataCell extends StatelessWidget {
  final String text;
  final bool bold;
  final bool isRevenue;
  const _DataCell(this.text, {this.bold = false, this.isRevenue = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    child: Text(text,
        style: GoogleFonts.inter(
          color: isRevenue ? AppTheme.emerald : AppTheme.textPrimary,
          fontSize: 12,
          fontWeight: isRevenue || bold ? FontWeight.w600 : FontWeight.w400,
        )),
  );
}

// ── Badge ──────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: AppTheme.borderRadius,
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(label,
        style: GoogleFonts.inter(
            color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

// ── Legend Item ────────────────────────────────────────────────
class _LegendLine extends StatelessWidget {
  final String label;
  final Color color;
  final bool dashed;
  const _LegendLine({required this.label, required this.color, required this.dashed});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 14, height: 2.5,
        color: dashed ? color.withOpacity(0.6) : color,
      ),
      const SizedBox(width: 5),
      Text(label,
          style: GoogleFonts.inter(
              color: AppTheme.textSecondary, fontSize: 10)),
    ],
  );
}

// ── Data model ─────────────────────────────────────────────────
class _TripEntry {
  final String tripId;
  final String busNo;
  final int passengers;
  final int revenue;
  const _TripEntry(this.tripId, this.busNo, this.passengers, this.revenue);
}
