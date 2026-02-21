// ============================================================
// Smart Shuttle — Alert Card Widget
// Pulsing safety alert card for Driver View
// Includes glow animation when active
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
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
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
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isActive ? _pulseAnim.value : 1.0,
          child: child,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: AppTheme.borderRadius,
          color: widget.isActive
              ? color.withOpacity(0.18)
              : AppTheme.glassFill,
          border: Border.all(
            color: widget.isActive ? color : AppTheme.glassBorder,
            width: widget.isActive ? 2 : 1,
          ),
          boxShadow: widget.isActive
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.45),
                    blurRadius: 24,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isActive ? color.withOpacity(0.25) : Colors.white10,
                borderRadius: AppTheme.borderRadius,
              ),
              child: Icon(
                widget.icon,
                color: widget.isActive ? color : AppTheme.textSecondary,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.inter(
                      color: widget.isActive ? color : AppTheme.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.isActive ? '⚠ ALERT ACTIVE' : widget.subtitle,
                    style: GoogleFonts.inter(
                      color: widget.isActive
                          ? color.withOpacity(0.9)
                          : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onSimulate != null)
              TextButton(
                onPressed: widget.onSimulate,
                child: Text(
                  widget.isActive ? 'Clear' : 'Simulate',
                  style: GoogleFonts.inter(
                    color: widget.isActive ? color : AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
