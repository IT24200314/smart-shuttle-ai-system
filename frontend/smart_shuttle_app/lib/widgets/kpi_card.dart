import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'glass_card.dart';

class KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final bool isPositive;
  final Color? accentColor;
  final bool compact;

  const KpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.isPositive = true,
    this.accentColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppTheme.accent;
    final statusColor = isPositive ? AppTheme.positive : AppTheme.danger;
    final statusText = isPositive ? 'Stable' : 'Attention';
    final cardPadding = compact ? 14.0 : 20.0;
    final valueSize = compact ? 28.0 : 34.0;
    final iconBoxPadding = compact ? 10.0 : 12.0;
    final iconSize = compact ? 20.0 : 22.0;
    final headerGap = compact ? 14.0 : 22.0;
    final labelGap = compact ? 6.0 : 10.0;
    final cardFill = Color.alphaBlend(
      accent.withOpacity(AppTheme.isDarkMode ? 0.11 : 0.08),
      AppTheme.surface,
    );
    final cardBorder = Color.alphaBlend(
      accent.withOpacity(AppTheme.isDarkMode ? 0.18 : 0.10),
      AppTheme.border,
    );

    return GlassCard(
      fillColor: cardFill,
      borderColor: cardBorder,
      padding: EdgeInsets.all(cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(iconBoxPadding),
                decoration: BoxDecoration(
                  color: accent.withOpacity(
                    AppTheme.isDarkMode ? 0.18 : 0.11,
                  ),
                  borderRadius: AppTheme.chipRadius,
                ),
                child: Icon(icon, color: accent, size: iconSize),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 9 : 10,
                  vertical: compact ? 5 : 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(
                    AppTheme.isDarkMode ? 0.14 : 0.10,
                  ),
                  borderRadius: AppTheme.chipRadius,
                  border: Border.all(
                    color: statusColor.withOpacity(
                      AppTheme.isDarkMode ? 0.28 : 0.20,
                    ),
                  ),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontSize: compact ? 10.5 : 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: headerGap),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: labelGap),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: valueSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.3,
              height: 1,
            ),
          ),
          SizedBox(height: compact ? 7 : 10),
          if ((subtitle ?? '').isNotEmpty)
            Flexible(
              child: Text(
                subtitle!,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: compact ? 11.5 : 12,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
