import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state_provider.dart';
import '../../utils/api_config.dart';
import '../../utils/download_helper.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/theme_toggle_button.dart';

class RevenueDashboardScreen extends StatefulWidget {
  const RevenueDashboardScreen({super.key});
  @override
  State<RevenueDashboardScreen> createState() => _RevenueDashboardScreenState();
}

class _RevenueDashboardScreenState extends State<RevenueDashboardScreen> {
  late Future<Map<String, dynamic>> _dashboardFuture;
  String _selectedPreset = 'today';
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = fetchDashboard();
  }

  Future<Map<String, dynamic>> fetchDashboard() async {
    final uri = _buildDashboardUri('/dashboard/revenue-summary');
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body));
    }
    throw Exception('Failed to load dashboard data');
  }

  Uri _buildDashboardUri(String path) {
    final query = <String, String>{'range': _selectedPreset};
    if (_selectedPreset == 'custom' && _customRange != null) {
      query['start_date'] =
          DateFormat('yyyy-MM-dd').format(_customRange!.start);
      query['end_date'] = DateFormat('yyyy-MM-dd').format(_customRange!.end);
    }
    return Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: query);
  }

  void _reloadDashboard() {
    setState(() {
      _dashboardFuture = fetchDashboard();
    });
  }

  Future<void> _selectPreset(String preset) async {
    if (preset == 'custom') {
      await _pickCustomRange();
      return;
    }
    setState(() {
      _selectedPreset = preset;
      _dashboardFuture = fetchDashboard();
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customRange,
      helpText: 'Select Report Range',
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _selectedPreset = 'custom';
      _dashboardFuture = fetchDashboard();
    });
  }

  Future<void> _downloadReport() async {
    final url = _buildDashboardUri('/dashboard/revenue-report.csv').toString();
    try {
      await triggerFileDownload(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV report download started.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download unavailable: $error')),
      );
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is List) {
      return value.map((item) => _asMap(item)).toList();
    }
    return <Map<String, dynamic>>[];
  }

  String _tripOutcomeLabel(Map<String, dynamic> trip) {
    final profit = _asDouble(trip['profit_or_loss']);
    if (profit >= 0) return 'Profitable Trip';
    return 'Loss Trip';
  }

  String? _tripRiskLabel(Map<String, dynamic> trip) {
    final aiPassengers = _asInt(trip['ai_passengers']);
    final unpaid = _asInt(trip['unpaid_or_leaked']);
    final leakageRate = aiPassengers > 0 ? (unpaid / aiPassengers) * 100 : 0.0;
    if (leakageRate >= 15 || unpaid >= 3) return 'High Leakage';
    if (unpaid > 0) return 'Leakage Detected';
    return null;
  }

  Color _breakEvenColor(Map<String, dynamic> trip) {
    final profit = _asDouble(trip['profit_or_loss']);
    final aiPassengers = _asInt(trip['ai_passengers']);
    final ticketsSold = _asInt(trip['tickets_sold']);
    final revenue = _asDouble(trip['actual_revenue']);
    if (aiPassengers == 0 && ticketsSold == 0 && revenue == 0) {
      return AppTheme.textMuted.withOpacity(0.7);
    }
    if (profit >= 500) return AppTheme.positive;
    if (profit <= -500) return AppTheme.danger;
    return AppTheme.warning;
  }

  String _breakEvenLabel(Map<String, dynamic> trip) {
    final rawDate = trip['date']?.toString() ?? '';
    final tripType = _tripDisplayType(trip)
        .replaceAll('NO BOARDINGS', 'No Boardings')
        .replaceAll('SCHEDULED TRIP', 'Scheduled Trip');
    final prettyType = tripType
        .split(' ')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
    try {
      final parsed = DateTime.parse(rawDate.split(' ').first);
      return '${DateFormat('MMM d').format(parsed)}\n($prettyType)';
    } catch (_) {
      return prettyType;
    }
  }

  String _buildBreakEvenInsight(List<Map<String, dynamic>> trips) {
    int morningProfit = 0;
    int eveningLoss = 0;
    int totalMorning = 0;
    int totalEvening = 0;

    for (final trip in trips) {
      final tripType = trip['trip_type']?.toString().toLowerCase() ?? '';
      final profit = _asDouble(trip['profit_or_loss']);
      if (tripType.contains('morning')) {
        totalMorning++;
        if (profit >= 0) morningProfit++;
      } else if (tripType.contains('evening')) {
        totalEvening++;
        if (profit < 0) eveningLoss++;
      }
    }

    if (totalMorning > 0 &&
        totalEvening > 0 &&
        morningProfit == totalMorning &&
        eveningLoss >= (totalEvening / 2).ceil()) {
      return 'Morning trips are consistently profitable while evening trips show more losses.';
    }
    if (eveningLoss == totalEvening && totalEvening > 0) {
      return 'Evening trips are underperforming across this selected range and may need review.';
    }
    if (morningProfit == totalMorning && totalMorning > 0) {
      return 'Morning trips are sustaining the strongest break-even performance in this range.';
    }
    return 'Profitability is mixed across the selected trips, with break-even performance varying by trip type.';
  }

  String _tripDisplayType(Map<String, dynamic> trip) {
    final rawType = trip['trip_type']?.toString().trim();
    final aiPassengers = _asInt(trip['ai_passengers']);
    final ticketsSold = _asInt(trip['tickets_sold']);
    if ((rawType == null ||
            rawType.isEmpty ||
            rawType.toUpperCase() == 'STANDARD') &&
        aiPassengers == 0 &&
        ticketsSold == 0) {
      return 'No Boardings';
    }
    if (rawType != null && rawType.contains('No Boarding Trips')) {
      return rawType;
    }
    if (rawType == null ||
        rawType.isEmpty ||
        rawType.toUpperCase() == 'STANDARD') {
      return 'Scheduled Trip';
    }
    return rawType.toUpperCase();
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: AppTheme.border,
    );
  }

  Widget _buildStatusDot(bool isWarning) {
    return Icon(
      isWarning ? Icons.warning_amber_rounded : Icons.circle,
      color: isWarning ? AppTheme.danger : AppTheme.positive,
      size: isWarning ? 14 : 8,
    );
  }

  List<Map<String, dynamic>> _buildBreakEvenRows(
      List<Map<String, dynamic>> trips) {
    final visibleRows = <Map<String, dynamic>>[];
    final noBoardingTrips = trips
        .where((trip) =>
            _asInt(trip['ai_passengers']) == 0 &&
            _asInt(trip['tickets_sold']) == 0)
        .toList();
    final regularTrips = trips
        .where((trip) => !(_asInt(trip['ai_passengers']) == 0 &&
            _asInt(trip['tickets_sold']) == 0))
        .toList();

    visibleRows.addAll(regularTrips);

    if (noBoardingTrips.length == 1) {
      visibleRows.add(noBoardingTrips.first);
    } else if (noBoardingTrips.length > 1) {
      final combinedProfit = noBoardingTrips.fold<double>(
          0.0, (sum, trip) => sum + _asDouble(trip['profit_or_loss']));
      visibleRows.add({
        'date': 'Multiple Dates',
        'trip_type': 'No Boarding Trips (${noBoardingTrips.length})',
        'ai_passengers': 0,
        'tickets_sold': 0,
        'actual_revenue': 0.0,
        'profit_or_loss': combinedProfit,
        'is_profit': combinedProfit >= 0,
        'is_warning': combinedProfit < 0,
        'unpaid_or_leaked': 0,
      });
    }

    return visibleRows;
  }

  String _buildTrendInsight(
      List<Map<String, dynamic>> trends, bool isTodayRange) {
    if (trends.length < 2) {
      return isTodayRange
          ? 'Today has limited completed trip buckets, so benchmark context is used to keep the trend meaningful.'
          : 'This selected range has limited data points, so benchmark context remains visible.';
    }

    final firstTickets = _asDouble(trends.first['tickets_sold']);
    final lastTickets = _asDouble(trends.last['tickets_sold']);
    if (lastTickets < firstTickets) {
      return isTodayRange
          ? 'Ticket sales decreased across the visible time buckets today.'
          : 'Ticket demand softened toward the end of the selected period.';
    }
    if (lastTickets > firstTickets) {
      return isTodayRange
          ? 'Ticket sales improved across the visible time buckets today.'
          : 'Ticket demand strengthened over the selected period.';
    }
    return 'Ticket demand remained relatively steady across the visible buckets.';
  }

  List<String> _buildStrategicInsights(List<Map<String, dynamic>> trips) {
    if (trips.isEmpty) {
      return [
        'No completed trips are available yet for strategic insight generation.'
      ];
    }

    double morningProfit = 0;
    double eveningProfit = 0;
    int belowBreakEven = 0;
    int morningCount = 0;
    int eveningCount = 0;

    for (final trip in trips) {
      final tripType = trip['trip_type']?.toString().toLowerCase() ?? '';
      final profit = _asDouble(trip['profit_or_loss']);
      if (profit < 0) belowBreakEven++;
      if (tripType.contains('morning')) {
        morningCount++;
        morningProfit += profit;
      } else if (tripType.contains('evening')) {
        eveningCount++;
        eveningProfit += profit;
      }
    }

    final totalProfit = morningProfit + eveningProfit;
    final morningProfitShare =
        totalProfit != 0 ? (morningProfit / totalProfit) * 100 : 0.0;
    final eveningGap = morningProfit != 0
        ? (((morningProfit - eveningProfit) / morningProfit.abs()) * 100)
        : 0.0;

    return [
      'Evening trips underperform by ${eveningGap.abs().toStringAsFixed(0)}% compared with morning profit contribution.',
      'Morning trips generate ${(morningProfitShare.clamp(-999.0, 999.0) as num).toStringAsFixed(0)}% of total profit in this view.',
      '$belowBreakEven out of ${trips.length} trips are currently below break-even.',
    ];
  }

  Widget _buildInsightBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 4, right: 6),
            child: Icon(Icons.circle, color: AppTheme.textMuted, size: 6),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildLedgerRows(
      List<Map<String, dynamic>> recent) {
    final visibleRows = <Map<String, dynamic>>[];
    final noBoardingTrips = recent
        .where((trip) =>
            _asInt(trip['ai_passengers']) == 0 &&
            _asInt(trip['tickets_sold']) == 0)
        .toList();
    final regularTrips = recent
        .where((trip) => !(_asInt(trip['ai_passengers']) == 0 &&
            _asInt(trip['tickets_sold']) == 0))
        .toList();

    visibleRows.addAll(regularTrips);

    if (noBoardingTrips.length == 1) {
      visibleRows.add(noBoardingTrips.first);
    } else if (noBoardingTrips.length > 1) {
      final combinedProfit = noBoardingTrips.fold<double>(
          0.0, (sum, trip) => sum + _asDouble(trip['profit_or_loss']));
      visibleRows.add({
        'date': 'Multiple Dates',
        'trip_type': 'No Boarding Trips (${noBoardingTrips.length})',
        'ai_passengers': 0,
        'tickets_sold': 0,
        'profit_or_loss': combinedProfit,
        'is_profit': combinedProfit >= 0,
        'is_warning': true,
        'unpaid_or_leaked': 0,
      });
    }

    return visibleRows;
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
            Text('Shuttle Operations',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text('Live Financial Dashboard',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          const ThemeToggleButton(compact: true),
          IconButton(
              icon: Icon(Icons.download_rounded,
                  color: AppTheme.textSecondary, size: 20),
              onPressed: _downloadReport),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: AppTheme.accent));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        color: AppTheme.danger, size: 32),
                    const SizedBox(height: 12),
                    Text(
                      'Dashboard data is temporarily unavailable.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _reloadDashboard,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = _asMap(snapshot.data);
          final summary = _asMap(data['summary_data']);
          final aiRec = _asMap(data['ai_recommendation']);
          final alert = data['low_demand_alert'];
          final best = data['best_trip'];
          final worst = data['worst_trip'];
          final recent = _asMapList(data['recent_trips']);
          final trends = _asMapList(data['daily_trends']);
          final percentageInsight = _asMap(data['percentage_insight']);
          final selectedRange = _asMap(data['selected_range']);
          final reportSummary = _asMap(data['report_summary']);
          final comparisonContext = _asMap(data['comparison_context']);

          return RefreshIndicator(
            onRefresh: () async => _reloadDashboard(),
            color: AppTheme.accent,
            backgroundColor: AppTheme.surfaceHigh,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1480),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return _buildDashboardLayout(
                        width: constraints.maxWidth,
                        summary: summary,
                        aiRec: aiRec,
                        alert: _asMap(alert),
                        best: _asMap(best),
                        worst: _asMap(worst),
                        recent: recent,
                        trends: trends,
                        percentageInsight: percentageInsight,
                        selectedRange: selectedRange,
                        reportSummary: reportSummary,
                        comparisonContext: comparisonContext,
                      );
                    },
                  ),
                ),
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

  Widget _buildDashboardLayout({
    required double width,
    required Map<String, dynamic> summary,
    required Map<String, dynamic> aiRec,
    required Map<String, dynamic> alert,
    required Map<String, dynamic> best,
    required Map<String, dynamic> worst,
    required List<Map<String, dynamic>> recent,
    required List<Map<String, dynamic>> trends,
    required Map<String, dynamic> percentageInsight,
    required Map<String, dynamic> selectedRange,
    required Map<String, dynamic> reportSummary,
    required Map<String, dynamic> comparisonContext,
  }) {
    final isWide = width >= 1180;
    final isMedium = width >= 860;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilterBar(selectedRange),
        const SizedBox(height: 24),
        const _SectionHeader('Selected Period Metrics'),
        const SizedBox(height: 12),
        _buildKPIGrid(summary, comparisonContext, width: width),
        const SizedBox(height: 24),
        const _SectionHeader('Trend And Insight'),
        const SizedBox(height: 12),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _buildDemandTrendChart(
                    trends, selectedRange, comparisonContext, summary),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: _buildPercentageInsightSection(
                    percentageInsight, reportSummary),
              ),
            ],
          )
        else ...[
          _buildDemandTrendChart(
              trends, selectedRange, comparisonContext, summary),
          const SizedBox(height: 14),
          _buildPercentageInsightSection(percentageInsight, reportSummary),
        ],
        const SizedBox(height: 24),
        const _SectionHeader('Decision Support'),
        const SizedBox(height: 12),
        if (isMedium && alert.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildAIRecoCard(aiRec, recent)),
              const SizedBox(width: 14),
              Expanded(child: _buildYieldAlertCard(alert)),
            ],
          )
        else ...[
          _buildAIRecoCard(aiRec, recent),
          if (alert.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildYieldAlertCard(alert),
          ],
        ],
        const SizedBox(height: 24),
        const _SectionHeader('Operational Snapshot'),
        const SizedBox(height: 12),
        if (isMedium)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  flex: 5,
                  child: _buildRealityCheckCard(summary, comparisonContext)),
              const SizedBox(width: 14),
              Expanded(
                  flex: 4,
                  child: _buildPerformanceSnapshot(
                      best, worst, comparisonContext, reportSummary)),
            ],
          )
        else ...[
          _buildRealityCheckCard(summary, comparisonContext),
          const SizedBox(height: 14),
          _buildPerformanceSnapshot(
              best, worst, comparisonContext, reportSummary),
        ],
        const SizedBox(height: 28),
        const _SectionHeader('Revenue vs Break-even (4000)'),
        const SizedBox(height: 12),
        _buildBreakEvenChart(recent, comparisonContext),
        const SizedBox(height: 28),
        const _SectionHeader('Trip Ledger'),
        const SizedBox(height: 12),
        _buildTripLedgerTable(recent, width: width),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildFilterBar(Map<String, dynamic> selectedRange) {
    final rangeLabel = selectedRange['label']?.toString() ?? 'Today';
    final rangeControls = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildRangeChip('Today', 'today'),
        _buildRangeChip('Last 7 Days', 'last7'),
        _buildRangeChip('Last 30 Days', 'last30'),
        ActionChip(
          label: Text(
            _selectedPreset == 'custom' ? 'Custom Range' : 'Custom',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          onPressed: _pickCustomRange,
          backgroundColor: _selectedPreset == 'custom'
              ? AppTheme.accent.withOpacity(0.18)
              : AppTheme.surfaceHigh,
          side: BorderSide(
            color: _selectedPreset == 'custom'
                ? AppTheme.accent.withOpacity(0.4)
                : AppTheme.border,
          ),
        ),
      ],
    );

    final periodInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reporting Period',
          style: GoogleFonts.inter(
              color: AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          rangeLabel,
          style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700),
        ),
      ],
    );

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 920;
          if (isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: rangeControls),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              color: AppTheme.textSecondary, size: 14),
                          const SizedBox(width: 8),
                          Expanded(child: periodInfo),
                          const SizedBox(width: 12),
                          FilledButton.tonalIcon(
                            onPressed: _downloadReport,
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text('Download CSV'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildRangeReferenceText(),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              rangeControls,
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      color: AppTheme.textSecondary, size: 14),
                  const SizedBox(width: 8),
                  Expanded(child: periodInfo),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: _downloadReport,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Download CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildRangeReferenceText(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRangeChip(String label, String value) {
    final isSelected = _selectedPreset == value;
    return ChoiceChip(
      selected: isSelected,
      showCheckmark: false,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelected) ...[
            Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.accent),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
      selectedColor: AppTheme.accent.withOpacity(0.2),
      backgroundColor: AppTheme.surfaceHigh,
      side: BorderSide(
          color:
              isSelected ? AppTheme.accent.withOpacity(0.7) : AppTheme.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      onSelected: (_) => _selectPreset(value),
    );
  }

  Widget _buildRangeReferenceText() {
    return Text(
      'Benchmark context remains visible for low-data ranges.',
      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10),
    );
  }

  Widget _buildLegendRow(List<Widget> items) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: items),
    );
  }

  Widget _buildTodaySummaryModeCard(
    Map<String, dynamic> summary,
    Map<String, dynamic> comparisonContext,
    Map<String, dynamic> selectedRange,
  ) {
    final tickets = _asInt(summary['total_tickets_sold']);
    final revenue = _asDouble(summary['revenue_today']);
    final profit = _asDouble(summary['net_profit_today']);
    final leakage = _asDouble(summary['ticket_leakage_amount']);
    final leakagePct = _asDouble(summary['ticket_leakage_percent']);
    final trips = _asInt(summary['trips_done_today']);
    final avgTickets = _asDouble(comparisonContext['average_daily_tickets']);
    final avgRevenue = _asDouble(comparisonContext['average_daily_revenue']);
    final avgProfit = _asDouble(comparisonContext['average_daily_profit']);
    final ticketDelta =
        _asDouble(comparisonContext['selected_period_tickets_delta_percent']);
    final revenueDelta =
        _asDouble(comparisonContext['selected_period_revenue_delta_percent']);
    final profitDelta =
        _asDouble(comparisonContext['selected_period_profit_delta_percent']);
    final benchmarkLabel =
        comparisonContext['reference_window_label']?.toString() ??
            'Reference window: last 7 completed days';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Today Summary Mode',
                  style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                selectedRange['label']?.toString() ?? 'Today',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Today view uses summary mode with benchmark context. Hourly trend is hidden for low-volume single-day data.',
            style:
                GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildCompactInsight('Tickets Sold Today', '$tickets'),
              _buildCompactInsight(
                  'Revenue Today', 'Rs. ${revenue.toStringAsFixed(0)}'),
              _buildCompactInsight(
                  'Net P/L Today', 'Rs. ${profit.toStringAsFixed(0)}'),
              _buildCompactInsight('Leakage Today',
                  'Rs. ${leakage.toStringAsFixed(0)} (${leakagePct.toStringAsFixed(1)}%)'),
              _buildCompactInsight('Trips Completed', '$trips'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Today vs 7-day average',
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildCompactInsight('Avg Tickets',
                  '${avgTickets.toStringAsFixed(1)} (${ticketDelta >= 0 ? '+' : ''}${ticketDelta.toStringAsFixed(1)}%)'),
              _buildCompactInsight('Avg Revenue',
                  'Rs. ${avgRevenue.toStringAsFixed(0)} (${revenueDelta >= 0 ? '+' : ''}${revenueDelta.toStringAsFixed(1)}%)'),
              _buildCompactInsight('Avg Profit',
                  'Rs. ${avgProfit.toStringAsFixed(0)} (${profitDelta >= 0 ? '+' : ''}${profitDelta.toStringAsFixed(1)}%)'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            benchmarkLabel,
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildDemandTrendChart(
    List<Map<String, dynamic>> trends,
    Map<String, dynamic> selectedRange,
    Map<String, dynamic> comparisonContext,
    Map<String, dynamic> summary,
  ) {
    final isTodayRange =
        (selectedRange['preset']?.toString() ?? 'today') == 'today';
    if (isTodayRange) {
      return _buildTodaySummaryModeCard(
          summary, comparisonContext, selectedRange);
    }

    if (trends.isEmpty) {
      final benchmarkLabel =
          comparisonContext['reference_window_label']?.toString() ??
              'Reference window: last 7 completed days';
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isTodayRange ? 'Hourly Ticket Sales' : 'Daily Ticket Sales',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'No completed trips were found in the selected period. Recent history is shown as context so the dashboard still stays useful on web.',
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildCompactInsight(
                    '7-day Avg Tickets',
                    _asDouble(comparisonContext['average_daily_tickets'])
                        .toStringAsFixed(1)),
                _buildCompactInsight('7-day Avg Revenue',
                    'Rs. ${_asDouble(comparisonContext['average_daily_revenue']).toStringAsFixed(0)}'),
                _buildCompactInsight('7-day Avg Leakage',
                    '${_asDouble(comparisonContext['average_daily_leakage_percent']).toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 10),
            Text(benchmarkLabel,
                style:
                    GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
          ],
        ),
      );
    }

    final benchmarkTickets =
        _asDouble(comparisonContext['average_daily_tickets']);
    final ticketsDelta =
        _asDouble(comparisonContext['selected_period_tickets_delta_percent']);
    final revenueDelta =
        _asDouble(comparisonContext['selected_period_revenue_delta_percent']);
    final benchmarkLabel =
        comparisonContext['reference_window_label']?.toString() ??
            'Reference window: last 7 completed days';
    final lowDataMode = trends.length <= 2;
    final trendInsight = _buildTrendInsight(trends, isTodayRange);

    final spots = <FlSpot>[];
    final benchmarkSpots = <FlSpot>[];
    double maxY = 0;
    for (var i = 0; i < trends.length; i++) {
      final tickets = _asDouble(trends[i]['tickets_sold']);
      spots.add(FlSpot(i.toDouble(), tickets));
      benchmarkSpots.add(FlSpot(i.toDouble(), benchmarkTickets));
      if (tickets > maxY) maxY = tickets;
    }
    if (benchmarkTickets > maxY) maxY = benchmarkTickets;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isTodayRange ? 'Hourly Ticket Sales' : 'Daily Ticket Sales',
                  style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                selectedRange['label']?.toString() ?? '',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            lowDataMode
                ? (isTodayRange
                    ? 'Today uses hourly view, with recent benchmark context to avoid a sparse single-point chart.'
                    : 'Selected range is small, so benchmark context is shown to keep the view meaningful.')
                : 'This is the primary demand view for admin reporting.',
            style:
                GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildCompactInsight(
                  '7-day Avg Tickets', benchmarkTickets.toStringAsFixed(1)),
              _buildCompactInsight('Ticket Delta',
                  '${ticketsDelta >= 0 ? '+' : ''}${ticketsDelta.toStringAsFixed(1)}%'),
              _buildCompactInsight('Revenue Delta',
                  '${revenueDelta >= 0 ? '+' : ''}${revenueDelta.toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            benchmarkLabel,
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = lowDataMode
                  ? (constraints.maxWidth > 560 ? 560.0 : constraints.maxWidth)
                  : constraints.maxWidth;
              return Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: chartWidth,
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY <= 0 ? 10 : maxY + 2,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: AppTheme.border, strokeWidth: 0.5),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => AppTheme.surfaceHigh,
                          getTooltipItems: (spots) => spots.map((spot) {
                            final point = trends[spot.x.toInt()];
                            return LineTooltipItem(
                              '${point['date']}\n'
                              'Tickets: ${_asInt(point['tickets_sold'])}\n'
                              'Revenue: Rs. ${_asDouble(point['revenue']).toStringAsFixed(0)}\n'
                              'Leakage: ${_asDouble(point['leakage_percent']).toStringAsFixed(1)}%',
                              GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            );
                          }).toList(),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            interval: maxY > 10 ? (maxY / 4).ceilToDouble() : 2,
                            getTitlesWidget: (value, _) => Text(
                              value.toInt().toString(),
                              style: GoogleFonts.inter(
                                  color: AppTheme.textMuted, fontSize: 9),
                            ),
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, _) {
                              final index = value.toInt();
                              if (index < 0 || index >= trends.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  trends[index]['label']?.toString() ?? '',
                                  style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary,
                                      fontSize: 9),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: benchmarkSpots,
                          isCurved: true,
                          color: AppTheme.textMuted.withOpacity(0.6),
                          barWidth: 2,
                          dashArray: [5, 4],
                          dotData: const FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppTheme.accent,
                          barWidth: 3,
                          belowBarData: BarAreaData(
                              show: true,
                              color: AppTheme.accent.withOpacity(0.12)),
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            trendInsight,
            style:
                GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageInsightSection(
      Map<String, dynamic> insight, Map<String, dynamic> reportSummary) {
    final paidPct = _asDouble(insight['paid_percentage']);
    final unpaidPct = _asDouble(insight['unpaid_percentage']);
    final profitablePct = _asDouble(insight['profitable_trip_percentage']);
    final morningSuccess = _asDouble(insight['morning_success_percentage']);
    final eveningSuccess = _asDouble(insight['evening_success_percentage']);
    final lowDemandTrips = _asInt(reportSummary['low_demand_trip_count']);

    final pieCard = GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paid vs Unpaid',
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 42,
                sectionsSpace: 4,
                sections: [
                  PieChartSectionData(
                    value: paidPct <= 0 && unpaidPct <= 0 ? 100 : paidPct,
                    color: AppTheme.positive,
                    title: '${paidPct.toStringAsFixed(0)}%',
                    radius: 36,
                    titleStyle: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  PieChartSectionData(
                    value: paidPct <= 0 && unpaidPct <= 0 ? 0 : unpaidPct,
                    color: AppTheme.danger,
                    title: '${unpaidPct.toStringAsFixed(0)}%',
                    radius: 36,
                    titleStyle: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendDot(AppTheme.positive, 'Paid'),
              _buildLegendDot(AppTheme.danger, 'Unpaid'),
            ],
          ),
        ],
      ),
    );

    final summaryCard = GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Decision Support Snapshot',
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _buildPercentBar(
              'Profitable Trips', profitablePct, AppTheme.positive),
          const SizedBox(height: 10),
          _buildPercentBar('Morning Success', morningSuccess, AppTheme.accent),
          const SizedBox(height: 10),
          _buildPercentBar('Evening Success', eveningSuccess, AppTheme.warning),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _buildCompactInsight(
                      'Low-demand Trips', '$lowDemandTrips')),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildCompactInsight(
                      'Leakage', '${unpaidPct.toStringAsFixed(1)}%')),
            ],
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              pieCard,
              const SizedBox(height: 12),
              summaryCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: pieCard),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: summaryCard),
          ],
        );
      },
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style:
                GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildPercentBar(String label, double value, Color color) {
    final safeValue = value.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(label,
                    style: GoogleFonts.inter(
                        color: AppTheme.textSecondary, fontSize: 11))),
            Text('${safeValue.toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: safeValue / 100,
            minHeight: 8,
            backgroundColor: AppTheme.surfaceHigh,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactInsight(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildAIRecoCard(
      Map<String, dynamic> ai, List<Map<String, dynamic>> recent) {
    final conf = ai['confidence'] ?? 'High';
    final strategicInsights = _buildStrategicInsights(recent);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      fillColor: AppTheme.accent.withOpacity(0.05),
      borderColor: AppTheme.accent.withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: AppTheme.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Should we run this trip tomorrow?',
                    style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4)),
                child: Text('$conf Confidence',
                    style: GoogleFonts.inter(
                        color: AppTheme.accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildDecisionBlock(
                      'Morning', ai['morning_action'] ?? '')),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildDecisionBlock(
                      'Evening', ai['evening_action'] ?? '')),
            ],
          ),
          if (ai['reason_points'] != null &&
              (ai['reason_points'] as List).isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: AppTheme.border),
            const SizedBox(height: 12),
            ...List<Widget>.from(
                (ai['reason_points'] as List).map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 4, right: 6),
                            child: Icon(Icons.circle,
                                color: AppTheme.textMuted, size: 6),
                          ),
                          Expanded(
                              child: Text(r.toString(),
                                  style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11))),
                        ],
                      ),
                    ))),
          ],
          if (strategicInsights.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(color: AppTheme.border),
            const SizedBox(height: 12),
            Text(
              'Operational Insights',
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...strategicInsights.map(_buildInsightBullet),
          ],
        ],
      ),
    );
  }

  Widget _buildDecisionBlock(String time, String action) {
    final isNegative = action.contains('Cancel') || action.contains('Review');
    final color = isNegative ? AppTheme.danger : AppTheme.positive;
    final icon = isNegative
        ? Icons.warning_amber_rounded
        : Icons.check_circle_outline_rounded;
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
          Text(time.toUpperCase(),
              style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(action,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYieldAlertCard(Map<String, dynamic> alert) {
    final avgRevenue = _asDouble(alert['avg_revenue']);
    final avgLoss = _asDouble(alert['avg_loss']);
    return GlassCard(
      fillColor: AppTheme.danger.withOpacity(0.08),
      borderColor: AppTheme.danger.withOpacity(0.4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  color: AppTheme.danger, size: 18),
              const SizedBox(width: 8),
              Text(alert['title'] ?? 'Low Demand Alert',
                  style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAlertStat('Trips', '${alert['last_n_evening_trips'] ?? 0}'),
              _buildAlertStat('Avg Rev', 'Rs. ${avgRevenue.toInt()}'),
              _buildAlertStat('Fixed Cost', 'Rs. 4000'),
              _buildAlertStat('Avg Loss', 'Rs. ${avgLoss.toInt()}',
                  color: AppTheme.danger),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6)),
            child: Row(
              children: [
                Expanded(
                    child: Text(alert['recommendation'] ?? '',
                        style: GoogleFonts.inter(
                            color: AppTheme.danger,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
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
        Text(label,
            style:
                GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.inter(
                color: color ?? AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildKPIGrid(
      Map<String, dynamic> summary, Map<String, dynamic> comparisonContext,
      {required double width}) {
    final net = _asDouble(summary['net_profit_today']);
    final rev = _asDouble(summary['revenue_today']);
    final leak = _asDouble(summary['ticket_leakage_amount']);
    final leakPct = _asDouble(summary['ticket_leakage_percent']);
    final trips = _asInt(summary['trips_done_today']);
    final benchmarkLabel =
        comparisonContext['reference_window_label']?.toString() ??
            'selected range';
    final revenueDelta =
        _asDouble(comparisonContext['selected_period_revenue_delta_percent']);
    final profitDelta =
        _asDouble(comparisonContext['selected_period_profit_delta_percent']);
    final ticketsDelta =
        _asDouble(comparisonContext['selected_period_tickets_delta_percent']);
    final crossAxisCount = width >= 1100 ? 4 : 2;
    final ratio = width >= 1100 ? 1.9 : 1.5;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: ratio,
      children: [
        _buildKPICard('Revenue', 'Rs. ${rev.toInt()}', AppTheme.positive,
            subtitle:
                '${revenueDelta >= 0 ? '+' : ''}${revenueDelta.toStringAsFixed(1)}% vs benchmark'),
        _buildKPICard(
            'Net Profit',
            'Rs. ${net.toInt()}${net >= 0 ? ' (Profit)' : ' (Loss)'}',
            net >= 0 ? AppTheme.positive : AppTheme.danger,
            subtitle:
                '${profitDelta >= 0 ? '+' : ''}${profitDelta.toStringAsFixed(1)}% vs benchmark'),
        _buildKPICard(
            'Ticket Leakage',
            'Rs. ${leak.toInt()} (${leakPct.toStringAsFixed(1)}%)',
            leakPct > 10
                ? AppTheme.danger
                : (leakPct >= 5 ? AppTheme.warning : AppTheme.positive),
            subtitle: benchmarkLabel),
        _buildKPICard('Trips Done', '$trips', AppTheme.textPrimary,
            subtitle:
                '${ticketsDelta >= 0 ? '+' : ''}${ticketsDelta.toStringAsFixed(1)}% demand vs benchmark'),
      ],
    );
  }

  Widget _buildKPICard(String label, String value, Color valueColor,
      {String? subtitle}) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: GoogleFonts.inter(
                    color: valueColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1)),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle,
                style:
                    GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
          ],
        ],
      ),
    );
  }

  Widget _buildRealityCheckCard(
      Map<String, dynamic> summary, Map<String, dynamic> comparisonContext) {
    final ai = _asInt(summary['total_ai_passengers']);
    final tkt = _asInt(summary['total_tickets_sold']);
    final unpaid = _asInt(summary['total_unpaid_or_leaked']);
    final rate = _asDouble(summary['overall_leakage_rate']);
    final benchmarkLabel =
        comparisonContext['reference_window_label']?.toString() ??
            'recent average';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: _buildRealityStat('Est. Passengers', '$ai',
                      Icons.remove_red_eye_rounded, AppTheme.accent)),
              Container(width: 1, height: 40, color: AppTheme.border),
              Expanded(
                  child: _buildRealityStat('Tickets Sold', '$tkt',
                      Icons.receipt_rounded, AppTheme.positive)),
              Container(width: 1, height: 40, color: AppTheme.border),
              Expanded(
                  child: _buildRealityStat(
                      'Unpaid / Leaked',
                      '$unpaid',
                      Icons.warning_rounded,
                      unpaid > 0 ? AppTheme.danger : AppTheme.positive)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.surfaceHigh, borderRadius: AppTheme.chipRadius),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Overall Leakage Rate: ',
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary, fontSize: 12)),
                    Text('${rate.toStringAsFixed(1)}%',
                        style: GoogleFonts.inter(
                            color:
                                rate > 5 ? AppTheme.danger : AppTheme.positive,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Compared with recent context: $benchmarkLabel',
                  style: GoogleFonts.inter(
                      color: AppTheme.textMuted, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPerformanceSnapshot(
    Map<String, dynamic> best,
    Map<String, dynamic> worst,
    Map<String, dynamic> comparisonContext,
    Map<String, dynamic> reportSummary,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Performance Snapshot',
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _buildBestWorstTrips(best, worst),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildCompactInsight('Low-demand Trips',
                      '${_asInt(reportSummary['low_demand_trip_count'])}')),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildCompactInsight('7-day Avg Profit',
                      'Rs. ${_asDouble(comparisonContext['average_daily_profit']).toStringAsFixed(0)}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealityStat(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        Text(value,
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style:
                GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 9)),
      ],
    );
  }

  Widget _buildBestWorstTrips(
      Map<String, dynamic>? best, Map<String, dynamic>? worst) {
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
                Text('Best Trip',
                    style: GoogleFonts.inter(
                        color: AppTheme.textSecondary, fontSize: 10)),
                const SizedBox(height: 6),
                Text(best?['trip_type'] ?? 'N/A',
                    style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(best?['label'] ?? '0',
                    style: GoogleFonts.inter(
                        color: AppTheme.positive,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                _buildMiniStatusChip('Profitable Trip', AppTheme.positive),
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
                Text('Worst Trip',
                    style: GoogleFonts.inter(
                        color: AppTheme.textSecondary, fontSize: 10)),
                const SizedBox(height: 6),
                Text(worst?['trip_type'] ?? 'N/A',
                    style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(worst?['label'] ?? '0',
                    style: GoogleFonts.inter(
                        color: AppTheme.danger,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                _buildMiniStatusChip('Loss Trip', AppTheme.danger),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakEvenChart(List<Map<String, dynamic>> recent,
      Map<String, dynamic> comparisonContext) {
    if (recent.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue vs Break-even',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'No finalized trips are available in this period. Recent benchmark context is shown below for web reporting continuity.',
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildCompactInsight('7-day Avg Revenue',
                    'Rs. ${_asDouble(comparisonContext['average_daily_revenue']).toStringAsFixed(0)}'),
                _buildCompactInsight('7-day Avg Profit',
                    'Rs. ${_asDouble(comparisonContext['average_daily_profit']).toStringAsFixed(0)}'),
              ],
            ),
          ],
        ),
      );
    }

    // Reverse to chronological order for the chart (oldest left, newest right)
    final chartData = _buildBreakEvenRows(recent.reversed.toList());

    // Safety check max limit to avoid overcrowding x-axis
    final displayData = chartData.length > 7
        ? chartData.sublist(chartData.length - 7)
        : chartData;
    final lowDataMode = displayData.length <= 2;
    final benchmarkRevenue =
        _asDouble(comparisonContext['average_daily_revenue']);
    final insightText = _buildBreakEvenInsight(displayData);

    final maxRevenue = displayData
        .map((trip) => _asDouble(trip['actual_revenue']))
        .fold<double>(
            4000, (maxSoFar, value) => value > maxSoFar ? value : maxSoFar);
    final chartMaxY =
        ((maxRevenue > benchmarkRevenue ? maxRevenue : benchmarkRevenue) + 1500)
            .clamp(5000, 20000)
            .toDouble();

    return GlassCard(
      padding: const EdgeInsets.only(top: 20, bottom: 10, left: 16, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegendRow([
            _buildLegendDot(AppTheme.positive, 'Profit'),
            const SizedBox(width: 14),
            _buildLegendDot(AppTheme.warning, 'Near Break-even'),
            const SizedBox(width: 14),
            _buildLegendDot(AppTheme.danger, 'Loss'),
            const SizedBox(width: 14),
            _buildLegendDot(AppTheme.textMuted, 'Empty Trip'),
            const SizedBox(width: 14),
            _buildLegendDot(AppTheme.warning, 'Break-even Line'),
          ]),
          const SizedBox(height: 12),
          if (lowDataMode) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildCompactInsight('Reference Daily Revenue',
                    'Rs. ${benchmarkRevenue.toStringAsFixed(0)}'),
                _buildCompactInsight('Reference Daily Profit',
                    'Rs. ${_asDouble(comparisonContext['average_daily_profit']).toStringAsFixed(0)}'),
                _buildCompactInsight('Trips In View', '${displayData.length}'),
              ],
            ),
            const SizedBox(height: 14),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final compactWidth = (displayData.length * 130)
                  .clamp(360, constraints.maxWidth.toInt())
                  .toDouble();
              final chartWidth =
                  displayData.length <= 5 ? compactWidth : constraints.maxWidth;
              return Align(
                alignment: displayData.length <= 5
                    ? Alignment.center
                    : Alignment.centerLeft,
                child: SizedBox(
                  width: chartWidth,
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: chartMaxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => Colors.transparent,
                          tooltipPadding: EdgeInsets.zero,
                          tooltipMargin: 6,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final trip = displayData[group.x.toInt()];
                            final formatter = NumberFormat('#,###');
                            final revenue = formatter.format(rod.toY);
                            final cost = formatter.format(4000);
                            final profit = formatter.format(
                                _asDouble(trip['profit_or_loss']).round());
                            final passengers = _asInt(trip['ai_passengers']);
                            final ticketsSold = _asInt(trip['tickets_sold']);
                            return BarTooltipItem(
                              '${_breakEvenLabel(trip).replaceAll('\n', ' ')}\n'
                              'Revenue: Rs. $revenue\n'
                              'Cost: Rs. $cost\n'
                              'Profit/Loss: Rs. $profit\n'
                              'Est. Passengers: $passengers\n'
                              'Tickets Sold: $ticketsSold',
                              GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 54,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              if (value.toInt() >= displayData.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  _breakEvenLabel(displayData[value.toInt()]),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: chartMaxY > 10000 ? 4000 : 2000,
                        getDrawingHorizontalLine: (value) {
                          if (value == 4000) {
                            return FlLine(
                                color: AppTheme.warning,
                                strokeWidth: 1.5,
                                dashArray: [4, 4]);
                          }
                          return FlLine(
                              color: AppTheme.border, strokeWidth: 0.5);
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(displayData.length, (i) {
                        final val = _asDouble(displayData[i]['actual_revenue']);
                        final color = _breakEvenColor(displayData[i]);
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: val,
                              color: color,
                              width: 18,
                              borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(3),
                                  topRight: Radius.circular(3)),
                            )
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            insightText,
            style:
                GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildTripLedgerTable(List<Map<String, dynamic>> recent,
      {required double width}) {
    if (recent.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No finalized trips are available for the selected range yet.',
          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
        ),
      );
    }
    final ledgerRows = _buildLedgerRows(recent);
    final tableWidth = width >= 1100 ? width - 32 : 900.0;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppTheme.cardRadius,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppTheme.surfaceHigh,
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: _TableHeader('Date & Type')),
                      Expanded(
                          flex: 2,
                          child: _TableHeader('Pax / Tkt', center: true)),
                      Expanded(
                          flex: 2,
                          child: _TableHeader('Profit/Loss', right: true)),
                      Expanded(flex: 3, child: _TableHeader('Status')),
                    ],
                  ),
                ),
                ...ledgerRows.asMap().entries.map((e) {
                  final trip = e.value;
                  final isEq = e.key.isEven;
                  final isWarn = trip['is_warning'] == true;
                  final pnl = _asInt(trip['profit_or_loss']);
                  final pnlStr = pnl >= 0 ? '+Rs. $pnl' : '-Rs. ${pnl.abs()}';
                  final displayType = _tripDisplayType(trip);
                  final outcomeLabel = _tripOutcomeLabel(trip);
                  final riskLabel = _tripRiskLabel(trip);

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isEq
                          ? AppTheme.surfaceHigh.withOpacity(0.5)
                          : Colors.transparent,
                      border: Border(
                          bottom:
                              BorderSide(color: AppTheme.border, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(trip['date'] ?? '-',
                                  style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary,
                                      fontSize: 10)),
                              const SizedBox(height: 2),
                              Text(displayType,
                                  style: GoogleFonts.inter(
                                      color: AppTheme.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        _buildVerticalDivider(),
                        Expanded(
                          flex: 2,
                          child: Text(
                              '${trip['ai_passengers']} / ${trip['tickets_sold']}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary, fontSize: 12)),
                        ),
                        _buildVerticalDivider(),
                        Expanded(
                          flex: 2,
                          child: Text(pnlStr,
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(
                                  color: trip['is_profit']
                                      ? AppTheme.positive
                                      : AppTheme.danger,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildMiniStatusChip(
                                  outcomeLabel,
                                  trip['is_profit']
                                      ? AppTheme.positive
                                      : AppTheme.danger,
                                ),
                                if (riskLabel != null)
                                  _buildMiniStatusChip(
                                    riskLabel,
                                    riskLabel == 'High Leakage'
                                        ? AppTheme.danger
                                        : AppTheme.warning,
                                  ),
                                _buildStatusDot(isWarn),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
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
    return Text(label,
        textAlign: align,
        style: GoogleFonts.inter(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600));
  }
}

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
                letterSpacing: 0.8)),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: AppTheme.border)),
      ],
    );
  }
}
