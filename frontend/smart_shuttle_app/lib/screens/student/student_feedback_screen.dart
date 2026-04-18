import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_config.dart';
import '../../widgets/theme_toggle_button.dart';

class StudentFeedbackScreen extends StatefulWidget {
  final String tripId;
  final String? tripType;
  final String? completedAt;

  const StudentFeedbackScreen({
    super.key,
    required this.tripId,
    this.tripType,
    this.completedAt,
  });

  @override
  State<StudentFeedbackScreen> createState() => _StudentFeedbackScreenState();
}

class _StudentFeedbackScreenState extends State<StudentFeedbackScreen> {
  final _commentCtrl = TextEditingController();
  int _rating = 0;
  bool _isSaving = false;
  bool _isLoading = true;
  String? _feedbackId;
  String? _createdAt;
  String? _updatedAt;
  String? _accessDeniedMessage;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppStateProvider>();
    if ((appState.jwtToken ?? '').isEmpty ||
        appState.currentRole != UserRole.student) {
      _accessDeniedMessage =
          'Please sign in as a student to manage trip feedback.';
      _isLoading = false;
      return;
    }
    _loadExistingFeedback();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _headers() {
    final token = context.read<AppStateProvider>().jwtToken;
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadExistingFeedback() async {
    setState(() => _isLoading = true);

    try {
      final response = await http
          .get(
            Uri.parse(
                '${ApiConfig.baseUrl}/feedback?trip_id=${widget.tripId}&mine=true'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final payload = Map<String, dynamic>.from(jsonDecode(response.body));
        final items =
            List<Map<String, dynamic>>.from(payload['items'] ?? const []);
        if (items.isNotEmpty) {
          final existing = items.first;
          _feedbackId = existing['id']?.toString();
          _rating = existing['rating'] ?? 0;
          _commentCtrl.text = existing['comment']?.toString() ?? '';
          _createdAt = existing['created_at']?.toString();
          _updatedAt = existing['updated_at']?.toString();
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load your existing trip feedback.',
            style: GoogleFonts.inter(color: AppTheme.onAccent),
          ),
          backgroundColor: AppTheme.warning,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveFeedback() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a rating between 1 and 5 stars.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<AppStateProvider>();
    final isCreating = _feedbackId == null;

    try {
      late http.Response response;
      if (isCreating) {
        response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/feedback'),
          headers: _headers(),
          body: jsonEncode(
            {
              'trip_id': widget.tripId,
              'student_id': provider.userId,
              'rating': _rating,
              'comment': _commentCtrl.text.trim(),
            },
          ),
        );
      } else {
        response = await http.put(
          Uri.parse('${ApiConfig.baseUrl}/feedback/$_feedbackId'),
          headers: _headers(),
          body: jsonEncode(
            {
              'rating': _rating,
              'comment': _commentCtrl.text.trim(),
            },
          ),
        );
      }

      if (!mounted) return;

      if (response.statusCode == 200) {
        await _loadExistingFeedback();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCreating
                  ? 'Feedback submitted successfully.'
                  : 'Feedback updated successfully.',
              style: GoogleFonts.inter(color: AppTheme.onAccent),
            ),
            backgroundColor: AppTheme.positive,
          ),
        );
      } else {
        final payload = Map<String, dynamic>.from(jsonDecode(response.body));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              payload['detail']?.toString() ?? 'Unable to save feedback.',
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
            'Failed to reach the server while saving feedback.',
            style: GoogleFonts.inter(color: AppTheme.onAccent),
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteFeedback() async {
    if (_feedbackId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        title: Text(
          'Delete Feedback',
          style: GoogleFonts.inter(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This removes your feedback for the latest completed trip. You can submit it again while this trip remains eligible.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/feedback/$_feedbackId'),
        headers: _headers(),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _feedbackId = null;
          _rating = 0;
          _commentCtrl.clear();
          _createdAt = null;
          _updatedAt = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Feedback deleted successfully.',
              style: GoogleFonts.inter(color: AppTheme.onAccent),
            ),
            backgroundColor: AppTheme.positive,
          ),
        );
      } else {
        final payload = Map<String, dynamic>.from(jsonDecode(response.body));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              payload['detail']?.toString() ?? 'Unable to delete feedback.',
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
            'Failed to reach the server while deleting feedback.',
            style: GoogleFonts.inter(color: AppTheme.onAccent),
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatTimestamp(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) return 'Not yet saved';
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
              'Rate your most recent completed trip',
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
      body: SafeArea(
        child: _accessDeniedMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      _accessDeniedMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              )
            : _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppTheme.accent))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: AppTheme.accent.withOpacity(0.22)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.tripType ?? 'Completed Trip',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Rate your latest shuttle experience',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Trip ID: ${widget.tripId}',
                                    style: GoogleFonts.inter(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12),
                                  ),
                                  if ((widget.completedAt ?? '')
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Completed: ${_formatTimestamp(widget.completedAt)}',
                                      style: GoogleFonts.inter(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    _feedbackId == null
                                        ? 'No feedback submitted yet for this trip.'
                                        : 'Created: ${_formatTimestamp(_createdAt)}\nLast updated: ${_formatTimestamp(_updatedAt)}',
                                    style: GoogleFonts.inter(
                                        color: AppTheme.textMuted,
                                        fontSize: 11,
                                        height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rating',
                                    style: GoogleFonts.inter(
                                        color: AppTheme.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final iconSize =
                                          constraints.maxWidth < 360
                                              ? 34.0
                                              : 40.0;

                                      return Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: List.generate(
                                          5,
                                          (index) => IconButton(
                                            iconSize: iconSize,
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(6),
                                            icon: Icon(
                                              index < _rating
                                                  ? Icons.star_rounded
                                                  : Icons.star_outline_rounded,
                                              color: index < _rating
                                                  ? AppTheme.warning
                                                  : AppTheme.borderStrong,
                                            ),
                                            onPressed: _isSaving
                                                ? null
                                                : () => setState(
                                                      () => _rating = index + 1,
                                                    ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  Text(
                                    _rating == 0
                                        ? 'Tap a star to select a rating.'
                                        : 'Selected rating: $_rating / 5',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Comment (Optional)',
                                    style: GoogleFonts.inter(
                                        color: AppTheme.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _commentCtrl,
                                    maxLines: 5,
                                    style: GoogleFonts.inter(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Share timing, comfort, safety, or service quality notes',
                                      hintStyle: GoogleFonts.inter(
                                          color: AppTheme.textMuted),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveFeedback,
                                child: _isSaving
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            color: AppTheme.onAccent,
                                            strokeWidth: 2),
                                      )
                                    : Text(
                                        _feedbackId == null
                                            ? 'Submit Feedback'
                                            : 'Update Feedback',
                                        style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15),
                                      ),
                              ),
                            ),
                            if (_feedbackId != null) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: _isSaving ? null : _deleteFeedback,
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 18),
                                  label: Text(
                                    'Delete Feedback',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.danger,
                                    side: BorderSide(color: AppTheme.danger),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}
