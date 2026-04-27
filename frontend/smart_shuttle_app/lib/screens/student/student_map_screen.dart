import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js' as js; // Needed for map availability check on web
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../providers/app_state_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/crowd_density_badge.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../utils/api_config.dart';
import 'student_lost_found_screen.dart';
import 'student_feedback_screen.dart';

class StudentMapScreen extends StatefulWidget {
  const StudentMapScreen({super.key});

  @override
  State<StudentMapScreen> createState() => _StudentMapScreenState();
}

class _StudentMapScreenState extends State<StudentMapScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  final Completer<GoogleMapController> _mapController = Completer();
  bool _autoCenterOnBus = false;

  // -- Map Stability States --
  bool _isMapAvailable = false;
  bool _isMapChecking = true;
  String? _mapInitError;

  Timer? _pollTimer;
  StreamSubscription<Position>? _positionStream;

  // Student's real-time position
  LatLng? _userPos;

  // Bus position from backend (SLIIT Kandy location approx as default)
  LatLng _busPos = const LatLng(7.2801, 80.7020);

  String _busId = 'NB-2341';
  int _currentSpeed = 0;
  String _stopStatus = 'En route';
  String? _feedbackTripId;
  String? _feedbackTripType;
  String? _feedbackTripEndedAt;
  List<_FeedbackTrip> _recentFeedbackTrips = const [];

  String _selectedRoute = 'Route A — Main Gate';
  final List<String> _routes = [
    'Route A — Main Gate',
    'Route B — Faculty Block',
    'Route C — Hostel Block',
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _startUserLocationTracking();
    _startPolling();
    _verifyMapAvailability();
  }

  /// Checks if the Google Maps library is actually loaded (critical for Web)
  Future<void> _verifyMapAvailability() async {
    if (!kIsWeb) {
      if (mounted) {
        setState(() {
          _isMapAvailable = true;
          _isMapChecking = false;
        });
      }
      return;
    }

    // Give JS a moment to initialize
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // Check if 'google' and 'google.maps' exist in the JS context
      final googleExists = js.context.hasProperty('google');
      if (googleExists) {
        final google = js.context['google'];
        final mapsExists = google != null && google.hasProperty('maps');

        if (mapsExists) {
          if (mounted) {
            setState(() {
              _isMapAvailable = true;
              _isMapChecking = false;
            });
          }
          return;
        }
      }
      throw 'Google Maps JS SDK not found. Check your API key and connection.';
    } catch (e) {
      debugPrint('Map verification failed: $e');
      if (mounted) {
        setState(() {
          _isMapAvailable = false;
          _isMapChecking = false;
          _mapInitError = e.toString();
        });
      }
    }
  }

  Future<void> _retryMapInit() async {
    setState(() {
      _isMapChecking = true;
      _mapInitError = null;
    });
    await _verifyMapAvailability();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _refreshStudentData();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (t) => _refreshStudentData(),
    );
  }

  Future<void> _refreshStudentData() async {
    await _fetchLiveLocation();
    await _fetchFeedbackEligibility();
    if (_autoCenterOnBus) {
      _centerOnBus();
    }
  }

  Future<void> _fetchLiveLocation() async {
    try {
      final res = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/map/live-location'))
          .timeout(const Duration(seconds: 2));

      if (res.statusCode == 200 && mounted) {
        final data = Map<String, dynamic>.from(json.decode(res.body));
        setState(() {
          // Backend sends raw coords in lat_percent/lng_percent
          double lat = (data['lat_percent'] ?? 7.2801).toDouble();
          double lng = (data['lng_percent'] ?? 80.7020).toDouble();
          _busPos = LatLng(lat, lng);
          _busId = data['bus_id'] ?? 'NB-2341';
          _currentSpeed = data['speed'] ?? 0;
          _stopStatus = data['status'] ?? 'Active';

          if (data['eta_min'] != null) {
            context.read<AppStateProvider>().setEta(data['eta_min']);
          }
        });
        _updateMarkers();
      }
    } catch (_) {}
  }

  Future<void> _fetchFeedbackEligibility() async {
    final appState = context.read<AppStateProvider>();
    final token = appState.jwtToken;
    if (token == null ||
        token.isEmpty ||
        appState.currentRole != UserRole.student) {
      if (!mounted) return;
      setState(() {
        _feedbackTripId = null;
        _feedbackTripType = null;
        _feedbackTripEndedAt = null;
        _recentFeedbackTrips = const [];
      });
      return;
    }

    try {
      final tripsRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/feedback/eligible-trips?limit=8'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 6));

      final feedbackRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/feedback?mine=true'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 6));

      if (!mounted) return;

      if (tripsRes.statusCode == 200) {
        final tripsPayload =
            Map<String, dynamic>.from(json.decode(tripsRes.body));
        final submittedTripIds = <String>{};
        if (feedbackRes.statusCode == 200) {
          final feedbackPayload =
              Map<String, dynamic>.from(json.decode(feedbackRes.body));
          for (final item
              in List<dynamic>.from(feedbackPayload['items'] ?? const [])) {
            final feedback = Map<String, dynamic>.from(item as Map);
            final tripId = feedback['trip_id']?.toString();
            if (tripId != null && tripId.isNotEmpty) {
              submittedTripIds.add(tripId);
            }
          }
        }

        final trips = List<dynamic>.from(tripsPayload['items'] ?? const [])
            .map((item) => _FeedbackTrip.fromJson(
                  Map<String, dynamic>.from(item as Map),
                  submittedTripIds: submittedTripIds,
                ))
            .toList();
        final latest = trips.isNotEmpty ? trips.first : null;
        setState(() {
          _recentFeedbackTrips = trips;
          _feedbackTripId = latest?.tripId;
          _feedbackTripType = latest?.tripType;
          _feedbackTripEndedAt = latest?.completedAt;
        });
      } else {
        setState(() {
          _recentFeedbackTrips = const [];
          _feedbackTripId = null;
          _feedbackTripType = null;
          _feedbackTripEndedAt = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recentFeedbackTrips = const [];
        _feedbackTripId = null;
        _feedbackTripType = null;
        _feedbackTripEndedAt = null;
      });
    }
  }

  Future<void> _startUserLocationTracking() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _userPos = LatLng(position.latitude, position.longitude);
      });
      _updateMarkers();

      _positionStream?.cancel();
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(() {
          _userPos = LatLng(pos.latitude, pos.longitude);
        });
        _updateMarkers();
      });
    } catch (_) {}
  }

  Future<void> _centerOnBus() async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _busPos, zoom: 16.5),
      ),
    );
  }

  Set<Marker> _markers = {};
  void _updateMarkers() {
    final markers = <Marker>{};

    // Bus marker
    markers.add(
      Marker(
        markerId: const MarkerId('bus_marker'),
        position: _busPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Shuttle Bus',
          snippet: 'Speed: $_currentSpeed km/h',
        ),
      ),
    );

    // User marker
    if (_userPos != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_marker'),
          position: _userPos!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'You'),
        ),
      );
    }
    setState(() {
      _markers = markers;
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _openFeedback([_FeedbackTrip? trip]) async {
    final targetTrip = trip ??
        (_feedbackTripId == null
            ? null
            : _FeedbackTrip(
                tripId: _feedbackTripId!,
                tripType: _feedbackTripType,
                completedAt: _feedbackTripEndedAt,
              ));

    if (targetTrip == null || targetTrip.tripId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Feedback is available after trip completion.',
            style: GoogleFonts.inter(color: AppTheme.onAccent),
          ),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    if (targetTrip.feedbackSubmitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Feedback submitted for this trip.',
            style: GoogleFonts.inter(color: AppTheme.onAccent),
          ),
          backgroundColor: AppTheme.positive,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentFeedbackScreen(
          tripId: targetTrip.tripId,
          tripType: targetTrip.tripType,
          completedAt: targetTrip.completedAt,
        ),
      ),
    );
    if (mounted) {
      await _fetchFeedbackEligibility();
    }
  }

  void _openLostFound() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StudentLostFoundScreen()),
    );
  }

  Widget _buildMapLayer() {
    if (_isMapChecking) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Initializing Map...',
                style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    if (!_isMapAvailable || _mapInitError != null) {
      return Container(
        color: AppTheme.background,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, color: AppTheme.danger, size: 48),
            const SizedBox(height: 16),
            Text(
              'Map Connection Issue',
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _mapInitError ?? 'The map could not be loaded on this device.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _retryMapInit,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry Initialization'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent.withOpacity(0.1),
                foregroundColor: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() => _isMapAvailable = true); // Risky force-try
              },
              child: Text('Force Load (Developer Mode)',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppTheme.textMuted)),
            ),
          ],
        ),
      );
    }

    try {
      return GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: CameraPosition(
          target: _busPos,
          zoom: 15.0,
        ),
        markers: _markers,
        onMapCreated: (GoogleMapController controller) {
          if (!_mapController.isCompleted) {
            _mapController.complete(controller);
          }
          _updateMarkers();
        },
        myLocationEnabled: true,
      );
    } catch (e) {
      return Center(
        child: Text('Error rendering map: $e',
            style: GoogleFonts.inter(color: AppTheme.danger)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppStateProvider>();
    final provider = context.watch<AppStateProvider>();
    final media = MediaQuery.of(context).size;
    final maxSheetHeight = media.height * (media.width < 700 ? 0.62 : 0.54);

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
            Text('Live Bus Tracker',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text('Student View',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          const ThemeToggleButton(compact: true),
          IconButton(
            tooltip: _autoCenterOnBus ? 'Auto-center ON' : 'Auto-center OFF',
            icon: Icon(
              _autoCenterOnBus
                  ? Icons.my_location_rounded
                  : Icons.location_searching_rounded,
              color:
                  _autoCenterOnBus ? AppTheme.accent : AppTheme.textSecondary,
              size: 20,
            ),
            onPressed: () {
              setState(() => _autoCenterOnBus = !_autoCenterOnBus);
              if (_autoCenterOnBus) {
                _centerOnBus();
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: AppTheme.textSecondary, size: 20),
            onPressed: _refreshStudentData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────
          Positioned.fill(
            bottom: maxSheetHeight - 20, // Space for Bottom Sheet
            child: _buildMapLayer(),
          ),

          // ── Bottom Info Sheet ───────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomSheet(
              provider: provider,
              selectedRoute: _selectedRoute,
              routes: _routes,
              onRouteChanged: (r) => setState(() => _selectedRoute = r!),
              busId: _busId,
              currentSpeed: _currentSpeed,
              stopStatus: _stopStatus,
              feedbackTripId: _feedbackTripId,
              feedbackTripType: _feedbackTripType,
              recentFeedbackTrips: _recentFeedbackTrips,
              onOpenFeedback: _openFeedback,
              onOpenLostFound: _openLostFound,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackTrip {
  final String tripId;
  final String? tripType;
  final String? completedAt;
  final bool feedbackSubmitted;

  const _FeedbackTrip({
    required this.tripId,
    this.tripType,
    this.completedAt,
    this.feedbackSubmitted = false,
  });

  factory _FeedbackTrip.fromJson(
    Map<String, dynamic> json, {
    required Set<String> submittedTripIds,
  }) {
    final tripId = json['trip_id']?.toString() ?? '';
    return _FeedbackTrip(
      tripId: tripId,
      tripType: json['trip_type']?.toString(),
      completedAt: json['actual_end_time']?.toString(),
      feedbackSubmitted: submittedTripIds.contains(tripId),
    );
  }
}

// ── Bottom Sheet ──────────────────────────────────────────────
class _BottomSheet extends StatelessWidget {
  final AppStateProvider provider;
  final String selectedRoute;
  final List<String> routes;
  final ValueChanged<String?> onRouteChanged;
  final String busId;
  final int currentSpeed;
  final String stopStatus;
  final String? feedbackTripId;
  final String? feedbackTripType;
  final List<_FeedbackTrip> recentFeedbackTrips;
  final Future<void> Function([_FeedbackTrip? trip]) onOpenFeedback;
  final VoidCallback onOpenLostFound;

  const _BottomSheet({
    required this.provider,
    required this.selectedRoute,
    required this.routes,
    required this.onRouteChanged,
    required this.busId,
    required this.currentSpeed,
    required this.stopStatus,
    required this.feedbackTripId,
    required this.feedbackTripType,
    required this.recentFeedbackTrips,
    required this.onOpenFeedback,
    required this.onOpenLostFound,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final maxSheetHeight = media.height * (media.width < 700 ? 0.62 : 0.54);

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedRoute,
                dropdownColor: AppTheme.surfaceHigh,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.route_rounded,
                      color: AppTheme.positive, size: 17),
                  labelText: 'Route',
                ),
                items: routes
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(
                            r,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: GoogleFonts.inter(
                                color: AppTheme.textPrimary, fontSize: 13),
                          ),
                        ))
                    .toList(),
                onChanged: onRouteChanged,
              ),
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stackStats = constraints.maxWidth < 360;

                    final etaBlock = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Estimated Arrival',
                            style: GoogleFonts.inter(
                                color: AppTheme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${provider.etaMinutes}',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                )),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text('min',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('to Main Gate stop',
                            style: GoogleFonts.inter(
                                color: AppTheme.textMuted, fontSize: 11)),
                      ],
                    );
                    final crowdBlock = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Crowd',
                            style: GoogleFonts.inter(
                                color: AppTheme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 8),
                        CrowdDensityBadge(density: provider.crowdDensity),
                      ],
                    );

                    if (stackStats) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          etaBlock,
                          const SizedBox(height: 14),
                          crowdBlock,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: etaBlock),
                        const SizedBox(width: 10),
                        crowdBlock,
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                        icon: Icons.confirmation_number_rounded,
                        label: 'Bus',
                        value: busId),
                    _InfoChip(
                        icon: Icons.speed_rounded,
                        label: 'Speed',
                        value: '$currentSpeed km/h'),
                    _InfoChip(
                        icon: Icons.location_on_rounded,
                        label: 'Status',
                        value: stopStatus),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 420;
                  final feedbackButton = ElevatedButton.icon(
                    onPressed: () => onOpenFeedback(),
                    icon: const Icon(Icons.rate_review_rounded, size: 18),
                    label: Text(
                      feedbackTripId == null
                          ? 'Feedback Unavailable'
                          : 'Rate Latest Trip',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: feedbackTripId == null
                          ? AppTheme.surfaceHigh
                          : AppTheme.accent,
                      foregroundColor: feedbackTripId == null
                          ? AppTheme.textSecondary
                          : AppTheme.onAccent,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  );

                  final lostFoundButton = OutlinedButton.icon(
                    onPressed: onOpenLostFound,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(
                      'Lost & Found',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  );

                  if (!isWide) {
                    return Column(
                      children: [
                        SizedBox(width: double.infinity, child: feedbackButton),
                        const SizedBox(height: 8),
                        SizedBox(
                            width: double.infinity, child: lostFoundButton),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: feedbackButton),
                      const SizedBox(width: 8),
                      Expanded(child: lostFoundButton),
                    ],
                  );
                },
              ),
              if (recentFeedbackTrips.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recent Completed Trips',
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...recentFeedbackTrips.map(
                  (trip) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RecentTripFeedbackTile(
                      trip: trip,
                      onTap: () => onOpenFeedback(trip),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                feedbackTripId == null
                    ? 'Feedback is available after trip completion.'
                    : 'Choose any completed trip above to submit feedback.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTripFeedbackTile extends StatelessWidget {
  final _FeedbackTrip trip;
  final VoidCallback onTap;

  const _RecentTripFeedbackTile({
    required this.trip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: AppTheme.chipRadius,
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(
            trip.feedbackSubmitted
                ? Icons.check_circle_rounded
                : Icons.rate_review_rounded,
            color: trip.feedbackSubmitted ? AppTheme.positive : AppTheme.accent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.tripType ?? 'Completed Trip',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Trip ID: ${trip.tripId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: trip.feedbackSubmitted ? null : onTap,
            child: Text(
              trip.feedbackSubmitted ? 'Submitted' : 'Feedback',
              style:
                  GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: AppTheme.chipRadius,
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.positive, size: 14),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
