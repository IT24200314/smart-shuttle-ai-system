// ============================================================
// Smart Shuttle — Alert Card Widget (Redesigned)
// Cleaner severity styling, left-border when active
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class AlertCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isActive;
  final Color alertColor;
  final VoidCallback? onSimulate;

  const AlertCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.alertColor,
    this.onSimulate,
  });

  @override
  State<AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<AlertCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacityAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.alertColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        borderRadius: AppTheme.cardRadius,
        color: widget.isActive
            ? color.withOpacity(0.10)
            : AppTheme.surface,
        border: Border.all(
          color: widget.isActive ? color.withOpacity(0.6) : AppTheme.border,
          width: 1,
        ),
        boxShadow: widget.isActive
            ? [
                BoxShadow(
                  color: color.withOpacity(0.20),
                  blurRadius: 18,
                  spreadRadius: 0,
                )
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: AppTheme.cardRadius,
        child: Row(
          children: [
            // Severity left border
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: 4,
              height: 80,
              color: widget.isActive ? color : AppTheme.borderStrong,
            ),
            const SizedBox(width: 14),
            // Icon
            AnimatedBuilder(
              animation: _opacityAnim,
              builder: (_, child) => Opacity(
                opacity: widget.isActive ? _opacityAnim.value : 1.0,
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? color.withOpacity(0.18)
                      : AppTheme.surfaceHigh,
                  borderRadius: AppTheme.chipRadius,
                ),
                child: Icon(
                  widget.icon,
                  color: widget.isActive ? color : AppTheme.textMuted,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        color: widget.isActive ? color : AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.isActive ? 'ALERT ACTIVE — AI detected event' : widget.subtitle,
                      style: GoogleFonts.inter(
                        color: widget.isActive
                            ? color.withOpacity(0.85)
                            : AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Simulate / Clear button
            if (widget.onSimulate != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton(
                  onPressed: widget.onSimulate,
                  style: TextButton.styleFrom(
                    backgroundColor: widget.isActive
                        ? color.withOpacity(0.15)
                        : AppTheme.surfaceHigh,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.chipRadius,
                    ),
                  ),
                  child: Text(
                    widget.isActive ? 'Clear' : 'Test',
                    style: GoogleFonts.inter(
                      color: widget.isActive ? color : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
