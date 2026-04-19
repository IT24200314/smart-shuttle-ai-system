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
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dense = compact || constraints.maxWidth < 240;
          final cardPadding = dense ? 12.0 : 18.0;
          final valueSize = dense ? 24.0 : 30.0;
          final iconBoxPadding = dense ? 9.0 : 12.0;
          final iconSize = dense ? 18.0 : 22.0;
          final titleGap = dense ? 10.0 : 16.0;
          final valueGap = dense ? 4.0 : 8.0;
          final stackHeader = constraints.maxWidth < 220;
          final statusChip = Container(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 9 : 10,
              vertical: dense ? 5 : 6,
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
                fontSize: dense ? 10.5 : 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          );

          return Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (stackHeader) ...[
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
                  const SizedBox(height: 10),
                  statusChip,
                ] else
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
                      statusChip,
                    ],
                  ),
                SizedBox(height: titleGap),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: dense ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: valueGap),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: valueSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.1,
                    height: 1,
                  ),
                ),
                if ((subtitle ?? '').isNotEmpty) ...[
                  SizedBox(height: dense ? 8 : 10),
                  Text(
                    subtitle!,
                    maxLines: dense ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                      fontSize: dense ? 11 : 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
