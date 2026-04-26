import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../../providers/app_state_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_config.dart';
import '../../widgets/alert_card.dart';
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
  String _driverMonitorState = 'ready';
  int _estimatedPassengerCount = 0;
  int _estimatedPassengerCountLive = 0;
  int _finalEstimatedPassengerCount = 0;
  int _currentDetectedCount = 0;
  int _peakVisibleCount = 0;
  int _yawnCount = 0;
  int _phoneUseCount = 0;
  int _drowsinessCount = 0;
  bool _driverBehaviorSessionActive = false;
  bool _driverCameraActive = false;
  bool _sessionToggleInFlight = false;
  String? _driverCameraError;
  String? _latestBehaviorType;
  String? _latestBehaviorLabel;
  String? _latestBehaviorAt;
  StreamSubscription<Position>? _gpsSubscription;

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
      if (!provider.sessionActive) return;

      provider.tickSecond();
      if (provider.tripDurationSeconds % 3 == 0) {
        _fetchSafetyScore();
        _fetchLiveTelemetry();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gpsSubscription?.cancel();
    _btnCtrl.dispose();
    super.dispose();
  }

  void _manageGpsTracking(bool active) async {
    if (active) {
      _gpsSubscription?.cancel();

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      _gpsSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        _updateGpsOnBackend(pos);
      });
    } else {
      _gpsSubscription?.cancel();
      _gpsSubscription = null;
    }
  }

  Future<void> _updateGpsOnBackend(Position pos) async {
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/gps/update-location'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'bus_id': _busId,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'speed': (pos.speed * 3.6).round(), // m/s to km/h
        }),
      );
    } catch (_) {}
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
      final yawnCount = (data['number_of_yawn'] as num?)?.toInt() ?? 0;
      final phoneCount = (data['number_of_usephone'] as num?)?.toInt() ?? 0;
      final drowsinessCount =
          (data['number_of_drowsiness'] as num?)?.toInt() ?? 0;
      provider
          .setSafetyScore((data['safety_score'] as num?)?.toDouble() ?? 100);
      provider.syncCounts(
        yawnCount,
        phoneCount,
        drowsinessCount,
      );
      setState(() {
        _yawnCount = yawnCount;
        _phoneUseCount = phoneCount;
        _drowsinessCount = drowsinessCount;
        _driverBehaviorSessionActive = data['session_active'] == true;
        _driverCameraActive = data['camera_active'] == true;
        _driverMonitorState = data['monitor_state']?.toString() ?? 'ready';
        _driverCameraError = data['camera_error']?.toString();
        _latestBehaviorType = data['latest_event_type']?.toString();
        _latestBehaviorLabel = data['latest_event_label']?.toString();
        _latestBehaviorAt = data['latest_event_at']?.toString();
      });
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
    if (_sessionToggleInFlight) return;

    final provider = context.read<AppStateProvider>();
    setState(() => _sessionToggleInFlight = true);

    try {
      if (!provider.sessionActive) {
        final tripType = await _showStartDialog();
        if (tripType == null) return;

        final res = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/driver/start-trip'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'bus_id': _busId,
            'trip_type': tripType,
            'driver_id': provider.userId ?? 'driver-01',
            'driver_email': provider.userEmail ?? 'driver@shuttle.lk',
          }),
        );

        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final passengerSession =
              data['passenger_counting_session'] as Map<String, dynamic>? ??
                  data['ai_session'] as Map<String, dynamic>?;
          final behaviorSession =
              data['driver_behavior_session'] as Map<String, dynamic>?;
          if (!mounted) return;
          setState(() {
            _activeTripType = tripType;
            _activeTripId = data['trip_id']?.toString();
            _aiState = passengerSession?['ai_state']?.toString() ?? 'starting';
            _estimatedPassengerCount = 0;
            _estimatedPassengerCountLive = 0;
            _finalEstimatedPassengerCount = 0;
            _currentDetectedCount = 0;
            _peakVisibleCount = 0;
            _driverBehaviorSessionActive = true;
            _driverMonitorState =
                behaviorSession?['monitor_state']?.toString() ?? 'starting';
            _driverCameraActive = behaviorSession?['camera_active'] == true;
            _driverCameraError = null;
            _latestBehaviorType = null;
            _latestBehaviorLabel = null;
            _latestBehaviorAt = null;
          });
          provider.beginDriverSession();
          _manageGpsTracking(true);
          _showSuccess(
            'Passenger counting preview and driver behavior monitoring are now active.',
          );
          _fetchLiveTelemetry();
          _fetchSafetyScore();
        } else {
          _showError(
              _detailFromResponse(res, 'Unable to start the AI session.'));
        }
        return;
      }

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
      final behaviorStop =
          stopData['driver_behavior_session'] as Map<String, dynamic>?;
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
      if (!mounted) return;
      setState(() {
        _activeTripId = stopData['trip_id']?.toString() ?? _activeTripId;
        _activeTripType = stopData['trip_type']?.toString() ?? _activeTripType;
        _aiState = stopAiState;
        _estimatedPassengerCountLive = stopLiveEstimate;
        _finalEstimatedPassengerCount = stopFinalEstimate;
        _estimatedPassengerCount = stopEffectiveEstimate;
        _currentDetectedCount = 0;
        _peakVisibleCount = (stopData['peak_visible_count'] as num?)?.toInt() ??
            _peakVisibleCount;
        _driverBehaviorSessionActive = false;
        _driverMonitorState =
            behaviorStop?['monitor_state']?.toString() ?? 'stopped';
        _driverCameraActive = behaviorStop?['camera_active'] == true;
      });

      final counts = await _showEndDialog();
      if (counts == null) {
        _showSuccess('AI stopped. Finalize the trip when you are ready.');
        return;
      }

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
        if (!mounted) return;
        provider.endDriverSession();
        _manageGpsTracking(false);
        setState(() {
          _activeTripId = null;
          _activeTripType = null;
          _aiState = 'idle';
          _estimatedPassengerCount = 0;
          _estimatedPassengerCountLive = 0;
          _finalEstimatedPassengerCount = 0;
          _currentDetectedCount = 0;
          _peakVisibleCount = 0;
          _driverBehaviorSessionActive = false;
          _driverCameraActive = false;
          _driverMonitorState = 'stopped';
          _driverCameraError = null;
          _latestBehaviorType = null;
          _latestBehaviorLabel = null;
          _latestBehaviorAt = null;
        });
        _showSuccess('Trip data synced to the revenue engine.');
        _fetchLiveTelemetry();
        _fetchSafetyScore();
      } else {
        _showError(_detailFromResponse(endRes, 'Failed to finalize the trip.'));
      }
    } catch (_) {
      _showError(
        provider.sessionActive
            ? 'Failed to sync the session with the backend.'
            : 'Server connection failed while starting the session.',
      );
    } finally {
      if (mounted) {
        setState(() => _sessionToggleInFlight = false);
      }
    }
  }

  Future<String?> _showStartDialog() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        title: Text('Start New Trip',
            style: GoogleFonts.inter(color: AppTheme.textPrimary)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ['Morning', 'Evening', 'Special']
                  .map(
                    (tripType) => ListTile(
                      title: Text(
                        tripType,
                        style: GoogleFonts.inter(color: AppTheme.textPrimary),
                      ),
                      onTap: () => Navigator.pop(ctx, tripType),
                    ),
                  )
                  .toList(),
            ),
          ),
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
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TicketField(label: '75 LKR Tickets', controller: c75),
                _TicketField(label: '100 LKR Tickets', controller: c100),
                _TicketField(label: '150 LKR Tickets', controller: c150),
                _TicketField(label: '200 LKR Tickets', controller: c200),
              ],
            ),
          ),
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

  Color _aiStateColor() {
    switch (_aiState) {
      case 'processing':
      case 'starting':
        return AppTheme.positive;
      case 'stopped':
      case 'completed':
        return AppTheme.warning;
      case 'failed':
        return AppTheme.danger;
      default:
        return AppTheme.textMuted;
    }
  }

  Color _driverMonitorColor() {
    switch (_driverMonitorState) {
      case 'monitoring':
      case 'starting':
      case 'camera_opening':
        return AppTheme.positive;
      case 'camera_unavailable':
        return AppTheme.warning;
      case 'failed':
        return AppTheme.danger;
      case 'stopped':
      case 'standby':
        return AppTheme.textMuted;
      default:
        return AppTheme.textMuted;
    }
  }

  Color _latestBehaviorColor() {
    switch (_latestBehaviorType) {
      case 'drowsiness':
        return AppTheme.danger;
      case 'usephone':
      case 'yawn':
        return AppTheme.warning;
      default:
        return AppTheme.accent;
    }
  }

  IconData _latestBehaviorIcon() {
    switch (_latestBehaviorType) {
      case 'drowsiness':
        return Icons.remove_red_eye_rounded;
      case 'usephone':
        return Icons.phone_android_rounded;
      case 'yawn':
        return Icons.sentiment_very_satisfied_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  String _driverMonitorLabel() {
    switch (_driverMonitorState) {
      case 'camera_opening':
        return 'Camera Opening';
      case 'camera_unavailable':
        return 'Camera Unavailable';
      default:
        return _driverMonitorState.replaceAll('_', ' ').toUpperCase();
    }
  }

  String? _formattedLatestBehaviorTime() {
    if (_latestBehaviorAt == null || _latestBehaviorAt!.isEmpty) return null;
    final parsed = DateTime.tryParse(_latestBehaviorAt!);
    if (parsed == null) return _latestBehaviorAt;
    final hh = parsed.hour.toString().padLeft(2, '0');
    final mm = parsed.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider to rebuild on theme toggle
    context.watch<AppStateProvider>();
    final provider = context.watch<AppStateProvider>();
    final latestBehaviorTime = _formattedLatestBehaviorTime();

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 900 ? 24.0 : 16.0;

          return SingleChildScrollView(
            padding: EdgeInsets.all(horizontalPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    IgnorePointer(
                      ignoring: _sessionToggleInFlight,
                      child: AnimatedOpacity(
                        opacity: _sessionToggleInFlight ? 0.72 : 1,
                        duration: const Duration(milliseconds: 180),
                        child: GestureDetector(
                          onTapDown: (_) => _btnCtrl.reverse(),
                          onTapUp: (_) {
                            _btnCtrl.forward();
                            _handleSessionToggle();
                          },
                          onTapCancel: () => _btnCtrl.forward(),
                          child: AnimatedBuilder(
                            animation: _btnScale,
                            builder: (_, child) => Transform.scale(
                                scale: _btnScale.value, child: child),
                            child: _SessionButton(
                              isActive: provider.sessionActive,
                              aiState: _aiState,
                              isBusy: _sessionToggleInFlight,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.smart_display_rounded,
                                  color: _aiStateColor(), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Passenger AI: ${_aiState.toUpperCase()}'
                                  '${_activeTripId != null ? '  | Trip: $_activeTripId' : ''}'
                                  '${_activeTripType != null ? '  | Type: $_activeTripType' : ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.videocam_rounded,
                                color: _driverMonitorColor(),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Driver Monitor: ${_driverMonitorLabel()}'
                                  '  | Camera: ${_driverCameraActive ? 'LIVE' : _driverBehaviorSessionActive ? 'INITIALIZING' : 'STANDBY'}'
                                  '  | Session: ${provider.sessionActive ? 'ACTIVE' : 'INACTIVE'}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_latestBehaviorLabel != null &&
                              _latestBehaviorLabel!.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  constraints:
                                      const BoxConstraints(maxWidth: 360),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _latestBehaviorColor()
                                        .withValues(alpha: 0.12),
                                    borderRadius: AppTheme.chipRadius,
                                    border: Border.all(
                                      color: _latestBehaviorColor()
                                          .withValues(alpha: 0.34),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _latestBehaviorIcon(),
                                        color: _latestBehaviorColor(),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Live Alert: $_latestBehaviorLabel',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            color: _latestBehaviorColor(),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (latestBehaviorTime != null)
                                  Text(
                                    'Updated $latestBehaviorTime',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (_sessionToggleInFlight) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Syncing session state across passenger preview and driver monitor...',
                              style: GoogleFonts.inter(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (_driverCameraError != null &&
                              _driverCameraError!.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _driverCameraError!,
                              style: GoogleFonts.inter(
                                color: AppTheme.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassCard(
                      fillColor: AppTheme.accent.withValues(alpha: 0.06),
                      borderColor: AppTheme.accent.withValues(alpha: 0.22),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      _aiStateColor().withValues(alpha: 0.12),
                                  borderRadius: AppTheme.chipRadius,
                                ),
                                child: Icon(Icons.groups_rounded,
                                    color: _aiStateColor(), size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Estimated Passenger Count',
                                      style: GoogleFonts.inter(
                                        color: AppTheme.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Final trip count is locked from stable tracked visibility, not a single crossing event.',
                                      style: GoogleFonts.inter(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compactCount = constraints.maxWidth < 420;
                              final countLabel = Text(
                                'Estimated Passenger Count',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                              final countValue = Text(
                                provider.sessionActive || _aiState != 'idle'
                                    ? '$_estimatedPassengerCount'
                                    : '--',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.4,
                                  height: 1,
                                ),
                              );

                              if (compactCount) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    countValue,
                                    const SizedBox(height: 8),
                                    countLabel,
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  countValue,
                                  const SizedBox(width: 10),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 5),
                                    child: countLabel,
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compactBreakdown =
                                  constraints.maxWidth < 360;
                              final liveText = Text(
                                'Live: $_estimatedPassengerCountLive',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                              final finalText = Text(
                                'Final: $_finalEstimatedPassengerCount',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              );

                              if (compactBreakdown) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    liveText,
                                    const SizedBox(height: 4),
                                    finalText,
                                  ],
                                );
                              }

                              return Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                children: [
                                  liveText,
                                  finalText,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _ResponsiveTileRow(
                            children: [
                              _StatTile(
                                icon: Icons.timer_rounded,
                                label: 'Session Duration',
                                value: _fmt(provider.tripDurationSeconds),
                                color: AppTheme.accent,
                              ),
                              _StatTile(
                                icon: Icons.visibility_rounded,
                                label: 'Visible Now',
                                value: '$_currentDetectedCount',
                                color: AppTheme.positive,
                              ),
                              _StatTile(
                                icon: Icons.bar_chart_rounded,
                                label: 'Peak Visible',
                                value: '$_peakVisibleCount',
                                color: AppTheme.warning,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Safety Score',
                              style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final scoreDial = SizedBox(
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
                                        color:
                                            _scoreColor(provider.safetyScore),
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              final scoreDetails = Column(
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
                                  _DeductRow(
                                    'Drowsiness detection',
                                    '-5 pts',
                                    AppTheme.danger,
                                  ),
                                ],
                              );

                              if (constraints.maxWidth < 520) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    scoreDial,
                                    const SizedBox(height: 16),
                                    scoreDetails,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  scoreDial,
                                  const SizedBox(width: 18),
                                  Expanded(child: scoreDetails),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _ResponsiveTileRow(
                            children: [
                              _StatTile(
                                icon: Icons.sentiment_very_satisfied_rounded,
                                label: 'Yawns',
                                value: '$_yawnCount',
                                color: AppTheme.warning,
                              ),
                              _StatTile(
                                icon: Icons.phone_android_rounded,
                                label: 'Phone Use',
                                value: '$_phoneUseCount',
                                color: AppTheme.warning,
                              ),
                              _StatTile(
                                icon: Icons.remove_red_eye_rounded,
                                label: 'Drowsiness',
                                value: '$_drowsinessCount',
                                color: AppTheme.danger,
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
          );
        },
      ),
    );
  }
}

class _SessionButton extends StatelessWidget {
  final bool isActive;
  final String aiState;
  final bool isBusy;

  const _SessionButton({
    required this.isActive,
    required this.aiState,
    required this.isBusy,
  });

  @override
  Widget build(BuildContext context) {
    final waitingForFinalize =
        isActive && (aiState == 'stopped' || aiState == 'completed');
    final color = isBusy
        ? AppTheme.accent
        : isActive
            ? AppTheme.danger
            : AppTheme.positive;
    final title = isBusy
        ? isActive
            ? 'Syncing Session...'
            : 'Starting Session...'
        : !isActive
            ? 'Start Session'
            : waitingForFinalize
                ? 'Finalize Trip'
                : 'Stop Session';
    final subtitle = isBusy
        ? 'Please wait while the backend updates both AI systems'
        : !isActive
            ? 'Tap to begin passenger preview and driver monitoring'
            : waitingForFinalize
                ? 'AI stopped - tap again to finalize tickets'
                : 'Tap to end the session and stop passenger counting plus driver monitoring';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        borderRadius: AppTheme.cardRadius,
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 540;
            final leading = isBusy
                ? SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : Icon(
                    !isActive
                        ? Icons.play_circle_rounded
                        : waitingForFinalize
                            ? Icons.assignment_turned_in_rounded
                            : Icons.stop_circle_rounded,
                    color: color,
                    size: 36,
                  );
            final content = Column(
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            );

            if (compact) {
              return Column(
                children: [
                  leading,
                  const SizedBox(height: 12),
                  content,
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                leading,
                const SizedBox(width: 14),
                Flexible(child: content),
              ],
            );
          },
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
        color: color.withValues(alpha: 0.10),
        borderRadius: AppTheme.chipRadius,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(active ? 'ON DUTY' : 'OFF DUTY',
          style: GoogleFonts.inter(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _ResponsiveTileRow extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveTileRow({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;

        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: spacing),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: spacing),
            ],
          ],
        );
      },
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
              maxLines: 2,
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
