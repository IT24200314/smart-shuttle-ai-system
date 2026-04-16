import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_config.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/theme_toggle_button.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  final _tripIdCtrl = TextEditingController();
  Map<String, dynamic>? _feedbackPayload;
  bool _isLoading = true;
  String? _error;
  int? _ratingMin;
  int? _ratingMax;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  @override
  void dispose() {
    _tripIdCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _headers() {
    final token = context.read<AppStateProvider>().jwtToken;
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _buildFeedbackUri() {
    final queryParameters = <String, String>{};
    if (_tripIdCtrl.text.trim().isNotEmpty) {
      queryParameters['trip_id'] = _tripIdCtrl.text.trim();
    }
    if (_ratingMin != null) {
      queryParameters['rating_min'] = _ratingMin.toString();
    }
    if (_ratingMax != null) {
      queryParameters['rating_max'] = _ratingMax.toString();
    }
    if (_startDate != null) {
      queryParameters['start_date'] =
          DateFormat('yyyy-MM-dd').format(_startDate!);
    }
    if (_endDate != null) {
      queryParameters['end_date'] = DateFormat('yyyy-MM-dd').format(_endDate!);
    }
    return Uri.parse('${ApiConfig.baseUrl}/feedback')
        .replace(queryParameters: queryParameters);
  }

  Future<void> _loadFeedback() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final appState = context.read<AppStateProvider>();
    if ((appState.jwtToken ?? '').isEmpty ||
        appState.currentRole != UserRole.admin) {
      setState(() {
        _isLoading = false;
        _error = 'Please sign in as an admin to view trip feedback.';
      });
      return;
    }

    try {
      final response = await http
          .get(
            _buildFeedbackUri(),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _feedbackPayload =
              Map<String, dynamic>.from(jsonDecode(response.body));
        });
      } else {
        final payload = Map<String, dynamic>.from(jsonDecode(response.body));
        setState(() {
          _error = payload['detail']?.toString() ?? 'Failed to load feedback.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to connect to the feedback API.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initialDate =
        isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.accent,
                  surface: AppTheme.surface,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  void _resetFilters() {
    setState(() {
      _tripIdCtrl.clear();
      _ratingMin = null;
      _ratingMax = null;
      _startDate = null;
      _endDate = null;
    });
    _loadFeedback();
  }

  String _formatDate(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) return '--';
    try {
      return DateFormat('MMM d, yyyy  h:mm a')
          .format(DateTime.parse(rawValue).toLocal());
    } catch (_) {
      return rawValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider to rebuild on theme toggle
    context.watch<AppStateProvider>();
    final items =
        List<Map<String, dynamic>>.from(_feedbackPayload?['items'] ?? const []);
    final averageRating = (_feedbackPayload?['average_rating'] ?? 0).toDouble();
    final totalFeedback = (_feedbackPayload?['total_feedback'] ?? 0) as int;
    final lowRatings = items.where((item) => (item['rating'] ?? 0) <= 2).length;

    final groupedByTrip = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final tripId = item['trip_id']?.toString() ?? 'Unknown Trip';
      groupedByTrip.putIfAbsent(tripId, () => []).add(item);
    }

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
            Text(
              'Trip Feedback',
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            Text(
              'Ratings, trends, and low-score review signals',
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary, fontSize: 11),
            ),
          ],
        ),
        actions: const [
          ThemeToggleButton(compact: true),
          SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFeedback,
        color: AppTheme.accent,
        backgroundColor: AppTheme.surfaceHigh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassCard(
                      fillColor: AppTheme.accent.withOpacity(0.07),
                      borderColor: AppTheme.accent.withOpacity(0.22),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Feedback Intelligence',
                            style: GoogleFonts.inter(
                              color: AppTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Analyze rating quality by trip, isolate low-score issues, and monitor rider sentiment trends in one workspace.',
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
                    _buildFilters(),
                    const SizedBox(height: 20),
                    if (_isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Center(
                          child:
                              CircularProgressIndicator(color: AppTheme.accent),
                        ),
                      )
                    else if (_error != null)
                      GlassCard(
                        fillColor: AppTheme.danger.withOpacity(0.12),
                        borderColor: AppTheme.danger.withOpacity(0.28),
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(color: AppTheme.textPrimary),
                        ),
                      )
                    else ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 900;
                          final cards = [
                            _MetricCard(
                              label: 'Average Rating',
                              value: averageRating.toStringAsFixed(2),
                              accent: AppTheme.warning,
                              suffixIcon: Icons.star_rounded,
                            ),
                            _MetricCard(
                              label: 'Total Reviews',
                              value: '$totalFeedback',
                              accent: AppTheme.accent,
                              suffixIcon: Icons.reviews_rounded,
                            ),
                            _MetricCard(
                              label: 'Low Ratings',
                              value: '$lowRatings',
                              accent: AppTheme.warning,
                              suffixIcon: Icons.flag_rounded,
                            ),
                          ];

                          if (!isWide) {
                            return Column(
                              children: cards
                                  .map((card) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: card,
                                      ))
                                  .toList(),
                            );
                          }

                          return Row(
                            children: [
                              for (var i = 0; i < cards.length; i++) ...[
                                Expanded(child: cards[i]),
                                if (i != cards.length - 1)
                                  const SizedBox(width: 12),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 1040;
                          final tripBreakdown =
                              _TripBreakdown(groupedByTrip: groupedByTrip);
                          final latestComments = _LatestComments(
                            items: items,
                            formatDate: _formatDate,
                          );

                          if (!isWide) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                tripBreakdown,
                                const SizedBox(height: 28),
                                latestComments,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: tripBreakdown),
                              const SizedBox(width: 18),
                              Expanded(flex: 4, child: latestComments),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Filters',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800),
              ),
              Text(
                'Apply quick segments for faster issue discovery',
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _tripIdCtrl,
                  style: GoogleFonts.inter(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Trip ID',
                    prefixIcon: Icon(Icons.directions_bus_filled_rounded),
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<int?>(
                  initialValue: _ratingMin,
                  dropdownColor: AppTheme.surfaceHigh,
                  decoration: const InputDecoration(
                    labelText: 'Min Rating',
                    prefixIcon: Icon(Icons.star_outline_rounded),
                  ),
                  items: const [
                    DropdownMenuItem<int?>(value: null, child: Text('Any')),
                    DropdownMenuItem<int?>(value: 1, child: Text('1+')),
                    DropdownMenuItem<int?>(value: 2, child: Text('2+')),
                    DropdownMenuItem<int?>(value: 3, child: Text('3+')),
                    DropdownMenuItem<int?>(value: 4, child: Text('4+')),
                    DropdownMenuItem<int?>(value: 5, child: Text('5')),
                  ],
                  onChanged: (value) => setState(() => _ratingMin = value),
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<int?>(
                  initialValue: _ratingMax,
                  dropdownColor: AppTheme.surfaceHigh,
                  decoration: const InputDecoration(
                    labelText: 'Max Rating',
                    prefixIcon: Icon(Icons.star_half_rounded),
                  ),
                  items: const [
                    DropdownMenuItem<int?>(value: null, child: Text('Any')),
                    DropdownMenuItem<int?>(value: 1, child: Text('1')),
                    DropdownMenuItem<int?>(value: 2, child: Text('2')),
                    DropdownMenuItem<int?>(value: 3, child: Text('3')),
                    DropdownMenuItem<int?>(value: 4, child: Text('4')),
                    DropdownMenuItem<int?>(value: 5, child: Text('5')),
                  ],
                  onChanged: (value) => setState(() => _ratingMax = value),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(true),
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(
                  _startDate == null
                      ? 'Start Date'
                      : DateFormat('MMM d, yyyy').format(_startDate!),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(false),
                icon: const Icon(Icons.event_available_rounded, size: 16),
                label: Text(
                  _endDate == null
                      ? 'End Date'
                      : DateFormat('MMM d, yyyy').format(_endDate!),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _loadFeedback,
                icon: const Icon(Icons.filter_alt_rounded, size: 18),
                label: const Text('Apply Filters'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _resetFilters,
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TripBreakdown extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> groupedByTrip;

  const _TripBreakdown({required this.groupedByTrip});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trip Breakdown',
          style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (groupedByTrip.isEmpty)
          GlassCard(
            child: Text(
              'No feedback records matched the current filters.',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: groupedByTrip.entries.map((entry) {
              final tripItems = entry.value;
              final tripAverage = tripItems.fold<double>(
                    0,
                    (sum, item) =>
                        sum + ((item['rating'] ?? 0) as num).toDouble(),
                  ) /
                  tripItems.length;
              final first = tripItems.first;
              return SizedBox(
                width: 260,
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${first['trip_type'] ?? 'Trip'}  •  ${tripItems.length} review(s)',
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                               color: AppTheme.warning, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            tripAverage.toStringAsFixed(2),
                            style: GoogleFonts.inter(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _LatestComments extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String Function(String?) formatDate;

  const _LatestComments({
    required this.items,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Latest Comments',
          style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          GlassCard(
            child: Text(
              'There are no comments for the current filter set.',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
          )
        else
          for (final feedback in items)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (feedback['rating'] ?? 0) <= 2
                    ? AppTheme.danger.withOpacity(0.08)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (feedback['rating'] ?? 0) <= 2
                      ? AppTheme.danger.withOpacity(0.28)
                      : AppTheme.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (feedback['rating'] ?? 0) <= 2
                              ? AppTheme.danger
                              : AppTheme.warning,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${feedback['rating'] ?? 0}',
                              style: GoogleFonts.inter(
                                  color: AppTheme.onAccent,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.star_rounded,
                                color: AppTheme.onAccent, size: 14),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feedback['student_name']?.toString().isNotEmpty ==
                                      true
                                  ? feedback['student_name'].toString()
                                  : feedback['student_id']?.toString() ??
                                      'Student',
                              style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${feedback['trip_type'] ?? 'Trip'} • ${feedback['trip_id'] ?? ''}',
                              style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatDate(feedback['updated_at']?.toString() ??
                            feedback['created_at']?.toString()),
                        style: GoogleFonts.inter(
                            color: AppTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    feedback['comment']?.toString().trim().isNotEmpty == true
                        ? feedback['comment'].toString()
                        : 'No comment provided for this rating.',
                    style: GoogleFonts.inter(
                      color:
                          feedback['comment']?.toString().trim().isNotEmpty ==
                                  true
                              ? AppTheme.textPrimary
                              : AppTheme.textMuted,
                      fontStyle:
                          feedback['comment']?.toString().trim().isNotEmpty ==
                                  true
                              ? FontStyle.normal
                              : FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final IconData suffixIcon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
              Icon(suffixIcon, color: accent, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
