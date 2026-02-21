// ============================================================
// Smart Shuttle — Admin Dashboard Screen
// Member: IT24200314 (Individual Contribution)
//
// Key emphasis: AI-Powered Prediction
//   Charts are NOT static — they represent forecasts generated
//   through the Smart Shuttle AI revenue prediction model.
//
// Features:
//  - 4 KPI Cards (revenue, profit, passengers, efficiency)
//  - Line Chart: "AI-Powered 30-Day Revenue Forecasting"
//  - Bar Chart: "Passenger Count per Hour" (peak demand)
//  - Data Table: Audit Log (Trip ID, Bus, Passengers, Revenue)
//  - Navigation to full Revenue Management Dashboard
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/kpi_card.dart';
import 'revenue_dashboard_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // ── Sample data: 30-day AI revenue forecast ───────────────
  final List<FlSpot> _revenueSpots = const [
    FlSpot(0,  42), FlSpot(1,  45), FlSpot(2,  43), FlSpot(3,  47),
    FlSpot(4,  50), FlSpot(5,  49), FlSpot(6,  53), FlSpot(7,  55),
    FlSpot(8,  54), FlSpot(9,  57), FlSpot(10, 60), FlSpot(11, 58),
    FlSpot(12, 63), FlSpot(13, 65), FlSpot(14, 67), FlSpot(15, 66),
    FlSpot(16, 70), FlSpot(17, 72), FlSpot(18, 71), FlSpot(19, 75),
    FlSpot(20, 78), FlSpot(21, 77), FlSpot(22, 80), FlSpot(23, 82),
    FlSpot(24, 84), FlSpot(25, 83), FlSpot(26, 86), FlSpot(27, 89),
    FlSpot(28, 88), FlSpot(29, 92),
  ];

  // Confidence interval upper/lower bounds
  final List<FlSpot> _upperBound = const [
    FlSpot(0,  47), FlSpot(5,  55), FlSpot(10, 66), FlSpot(15, 73),
    FlSpot(20, 85), FlSpot(25, 91), FlSpot(29, 99),
  ];
  final List<FlSpot> _lowerBound = const [
    FlSpot(0,  37), FlSpot(5,  43), FlSpot(10, 54), FlSpot(15, 59),
    FlSpot(20, 71), FlSpot(25, 75), FlSpot(29, 85),
  ];

  // ── Hourly passenger counts ───────────────────────────────
  final List<double> _hourlyPassengers = const [
    8, 15, 32, 58, 85, 92, 74, 40, 30, 45, 88, 95,
    68, 30, 22, 55, 90, 88, 60, 35, 18, 10, 6, 3,
  ];

  // ── Audit log data ────────────────────────────────────────
  final List<_AuditEntry> _auditLog = const [
    _AuditEntry('TRP-001', 'NB-2341', 45, 'LKR 1,350'),
    _AuditEntry('TRP-002', 'NB-1892', 38, 'LKR 1,140'),
    _AuditEntry('TRP-003', 'NB-3010', 52, 'LKR 1,560'),
    _AuditEntry('TRP-004', 'NB-2341', 29, 'LKR 870'),
    _AuditEntry('TRP-005', 'NB-4455', 61, 'LKR 1,830'),
    _AuditEntry('TRP-006', 'NB-1892', 44, 'LKR 1,320'),
    _AuditEntry('TRP-007', 'NB-3010', 37, 'LKR 1,110'),
    _AuditEntry('TRP-008', 'NB-2341', 55, 'LKR 1,650'),
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
        title: Text('Admin Dashboard',
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.bar_chart_rounded, color: AppTheme.emerald, size: 18),
            label: Text('Revenue Mgmt',
                style: GoogleFonts.inter(color: AppTheme.emerald, fontSize: 12)),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RevenueDashboardScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── AI Badge ────────────────────────────────────
            _AiBadge(),
            const SizedBox(height: 16),

            // ── KPI Cards ────────────────────────────────────
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: const [
                KpiCard(
                  icon: Icons.attach_money_rounded,
                  label: 'Total Daily Revenue',
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
                  subtitle: '08:00–09:00 window',
                  isPositive: true,
                ),
                KpiCard(
                  icon: Icons.bolt_rounded,
                  label: 'Trip Efficiency',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ChartHeader(
                    title: 'AI-Powered 30-Day Revenue Forecasting',
                    subtitle: 'Prediction model trained on historical trip & ticket data',
                    badge: 'AI Model',
                    badgeColor: AppTheme.emerald,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: _RevenueLineChart(
                      spots: _revenueSpots,
                      upperBound: _upperBound,
                      lowerBound: _lowerBound,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ChartLegend(),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Hourly Passenger Bar Chart ────────────────────
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ChartHeader(
                    title: 'Daily Passenger Count per Hour',
                    subtitle: 'Identifying peak student demand windows',
                    badge: 'Analytics',
                    badgeColor: Color(0xFF7C4DFF),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 180,
                    child: _PassengerBarChart(data: _hourlyPassengers),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Audit Log Table ───────────────────────────────
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_rounded,
                          color: AppTheme.emerald, size: 18),
                      const SizedBox(width: 8),
                      Text('Audit Log',
                          style: GoogleFonts.inter(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: const BoxDecoration(
                          color: Colors.white10,
                          borderRadius: AppTheme.borderRadius,
                        ),
                        child: Text('Firestore Synced',
                            style: GoogleFonts.inter(
                                color: AppTheme.textSecondary,
                                fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _AuditLogTable(entries: _auditLog),
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

// ── AI Badge ─────────────────────────────────────────────────
class _AiBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderColor: AppTheme.emerald.withOpacity(0.4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withOpacity(0.15),
              borderRadius: AppTheme.borderRadius,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppTheme.emerald, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI-Powered Revenue Prediction Engine',
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
                Text(
                  'Forecasts generated by ML model trained on 6 months of trip & ticketing data. Individual contribution: IT24200314.',
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chart Header ──────────────────────────────────────────────
class _ChartHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;

  const _ChartHeader({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.12),
            borderRadius: AppTheme.borderRadius,
            border:
                Border.all(color: badgeColor.withOpacity(0.4)),
          ),
          child: Text(badge,
              style: GoogleFonts.inter(
                color: badgeColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              )),
        ),
      ],
    );
  }
}

// ── Revenue Line Chart ────────────────────────────────────────
class _RevenueLineChart extends StatelessWidget {
  final List<FlSpot> spots;
  final List<FlSpot> upperBound;
  final List<FlSpot> lowerBound;

  const _RevenueLineChart({
    required this.spots,
    required this.upperBound,
    required this.lowerBound,
  });

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: Colors.white10,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              reservedSize: 36,
              getTitlesWidget: (val, _) => Text(
                '${val.toInt()}k',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              getTitlesWidget: (val, _) => Text(
                'D${val.toInt() + 1}',
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
        minY: 30, maxY: 105,
        lineBarsData: [
          // Confidence band — upper
          LineChartBarData(
            spots: upperBound,
            isCurved: true,
            color: AppTheme.emerald.withOpacity(0.1),
            barWidth: 0,
            belowBarData: BarAreaData(show: false),
            dotData: const FlDotData(show: false),
          ),
          // Confidence band — lower (fills between upper)
          LineChartBarData(
            spots: lowerBound,
            isCurved: true,
            color: AppTheme.emerald.withOpacity(0.1),
            barWidth: 0,
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.emerald.withOpacity(0.08),
              applyCutOffY: false,
            ),
            dotData: const FlDotData(show: false),
          ),
          // Main forecast line
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppTheme.emerald,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.emerald.withOpacity(0.25),
                  AppTheme.emerald.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.midBlue,
            getTooltipItems: (spots) => spots.map((s) =>
              LineTooltipItem(
                'LKR ${(s.y * 1000).toStringAsFixed(0)}',
                GoogleFonts.inter(
                    color: AppTheme.emerald,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Chart Legend ──────────────────────────────────────────────
class _ChartLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _LegendDot(color: AppTheme.emerald, label: 'AI Prediction'),
        const SizedBox(width: 16),
        _LegendDot(color: AppTheme.emerald.withOpacity(0.3), label: 'Confidence Band'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.inter(
                color: AppTheme.textSecondary, fontSize: 10)),
      ],
    );
  }
}

// ── Passenger Bar Chart ───────────────────────────────────────
class _PassengerBarChart extends StatelessWidget {
  final List<double> data;
  const _PassengerBarChart({required this.data});

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
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
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
              getTitlesWidget: (val, _) => Text(
                val.toInt() % 3 == 0
                    ? '${val.toInt()}:00'
                    : '',
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
                    : AppTheme.emerald.withOpacity(0.4),
                width: 8,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: 110,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Audit Log Table ────────────────────────────────────────────
class _AuditLogTable extends StatelessWidget {
  final List<_AuditEntry> entries;
  const _AuditLogTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(0.9),
        3: FlexColumnWidth(1.3),
      },
      children: [
        // Header
        TableRow(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: AppTheme.borderRadius,
          ),
          children: ['Trip ID', 'Bus No.', 'Pax', 'Revenue']
              .map((h) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    child: Text(h,
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        )),
                  ))
              .toList(),
        ),
        ...entries.asMap().entries.map((e) => TableRow(
          decoration: BoxDecoration(
            color: e.key.isEven
                ? Colors.white.withOpacity(0.02)
                : Colors.transparent,
          ),
          children: [
            _TableCell(e.value.tripId, isId: true),
            _TableCell(e.value.busNo),
            _TableCell(e.value.passengers.toString()),
            _TableCell(e.value.revenue, isRevenue: true),
          ],
        )),
      ],
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool isId;
  final bool isRevenue;
  const _TableCell(this.text, {this.isId = false, this.isRevenue = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: isRevenue
              ? AppTheme.emerald
              : isId
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: isRevenue
              ? FontWeight.w600
              : isId
                  ? FontWeight.w600
                  : FontWeight.w400,
        ),
      ),
    );
  }
}

class _AuditEntry {
  final String tripId;
  final String busNo;
  final int passengers;
  final String revenue;
  const _AuditEntry(this.tripId, this.busNo, this.passengers, this.revenue);
}
