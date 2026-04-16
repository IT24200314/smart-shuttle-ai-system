// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'glass_card.dart';

class DriverCameraPanel extends StatefulWidget {
  final bool sessionLive;
  final String aiState;

  const DriverCameraPanel({
    super.key,
    required this.sessionLive,
    required this.aiState,
  });

  @override
  State<DriverCameraPanel> createState() => _DriverCameraPanelState();
}

class _DriverCameraPanelState extends State<DriverCameraPanel> {
  static int _instanceCounter = 0;

  late final String _viewType;
  html.VideoElement? _videoElement;
  bool _isRequesting = false;
  bool _isStreaming = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _viewType = 'driver-camera-feed-${_instanceCounter++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..controls = false
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.border = '0'
        ..setAttribute('playsinline', 'true');
      _videoElement = video;
      return video;
    });

    if (widget.sessionLive) {
      unawaited(_startCamera());
    }
  }

  @override
  void didUpdateWidget(covariant DriverCameraPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessionLive && !oldWidget.sessionLive) {
      unawaited(_startCamera());
    } else if (!widget.sessionLive && oldWidget.sessionLive) {
      _stopCamera();
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    }
  }

  Future<void> _startCamera() async {
    if (_isRequesting || _isStreaming) return;

    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      setState(() {
        _errorMessage =
            'Browser camera access is unavailable in this environment.';
      });
      return;
    }

    setState(() {
      _isRequesting = true;
      _errorMessage = null;
    });

    try {
      final stream = await mediaDevices.getUserMedia({
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
        'audio': false,
      });

      if (!mounted) {
        _stopTracks(stream);
        return;
      }

      _videoElement?.srcObject = stream;
      final playFuture = _videoElement?.play();
      if (playFuture != null) {
        await playFuture;
      }

      if (!mounted) return;
      setState(() {
        _isStreaming = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isStreaming = false;
        _errorMessage =
            'Camera preview unavailable. Check browser permission or close any app already using the camera.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }

  void _stopTracks(html.MediaStream stream) {
    for (final track in stream.getTracks()) {
      track.stop();
    }
  }

  void _stopCamera() {
    final currentStream = _videoElement?.srcObject;
    if (currentStream is html.MediaStream) {
      _stopTracks(currentStream);
    }
    if (_videoElement != null) {
      _videoElement!.srcObject = null;
    }
    _isStreaming = false;
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _isStreaming
        ? AppTheme.positive
        : widget.sessionLive
            ? AppTheme.warning
            : AppTheme.textMuted;
    final statusLabel = _isStreaming
        ? 'Live'
        : widget.sessionLive
            ? 'Permission needed'
            : 'Idle';
    final helperText = _isStreaming
        ? 'Live driver camera feed is active for the current session.'
        : widget.sessionLive
            ? 'This panel requests browser camera access when a driver session starts.'
            : 'Start Session to initialize the driver camera preview.';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryAccent.withOpacity(
                    AppTheme.isDarkMode ? 0.16 : 0.12,
                  ),
                  borderRadius: AppTheme.chipRadius,
                ),
                child: Icon(
                  Icons.videocam_rounded,
                  color: AppTheme.secondaryAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Driver Camera Feed',
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
            height: 248,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: AppTheme.cardRadius,
              border: Border.all(color: AppTheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildPreviewSurface(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSurface() {
    if (!widget.sessionLive) {
      return _CameraFallbackSurface(
        icon: Icons.video_call_outlined,
        title: 'Driver camera is standing by.',
        message:
            'Start Session to request camera access and display the live feed here.',
        tone: AppTheme.textMuted,
      );
    }

    if (_isStreaming) {
      return Stack(
        fit: StackFit.expand,
        children: [
          HtmlElementView(viewType: _viewType),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: AppTheme.cardRadius,
              ),
              child: Text(
                'LIVE',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_isRequesting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: AppTheme.secondaryAccent,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Requesting camera access...',
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return _CameraFallbackSurface(
      icon: Icons.videocam_off_rounded,
      title: 'Live preview is unavailable.',
      message: _errorMessage ??
          'Camera access did not start. Check browser permission and device availability.',
      tone: AppTheme.warning,
    );
  }
}

class _CameraFallbackSurface extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color tone;

  const _CameraFallbackSurface({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: tone, size: 34),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
