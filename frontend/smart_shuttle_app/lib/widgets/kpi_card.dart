// ============================================================
// Smart Shuttle — KPI Card Widget
// Compact metric tile with icon, label, value, trend arrow
// Used on Admin Dashboard and Revenue Dashboard
// ============================================================

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

  const KpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.isPositive = true,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppTheme.emerald;
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: AppTheme.borderRadius,
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const Spacer(),
              Icon(
                isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: isPositive ? AppTheme.emerald : AppTheme.danger,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // FittedBox scales the value text down if space is tight
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: isPositive ? AppTheme.emerald : AppTheme.danger,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
