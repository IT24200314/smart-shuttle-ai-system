// ============================================================
// Smart Shuttle — Crowd Density Badge Widget
// Color-coded chip: Low (green) / Medium (amber) / High (red)
// Used on Student Map Screen
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';

class CrowdDensityBadge extends StatelessWidget {
  final CrowdDensity density;

  const CrowdDensityBadge({super.key, required this.density});

  Color get _color => switch (density) {
    CrowdDensity.low    => AppTheme.emerald,
    CrowdDensity.medium => AppTheme.amber,
    CrowdDensity.high   => AppTheme.danger,
  };

  String get _label => switch (density) {
    CrowdDensity.low    => 'Low',
    CrowdDensity.medium => 'Medium',
    CrowdDensity.high   => 'High',
  };

  IconData get _icon => switch (density) {
    CrowdDensity.low    => Icons.people_outline_rounded,
    CrowdDensity.medium => Icons.people_rounded,
    CrowdDensity.high   => Icons.groups_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: AppTheme.borderRadius,
        border: Border.all(color: _color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _color, size: 16),
          const SizedBox(width: 6),
          Text(
            'Crowd: $_label',
            style: GoogleFonts.inter(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
