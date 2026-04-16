import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_config.dart';
import '../../widgets/alert_card.dart';
import '../../widgets/driver_camera_panel.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/theme_toggle_button.dart';
import '../auth/login_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const String _busId = 'NB-2341';

  Timer? _timer;
  late final AnimationController _btnCtrl;
  late final Animation<double> _btnScale;

  String? _activeTripId;
  String? _activeTripType;
  String _aiState = 'idle';
  bool _aiPreviewEnabled = false;
  String? _aiModelPath;
  String? _aiVideoPath;
  int _estimatedPassengerCount = 0;
  int _estimatedPassengerCountLive = 0;
  int _finalEstimatedPassengerCount = 0;
  int _currentDetectedCount = 0;
  int _peakVisibleCount = 0;

  @override
  void initState() {
    super.initState();
    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
    _btnScale = _btnCtrl;

    _fetchSafetyScore();
    _fetchLiveTelemetry();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final provider = context.read<AppStateProvider>();
      if (!provider.sessionActive ||
          _aiState == 'stopped' ||
          _aiState == 'completed' ||
          _aiState == 'failed') {
        return;
      }

      provider.tickSecond();
      if (provider.tripDurationSeconds % 2 == 0) {
        _fetchSafetyScore();
        _fetchLiveTelemetry();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _btnCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSafetyScore() async {
    try {
      final provider = context.read<AppStateProvider>();
      final driverEmail = Uri.encodeComponent(
        provider.userEmail ?? 'driver@shuttle.lk',
      );
      final res = await http
          .get(Uri.parse(
              '${ApiConfig.baseUrl}/driver/safety-score/$driverEmail'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode != 200 || !mounted) return;

      final data = json.decode(res.body);
      provider
          .setSafetyScore((data['safety_score'] as num?)?.toDouble() ?? 100);
      provider.syncCounts(
        (data['number_of_ywan'] as num?)?.toInt() ?? 0,
        (data['number_of_usephone'] as num?)?.toInt() ?? 0,
        (data['number_of_drowsiness'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {}
  }

  Future<void> _fetchLiveTelemetry() async {
    try {
      final res = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/map/live-location/$_busId'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode != 200 || !mounted) return;

      final data = json.decode(res.body);
      final aiState = data['ai_state']?.toString() ?? 'idle';
      final estimatedLive =
          (data['estimated_passenger_count_live'] as num?)?.toInt() ??
              (data['estimated_passenger_count'] as num?)?.toInt() ??
              (data['passenger_count'] as num?)?.toInt() ??
              0;
      final finalEstimated =
          (data['final_estimated_passenger_count'] as num?)?.toInt() ??
              (data['estimated_passenger_count'] as num?)?.toInt() ??
              estimatedLive;
      final effectiveEstimated = (aiState == 'stopped' ||
              aiState == 'completed' ||
              aiState == 'failed')
          ? finalEstimated
          : estimatedLive;
      setState(() {
        _activeTripId = data['trip_id']?.toString();
        _activeTripType = data['trip_type']?.toString() ?? _activeTripType;
        _aiState = aiState;
        _estimatedPassengerCountLive = estimatedLive;
        _finalEstimatedPassengerCount = finalEstimated;
        _estimatedPassengerCount = effectiveEstimated;
        _currentDetectedCount =
            (data['current_detected_count'] as num?)?.toInt() ?? 0;
        _peakVisibleCount = (data['peak_visible_count'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _handleSessionToggle() async {
    final provider = context.read<AppStateProvider>();
    if (!provider.sessionActive) {
      final tripType = await _showStartDialog();
      if (tripType == null) return;

      try {
        final res = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/driver/start-trip'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'bus_id': _busId,
            'trip_type': tripType,
            'driver_id': provider.userEmail ?? 'driver@shuttle.lk',
          }),
        );

        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          setState(() {
            _activeTripType = tripType;
            _activeTripId = data['trip_id']?.toString();
            _aiState =
                data['ai_session']?['ai_state']?.toString() ?? 'starting';
            _aiPreviewEnabled = data['ai_session']?['preview_enabled'] == true;
            _aiModelPath = data['ai_session']?['model_path']?.toString();
            _aiVideoPath = data['ai_session']?['video_path']?.toString();
            _estimatedPassengerCount = 0;
            _estimatedPassengerCountLive = 0;
            _finalEstimatedPassengerCount = 0;
            _currentDetectedCount = 0;
            _peakVisibleCount = 0;
          });
          provider.toggleSession();
          _showSuccess(
              'Passenger preview started and the driver camera panel is ready.');
          _fetchLiveTelemetry();
        } else {
          _showError(
              _detailFromResponse(res, 'Unable to start the AI session.'));
        }
      } catch (_) {
        _showError('Server connection failed while starting the session.');
      }
      return;
    }

    try {
      final stopRes = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/driver/stop-session'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'bus_id': _busId}),
      );
      if (stopRes.statusCode != 200) {
        _showError(
            _detailFromResponse(stopRes, 'Unable to stop the AI session.'));
        return;
      }

      final stopData = json.decode(stopRes.body);
      final stopAiState = stopData['ai_state']?.toString() ?? 'stopped';
      final stopLiveEstimate =
          (stopData['estimated_passenger_count_live'] as num?)?.toInt() ??
              (stopData['estimated_passenger_count'] as num?)?.toInt() ??
              (stopData['passenger_count'] as num?)?.toInt() ??
              _estimatedPassengerCountLive;
      final stopFinalEstimate =
          (stopData['final_estimated_passenger_count'] as num?)?.toInt() ??
              (stopData['estimated_passenger_count'] as num?)?.toInt() ??
              (stopData['passenger_count'] as num?)?.toInt() ??
              _finalEstimatedPassengerCount;
      final stopEffectiveEstimate = (stopAiState == 'stopped' ||
              stopAiState == 'completed' ||
              stopAiState == 'failed')
          ? stopFinalEstimate
          : stopLiveEstimate;
      setState(() {
        _activeTripId = stopData['trip_id']?.toString() ?? _activeTripId;
        _activeTripType = stopData['trip_type']?.toString() ?? _activeTripType;
        _aiState = stopAiState;
        _aiPreviewEnabled = false;
        _estimatedPassengerCountLive = stopLiveEstimate;
        _finalEstimatedPassengerCount = stopFinalEstimate;
        _estimatedPassengerCount = stopEffectiveEstimate;
        _currentDetectedCount = 0;
        _peakVisibleCount = (stopData['peak_visible_count'] as num?)?.toInt() ??
            _peakVisibleCount;
      });
    } catch (_) {
      _showError('Failed to stop the AI session.');
      return;
    }

    final counts = await _showEndDialog();
    if (counts == null) {
      _showSuccess('AI stopped. Finalize the trip when you are ready.');
      return;
    }

    try {
      final endRes = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/driver/end-trip'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'bus_id': _busId,
          'trip_type': _activeTripType ?? 'Morning',
          'tickets_75': counts['75'] ?? 0,
          'tickets_100': counts['100'] ?? 0,
          'tickets_150': counts['150'] ?? 0,
          'tickets_200': counts['200'] ?? 0,
        }),
      );
      if (endRes.statusCode == 200) {
        provider.toggleSession();
        setState(() {
          _activeTripId = null;
          _activeTripType = null;
          _aiState = 'idle';
          _aiPreviewEnabled = false;
          _aiModelPath = null;
          _aiVideoPath = null;
          _estimatedPassengerCount = 0;
          _estimatedPassengerCountLive = 0;
          _finalEstimatedPassengerCount = 0;
          _currentDetectedCount = 0;
          _peakVisibleCount = 0;
        });
        _showSuccess('Trip data synced to the revenue engine.');
        _fetchLiveTelemetry();
      } else {
        _showError(_detailFromResponse(endRes, 'Failed to finalize the trip.'));
      }
    } catch (_) {
      _showError('Failed to finalize the trip.');
    }
  }

  Future<String?> _showStartDialog() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        title: Text('Start New Trip',
            style: GoogleFonts.inter(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Morning', 'Evening', 'Special']
              .map(
                (tripType) => ListTile(
                  title: Text(tripType,
                      style: GoogleFonts.inter(color: AppTheme.textPrimary)),
                  onTap: () => Navigator.pop(ctx, tripType),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<Map<String, int>?> _showEndDialog() async {
    final c75 = TextEditingController(text: '0');
    final c100 = TextEditingController(text: '0');
    final c150 = TextEditingController(text: '0');
    final c200 = TextEditingController(text: '0');

    return showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        title: Text('Finalize Tickets',
            style: GoogleFonts.inter(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TicketField(label: '75 LKR Tickets', controller: c75),
            _TicketField(label: '100 LKR Tickets', controller: c100),
            _TicketField(label: '150 LKR Tickets', controller: c150),
            _TicketField(label: '200 LKR Tickets', controller: c200),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, {
              '75': int.tryParse(c75.text) ?? 0,
              '100': int.tryParse(c100.text) ?? 0,
              '150': int.tryParse(c150.text) ?? 0,
              '200': int.tryParse(c200.text) ?? 0,
            }),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  String _detailFromResponse(http.Response response, String fallback) {
    try {
      final payload = json.decode(response.body);
      if (payload is Map<String, dynamic>) {
        return payload['detail']?.toString() ??
            payload['message']?.toString() ??
            fallback;
      }
    } catch (_) {}
    return fallback;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.danger),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.positive),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        title: Text('Logout',
            style: GoogleFonts.inter(color: AppTheme.textPrimary)),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.read<AppStateProvider>().clearSession();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  String _fmt(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color _scoreColor(double score) {
    if (score >= 85) return AppTheme.positive;
    if (score >= 60) return AppTheme.warning;
    return AppTheme.danger;
  }

  bool _isMonitorLive(AppStateProvider provider) {
    return provider.sessionActive &&
        _aiState != 'stopped' &&
        _aiState != 'completed' &&
        _aiState != 'failed' &&
        _aiState != 'idle';
  }

  String _shortPath(String? value) {
    if (value == null || value.isEmpty) return '--';
    final normalized = value.replaceAll('\\', '/');
    final segments = normalized
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    return segments.isEmpty ? value : segments.last;
  }

  Widget _buildSessionMonitor(AppStateProvider provider) {
    final sessionLive = _isMonitorLive(provider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final splitView = constraints.maxWidth >= 980;
        final passengerPanel = _PassengerPreviewPanel(
          sessionLive: sessionLive,
          previewEnabled: _aiPreviewEnabled,
          aiState: _aiState,
          estimatedPassengerCount: _estimatedPassengerCount,
          estimatedPassengerCountLive: _estimatedPassengerCountLive,
          finalEstimatedPassengerCount: _finalEstimatedPassengerCount,
          currentDetectedCount: _currentDetectedCount,
          peakVisibleCount: _peakVisibleCount,
          sessionDurationLabel: _fmt(provider.tripDurationSeconds),
          modelLabel: _shortPath(_aiModelPath),
          videoLabel: _shortPath(_aiVideoPath),
        );
        final cameraPanel = DriverCameraPanel(
          sessionLive: sessionLive,
          aiState: _aiState,
        );

        if (splitView) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: passengerPanel),
              const SizedBox(width: 16),
              Expanded(child: cameraPanel),
            ],
          );
        }

        return Column(
          children: [
            passengerPanel,
            const SizedBox(height: 16),
            cameraPanel,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider to rebuild on theme toggle
    context.watch<AppStateProvider>();
    final provider = context.watch<AppStateProvider>();
    final sessionRunning = _isMonitorLive(provider);
    final sessionFinalizing = provider.sessionActive &&
        !sessionRunning &&
        (_aiState == 'stopped' || _aiState == 'completed');
    final sessionTone = sessionRunning
        ? AppTheme.positive
        : sessionFinalizing
            ? AppTheme.warning
            : AppTheme.textMuted;
    final sessionTitle = sessionRunning
        ? 'Session Active'
        : sessionFinalizing
            ? 'Session Ready To Finalize'
            : 'Session Idle';
    final sessionBadge = sessionRunning
        ? 'RUNNING'
        : sessionFinalizing
            ? 'FINALIZE'
            : 'READY';
    final sessionSummary = sessionRunning
        ? 'Passenger preview and driver camera are currently running.'
        : sessionFinalizing
            ? 'Passenger preview has stopped. Finalize the trip when you are ready.'
            : 'Start Session to begin passenger preview and camera monitoring.';

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
            Text('Driver Dashboard',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text('AI Safety Dashboard',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          _DutyBadge(active: provider.sessionActive),
          const ThemeToggleButton(compact: true),
          IconButton(
            tooltip: 'Logout',
            icon: Icon(Icons.power_settings_new_rounded,
                color: AppTheme.danger, size: 22),
            onPressed: _logout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTapDown: (_) => _btnCtrl.reverse(),
                  onTapUp: (_) {
                    _btnCtrl.forward();
                    _handleSessionToggle();
                  },
                  onTapCancel: () => _btnCtrl.forward(),
                  child: AnimatedBuilder(
                    animation: _btnScale,
                    builder: (_, child) =>
                        Transform.scale(scale: _btnScale.value, child: child),
                    child: _SessionButton(
                      isActive: provider.sessionActive,
                      aiState: _aiState,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GlassCard(
                  fillColor: sessionRunning
                      ? AppTheme.positiveDim.withOpacity(
                          AppTheme.isDarkMode ? 0.34 : 0.92,
                        )
                      : sessionFinalizing
                          ? AppTheme.warningDim.withOpacity(
                              AppTheme.isDarkMode ? 0.26 : 0.96,
                            )
                          : null,
                  borderColor: sessionRunning
                      ? AppTheme.positive.withOpacity(
                          AppTheme.isDarkMode ? 0.34 : 0.20,
                        )
                      : sessionFinalizing
                          ? AppTheme.warning.withOpacity(
                              AppTheme.isDarkMode ? 0.30 : 0.20,
                            )
                          : null,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: sessionTone.withOpacity(
                            AppTheme.isDarkMode ? 0.16 : 0.12,
                          ),
                          borderRadius: AppTheme.chipRadius,
                        ),
                        child: Icon(
                          sessionRunning
                              ? Icons.check_circle_rounded
                              : sessionFinalizing
                                  ? Icons.assignment_turned_in_rounded
                                  : Icons.pause_circle_outline_rounded,
                          color: sessionTone,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    sessionTitle,
                                    style: GoogleFonts.inter(
                                      color: sessionRunning || sessionFinalizing
                                          ? AppTheme.textPrimary
                                          : AppTheme.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sessionTone.withOpacity(
                                      AppTheme.isDarkMode ? 0.16 : 0.12,
                                    ),
                                    borderRadius: AppTheme.cardRadius,
                                  ),
                                  child: Text(
                                    sessionBadge,
                                    style: GoogleFonts.inter(
                                      color: sessionTone,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sessionSummary,
                              style: GoogleFonts.inter(
                                color: AppTheme.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'AI Status: ${_aiState.toUpperCase()}'
                              '${_activeTripId != null ? '  | Trip: $_activeTripId' : ''}'
                              '${_activeTripType != null ? '  | Type: $_activeTripType' : ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionLabel('Session Monitor'),
                const SizedBox(height: 12),
                _buildSessionMonitor(provider),
                const SizedBox(height: 20),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety Score',
                        style: GoogleFonts.inter(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          SizedBox(
                            width: 86,
                            height: 86,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: provider.safetyScore / 100,
                                  strokeWidth: 7,
                                  backgroundColor: AppTheme.border,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _scoreColor(provider.safetyScore),
                                  ),
                                  strokeCap: StrokeCap.round,
                                ),
                                Text(
                                  provider.safetyScore.toStringAsFixed(0),
                                  style: GoogleFonts.inter(
                                    color: _scoreColor(provider.safetyScore),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.safetyScore >= 85
                                      ? 'Excellent - Keep it up!'
                                      : provider.safetyScore >= 60
                                          ? 'Caution - Check alerts'
                                          : 'Poor - Needs attention',
                                  style: GoogleFonts.inter(
                                    color: _scoreColor(provider.safetyScore),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _DeductRow('Yawn detection', '-1 pts',
                                    AppTheme.warning),
                                const SizedBox(height: 4),
                                _DeductRow('Phone use event', '-2 pts',
                                    AppTheme.warning),
                                const SizedBox(height: 4),
                                _DeductRow('Drowsiness detection', '-5 pts',
                                    AppTheme.danger),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionLabel('AI Safety Monitoring'),
                const SizedBox(height: 12),
                AlertCard(
                  icon: Icons.sentiment_very_satisfied_rounded,
                  title: 'Yawn Detected',
                  subtitle: 'AI monitors mouth opening',
                  isActive: provider.yawnAlert,
                  alertColor: AppTheme.warning,
                  onSimulate: provider.sessionActive
                      ? () => context
                          .read<AppStateProvider>()
                          .triggerYawn(!provider.yawnAlert)
                      : null,
                ),
                const SizedBox(height: 10),
                AlertCard(
                  icon: Icons.phone_android_rounded,
                  title: 'Phone Use Detected',
                  subtitle: 'Vision model: handheld device detection',
                  isActive: provider.phoneUseAlert,
                  alertColor: AppTheme.warning,
                  onSimulate: provider.sessionActive
                      ? () => context
                          .read<AppStateProvider>()
                          .triggerPhoneUse(!provider.phoneUseAlert)
                      : null,
                ),
                const SizedBox(height: 10),
                AlertCard(
                  icon: Icons.remove_red_eye_rounded,
                  title: 'Drowsiness Detected',
                  subtitle: 'AI monitors eye closure and head position',
                  isActive: provider.drowsinessAlert,
                  alertColor: AppTheme.danger,
                  onSimulate: provider.sessionActive
                      ? () => context
                          .read<AppStateProvider>()
                          .triggerDrowsiness(!provider.drowsinessAlert)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PassengerPreviewPanel extends StatelessWidget {
  final bool sessionLive;
  final bool previewEnabled;
  final String aiState;
  final int estimatedPassengerCount;
  final int estimatedPassengerCountLive;
  final int finalEstimatedPassengerCount;
  final int currentDetectedCount;
  final int peakVisibleCount;
  final String sessionDurationLabel;
  final String modelLabel;
  final String videoLabel;

  const _PassengerPreviewPanel({
    required this.sessionLive,
    required this.previewEnabled,
    required this.aiState,
    required this.estimatedPassengerCount,
    required this.estimatedPassengerCountLive,
    required this.finalEstimatedPassengerCount,
    required this.currentDetectedCount,
    required this.peakVisibleCount,
    required this.sessionDurationLabel,
    required this.modelLabel,
    required this.videoLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isPaused = aiState == 'stopped' || aiState == 'completed';
    final statusColor = sessionLive
        ? (previewEnabled ? AppTheme.positive : AppTheme.accent)
        : isPaused
            ? AppTheme.warning
            : AppTheme.textMuted;
    final statusLabel = sessionLive
        ? (previewEnabled ? 'Live' : 'Tracking')
        : isPaused
            ? 'Paused'
            : 'Idle';
    final helperText = sessionLive
        ? previewEnabled
            ? 'Passenger counting preview is live for the active trip.'
            : 'Passenger counting is active in background mode for the active trip.'
        : isPaused
            ? 'Passenger counting has stopped, and final trip values remain available below.'
            : 'Start Session to activate passenger counting preview.';
    final hasSessionData = sessionLive || aiState != 'idle';
    final showModel = modelLabel != '--';
    final showVideo = videoLabel != '--';

    return GlassCard(
      fillColor: AppTheme.accent.withOpacity(0.05),
      borderColor: AppTheme.accent.withOpacity(0.20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(
                    AppTheme.isDarkMode ? 0.16 : 0.12,
                  ),
                  borderRadius: AppTheme.chipRadius,
                ),
                child: Icon(
                  Icons.groups_rounded,
                  color: AppTheme.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Passenger Count Preview',
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      helperText,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(
                    AppTheme.isDarkMode ? 0.14 : 0.10,
                  ),
                  borderRadius: AppTheme.cardRadius,
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: AppTheme.cardRadius,
              border: Border.all(color: AppTheme.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 460;
                final totalBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasSessionData ? '$estimatedPassengerCount' : '--',
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.3,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Estimated passenger count',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Live: $estimatedPassengerCountLive   |   Final: $finalEstimatedPassengerCount',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
                final telemetryBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PreviewMetric(
                      label: 'Current visible',
                      value: '$currentDetectedCount',
                    ),
                    const SizedBox(height: 10),
                    _PreviewMetric(
                      label: 'Peak visible',
                      value: '$peakVisibleCount',
                    ),
                    const SizedBox(height: 10),
                    _PreviewMetric(
                      label: 'Preview mode',
                      value: previewEnabled ? 'Enabled' : 'Background',
                    ),
                  ],
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      totalBlock,
                      const SizedBox(height: 14),
                      telemetryBlock,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: totalBlock),
                    const SizedBox(width: 18),
                    SizedBox(width: 170, child: telemetryBlock),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.timer_rounded,
                  label: 'Session Duration',
                  value: sessionDurationLabel,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.visibility_rounded,
                  label: 'Visible Now',
                  value: '$currentDetectedCount',
                  color: AppTheme.positive,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.bar_chart_rounded,
                  label: 'Peak Visible',
                  value: '$peakVisibleCount',
                  color: AppTheme.warning,
                ),
              ),
            ],
          ),
          if (showModel || showVideo) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (showModel)
                  _InfoPill(
                    icon: Icons.memory_rounded,
                    label: 'Model',
                    value: modelLabel,
                  ),
                if (showVideo)
                  _InfoPill(
                    icon: Icons.movie_creation_outlined,
                    label: 'Preview source',
                    value: videoLabel,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppTheme.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.accent, size: 15),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionButton extends StatelessWidget {
  final bool isActive;
  final String aiState;

  const _SessionButton({required this.isActive, required this.aiState});

  @override
  Widget build(BuildContext context) {
    final isRunning = isActive &&
        aiState != 'stopped' &&
        aiState != 'completed' &&
        aiState != 'failed';
    final isFinalizing =
        isActive && (aiState == 'stopped' || aiState == 'completed');
    final tone = isRunning
        ? AppTheme.positive
        : isFinalizing
            ? AppTheme.warning
            : AppTheme.positive;
    final title = !isActive
        ? 'Start Session'
        : isRunning
            ? 'Session Active'
            : 'Finalize Session';
    final subtitle = !isActive
        ? 'Tap to begin AI monitoring'
        : isRunning
            ? 'Passenger preview and driver camera are live. Tap to stop when the trip ends.'
            : 'AI stopped. Tap again to finalize tickets and close the trip.';
    final badge = !isActive
        ? 'READY'
        : isRunning
            ? 'ACTIVE'
            : 'FINALIZE';
    final leadingIcon = !isActive
        ? Icons.play_circle_rounded
        : isRunning
            ? Icons.check_circle_rounded
            : Icons.assignment_turned_in_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        borderRadius: AppTheme.cardRadius,
        color: tone.withOpacity(isRunning ? 0.12 : 0.08),
        border: Border.all(color: tone.withOpacity(0.5), width: 1.5),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: tone.withOpacity(
                    AppTheme.isDarkMode ? 0.18 : 0.10,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tone.withOpacity(AppTheme.isDarkMode ? 0.16 : 0.12),
                borderRadius: AppTheme.cardRadius,
              ),
              child: Icon(leadingIcon, color: tone, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: tone,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tone.withOpacity(AppTheme.isDarkMode ? 0.16 : 0.12),
                borderRadius: AppTheme.cardRadius,
                border: Border.all(
                  color: tone.withOpacity(AppTheme.isDarkMode ? 0.24 : 0.18),
                ),
              ),
              child: Text(
                badge,
                style: GoogleFonts.inter(
                  color: tone,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DutyBadge extends StatelessWidget {
  final bool active;

  const _DutyBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.positive : AppTheme.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: AppTheme.chipRadius,
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(active ? 'ON DUTY' : 'OFF DUTY',
          style: GoogleFonts.inter(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}

class _DeductRow extends StatelessWidget {
  final String label;
  final String points;
  final Color color;

  const _DeductRow(this.label, this.points, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary, fontSize: 11)),
        ),
        Text(points,
            style: GoogleFonts.inter(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _TicketField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _TicketField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: GoogleFonts.inter(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: AppTheme.textSecondary),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.border)),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel(this.title);

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
        Expanded(child: Divider(color: AppTheme.border)),
      ],
    );
  }
}
