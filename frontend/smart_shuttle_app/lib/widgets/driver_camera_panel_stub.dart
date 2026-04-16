import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'glass_card.dart';

class DriverCameraPanel extends StatelessWidget {
  final bool sessionLive;
  final String aiState;

  const DriverCameraPanel({
    super.key,
    required this.sessionLive,
    required this.aiState,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = sessionLive ? AppTheme.positive : AppTheme.textMuted;
    final statusLabel = sessionLive ? 'Camera module active' : 'Camera standby';

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
                      statusLabel,
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
                  sessionLive ? 'Fallback' : 'Idle',
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
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  sessionLive
                      ? Icons.videocam_off_rounded
                      : Icons.video_call_outlined,
                  color: sessionLive ? AppTheme.warning : AppTheme.textMuted,
                  size: 34,
                ),
                const SizedBox(height: 12),
                Text(
                  sessionLive
                      ? 'Embedded camera preview is not available on this platform build.'
                      : 'Start Session to prepare the driver camera module.',
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
                  sessionLive
                      ? 'The backend monitoring process can still run, but this client shows a safe fallback panel instead of a live preview.'
                      : 'When a session starts, this card switches into the driver monitoring state.',
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
        ],
      ),
    );
  }
}
