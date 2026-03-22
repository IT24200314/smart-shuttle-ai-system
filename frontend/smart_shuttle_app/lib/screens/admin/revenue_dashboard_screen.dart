import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../utils/api_config.dart';

class RevenueDashboardScreen extends StatefulWidget {
  const RevenueDashboardScreen({super.key});
  @override
  State<RevenueDashboardScreen> createState() => _RevenueDashboardScreenState();
}

class _RevenueDashboardScreenState extends State<RevenueDashboardScreen> {
  Future<Map<String, dynamic>> fetchDashboard() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/dashboard/revenue-summary'));
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body));
    }
    throw Exception('Failed to load dashboard data');
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shuttle Operations',
                style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            Text('Live Financial Dashboard',
                style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.tune_rounded, color: AppTheme.textSecondary, size: 20), onPressed: () {}),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchDashboard(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error rendering dashboard.\n${snapshot.error}', style: const TextStyle(color: AppTheme.danger)));
          }

          final data = snapshot.data!;
          final summary = data['summary_data'] ?? {};
          final aiRec = data['ai_recommendation'] ?? {};
          final alert = data['low_demand_alert'];
          final best = data['best_trip'];
          final worst = data['worst_trip'];
          final recent = List<Map<String, dynamic>>.from(data['recent_trips'] ?? []);

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            color: AppTheme.accent,
            backgroundColor: AppTheme.surfaceHigh,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  
                  // SECTION 2: AI SCHEDULING RECOMMENDATION
                  _SectionHeader('AI Scheduling Decision'),
                  const SizedBox(height: 12),
                  _buildAIRecoCard(aiRec),
                  const SizedBox(height: 24),

                  // SECTION 3: LOW DEMAND ALERT (If any)
                  if (alert != null) ...[
                    _buildYieldAlertCard(alert),
                    const SizedBox(height: 24),
                  ],

                  // SECTION 4: TOP KPI CARDS
                  _SectionHeader('Today\'s Core Metrics'),
                  const SizedBox(height: 12),
                  _buildKPIGrid(summary),
                  const SizedBox(height: 24),

                  // SECTION 5: SHUTTLE REALITY CHECK
                  _SectionHeader('Operational Integrity Check'),
                  const SizedBox(height: 12),
                  _buildRealityCheckCard(summary),
                  const SizedBox(height: 24),

                  // SECTION 6: BEST / WORST TRIP
                  _SectionHeader('Trip Performance Extremes'),
                  const SizedBox(height: 12),
                  _buildBestWorstTrips(best, worst),
                  const SizedBox(height: 28),

                  // SECTION 7: REVENUE VS COST CHART
                  _SectionHeader('Revenue vs Break-even (4000)'),
                  const SizedBox(height: 12),
                  _buildBreakEvenChart(recent),
                  const SizedBox(height: 28),

                  // SECTION 8: TRIP LEDGER TABLE
                  _SectionHeader('Trip Ledger'),
                  const SizedBox(height: 12),
                  _buildTripLedgerTable(recent),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // BUILDERS
  // -------------------------------------------------------------

  Widget _buildAIRecoCard(Map<String, dynamic> ai) {
    final conf = ai['confidence'] ?? 'High';
    return GlassCard(
      padding: const EdgeInsets.all(16),
      fillColor: AppTheme.accent.withOpacity(0.05),
      borderColor: AppTheme.accent.withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Should we run this trip tomorrow?', 
                  style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text('$conf Confidence', style: GoogleFonts.inter(color: AppTheme.accent, fontSize: 9, fontWeight: FontWeight.w700)),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDecisionBlock('Morning', ai['morning_action'] ?? '')),
              const SizedBox(width: 12),
              Expanded(child: _buildDecisionBlock('Evening', ai['evening_action'] ?? '')),
            ],
          ),
          if (ai['reason_points'] != null && (ai['reason_points'] as List).isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 12),
            ...List<Widget>.from((ai['reason_points'] as List).map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4, right: 6),
                    child: Icon(Icons.circle, color: AppTheme.textMuted, size: 6),
                  ),
                  Expanded(child: Text(r.toString(), style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11))),
                ],
              ),
            ))),
          ]
        ],
      ),
    );
  }

  Widget _buildDecisionBlock(String time, String action) {
    final isNegative = action.contains('Cancel') || action.contains('Review');
    final color = isNegative ? AppTheme.danger : AppTheme.positive;
    final icon = isNegative ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(time.toUpperCase(), style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(action, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYieldAlertCard(Map<String, dynamic> alert) {
    return GlassCard(
      fillColor: AppTheme.danger.withOpacity(0.08),
      borderColor: AppTheme.danger.withOpacity(0.4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 18),
              const SizedBox(width: 8),
              Text(alert['title'] ?? 'Low Demand Alert', 
                style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAlertStat('Trips', '${alert['last_n_evening_trips'] ?? 0}'),
              _buildAlertStat('Avg Rev', 'Rs. ${alert['avg_revenue']?.toInt() ?? 0}'),
              _buildAlertStat('Fixed Cost', 'Rs. 4000'),
              _buildAlertStat('Avg Loss', 'Rs. ${alert['avg_loss']?.toInt() ?? 0}', color: AppTheme.danger),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.danger.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Row(
              children: [
                Expanded(child: Text(alert['recommendation'] ?? '', 
                  style: GoogleFonts.inter(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.w600))),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAlertStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(color: color ?? AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildKPIGrid(Map<String, dynamic> summary) {
    final net = summary['net_profit_today']?.toDouble() ?? 0.0;
    final rev = summary['revenue_today']?.toDouble() ?? 0.0;
    final leak = summary['ticket_leakage_amount']?.toDouble() ?? 0.0;
    final leakPct = summary['ticket_leakage_percent']?.toDouble() ?? 0.0;
    final trips = summary['trips_done_today'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildKPICard('Revenue Today', 'Rs. ${rev.toInt()}', AppTheme.positive),
        _buildKPICard('Net Profit Today', 'Rs. ${net.toInt()}${net >= 0 ? ' (Profit)' : ' (Loss)'}', net >= 0 ? AppTheme.positive : AppTheme.danger),
        _buildKPICard('Ticket Leakage', 'Rs. ${leak.toInt()} (${leakPct.toStringAsFixed(1)}%)', 
            leakPct > 10 ? AppTheme.danger : (leakPct >= 5 ? Colors.orange : AppTheme.positive)),
        _buildKPICard('Trips Done', '$trips', AppTheme.textPrimary),
      ],
    );
  }

  Widget _buildKPICard(String label, String value, Color valueColor) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(), style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: GoogleFonts.inter(color: valueColor, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -1)),
          ),
        ],
      ),
    );
  }

  Widget _buildRealityCheckCard(Map<String, dynamic> summary) {
    final ai = summary['total_ai_passengers'] ?? 0;
    final tkt = summary['total_tickets_sold'] ?? 0;
    final unpaid = summary['total_unpaid_or_leaked'] ?? 0;
    final rate = summary['overall_leakage_rate']?.toDouble() ?? 0.0;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildRealityStat('AI Passengers', '$ai', Icons.remove_red_eye_rounded, AppTheme.accent)),
              Container(width: 1, height: 40, color: AppTheme.border),
              Expanded(child: _buildRealityStat('Tickets Sold', '$tkt', Icons.receipt_rounded, AppTheme.positive)),
              Container(width: 1, height: 40, color: AppTheme.border),
              Expanded(child: _buildRealityStat('Unpaid / Leaked', '$unpaid', Icons.warning_rounded, unpaid > 0 ? AppTheme.danger : AppTheme.positive)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.surfaceHigh, borderRadius: AppTheme.chipRadius),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Overall Leakage Rate: ', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12)),
                Text('${rate.toStringAsFixed(1)}%', style: GoogleFonts.inter(color: rate > 5 ? AppTheme.danger : AppTheme.positive, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRealityStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 9)),
      ],
    );
  }

  Widget _buildBestWorstTrips(Map<String, dynamic>? best, Map<String, dynamic>? worst) {
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            fillColor: AppTheme.positive.withOpacity(0.05),
            borderColor: AppTheme.positive.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Best Trip', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 10)),
                const SizedBox(height: 6),
                Text(best?['trip_type'] ?? 'N/A', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(best?['label'] ?? '0', style: GoogleFonts.inter(color: AppTheme.positive, fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            fillColor: AppTheme.danger.withOpacity(0.05),
            borderColor: AppTheme.danger.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Worst Trip', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 10)),
                const SizedBox(height: 6),
                Text(worst?['trip_type'] ?? 'N/A', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(worst?['label'] ?? '0', style: GoogleFonts.inter(color: AppTheme.danger, fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakEvenChart(List<Map<String, dynamic>> recent) {
    if (recent.isEmpty) {
      return const SizedBox(height: 150, child: Center(child: Text('No trip data available', style: TextStyle(color: AppTheme.textMuted))));
    }
    
    // Reverse to chronological order for the chart (oldest left, newest right)
    final chartData = recent.reversed.toList();
    
    // Safety check max limit to avoid overcrowding x-axis
    final displayData = chartData.length > 7 ? chartData.sublist(chartData.length - 7) : chartData;

    return GlassCard(
      padding: const EdgeInsets.only(top: 30, bottom: 10, left: 10, right: 20),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 12000, // Fixed cost is 4000, so 12000 max is safe
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (group) => Colors.transparent,
                tooltipPadding: EdgeInsets.zero,
                tooltipMargin: 6,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final formatter = NumberFormat('#,###');
                  final str = formatter.format(rod.toY);
                  return BarTooltipItem(
                    'Rs. $str',
                    GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 9, fontWeight: FontWeight.w700),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    if (value.toInt() >= displayData.length) return const SizedBox.shrink();
                    final typeStr = displayData[value.toInt()]['trip_type'].toString().toUpperCase();
                    final mode = (typeStr == 'STANDARD' || typeStr.trim().isEmpty) ? 'E' : typeStr.substring(0, 1);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(mode, style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
                    );
                  },
                ),
              ),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 4000, // Specifically intervaling at the break-even point
              getDrawingHorizontalLine: (value) {
                if (value == 4000) {
                  return const FlLine(color: Colors.yellow, strokeWidth: 1.5, dashArray: [4, 4]); // Break-even line
                }
                return const FlLine(color: AppTheme.border, strokeWidth: 0.5);
              },
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(displayData.length, (i) {
              final val = displayData[i]['actual_revenue']?.toDouble() ?? 0.0;
              final isProfit = displayData[i]['is_profit'] as bool;
              final pnl = displayData[i]['profit_or_loss']?.toInt() ?? 0;
              
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: val,
                    color: isProfit ? AppTheme.positive : AppTheme.danger,
                    width: 14,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), topRight: Radius.circular(3)),
                  )
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildTripLedgerTable(List<Map<String, dynamic>> recent) {
    if (recent.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No trips available', style: TextStyle(color: AppTheme.textMuted)),
      );
    }
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppTheme.cardRadius,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.surfaceHigh,
              child: Row(
                children: [
                  Expanded(flex: 3, child: _TableHeader('Date & Type')),
                  Expanded(flex: 2, child: _TableHeader('Pax / Tkt', center: true)),
                  Expanded(flex: 2, child: _TableHeader('Profit/Loss', right: true)),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            ...recent.asMap().entries.map((e) {
              final trip = e.value;
              final isEq = e.key.isEven;
              final isWarn = trip['is_warning'] == true;
              final pnl = trip['profit_or_loss']?.toInt() ?? 0;
              final pnlStr = pnl >= 0 ? '+Rs. $pnl' : '-Rs. ${pnl.abs()}';
              final rawType = trip['trip_type']?.toString().toUpperCase() ?? '-';
              final displayType = (rawType == 'STANDARD' || rawType.trim().isEmpty) ? 'EMPTY TRIP' : rawType;
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                color: isEq ? AppTheme.surfaceHigh.withOpacity(0.5) : Colors.transparent,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trip['date'] ?? '-', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 10)),
                          const SizedBox(height: 2),
                          Text(displayType, style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('${trip['ai_passengers']} / ${trip['tickets_sold']}', 
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 12)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(pnlStr, 
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          color: trip['is_profit'] ? AppTheme.positive : AppTheme.danger, 
                          fontSize: 12, 
                          fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 14),
                    Icon(isWarn ? Icons.warning_amber_rounded : Icons.circle, 
                      color: isWarn ? AppTheme.danger : AppTheme.positive, 
                      size: isWarn ? 14 : 8),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String label;
  final bool right;
  final bool center;
  const _TableHeader(this.label, {this.right = false, this.center = false});
  @override
  Widget build(BuildContext context) {
    var align = TextAlign.left;
    if (right) align = TextAlign.right;
    if (center) align = TextAlign.center;
    return Text(label, textAlign: align, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600));
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title.toUpperCase(), style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: AppTheme.border)),
      ],
    );
  }
}
