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
  late final AnimationController _pulseCtrl;
  late final Animation<double> _opacityAnim;

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
        color:
            widget.isActive ? color.withValues(alpha: 0.10) : AppTheme.surface,
        border: Border.all(
          color:
              widget.isActive ? color.withValues(alpha: 0.6) : AppTheme.border,
          width: 1,
        ),
        boxShadow: widget.isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.20),
                  blurRadius: 18,
                ),
              ]
            : const [],
      ),
      child: ClipRRect(
        borderRadius: AppTheme.cardRadius,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showInlineAction =
                widget.onSimulate != null && constraints.maxWidth >= 520;

            final actionButton = widget.onSimulate == null
                ? null
                : TextButton(
                    onPressed: widget.onSimulate,
                    style: TextButton.styleFrom(
                      backgroundColor: widget.isActive
                          ? color.withValues(alpha: 0.15)
                          : AppTheme.surfaceHigh,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: const RoundedRectangleBorder(
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
                  );

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: 4,
                    decoration: BoxDecoration(
                      color: widget.isActive ? color : AppTheme.borderStrong,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedBuilder(
                            animation: _opacityAnim,
                            builder: (_, child) => Opacity(
                              opacity:
                                  widget.isActive ? _opacityAnim.value : 1.0,
                              child: child,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: widget.isActive
                                    ? color.withValues(alpha: 0.18)
                                    : AppTheme.surfaceHigh,
                                borderRadius: AppTheme.chipRadius,
                              ),
                              child: Icon(
                                widget.icon,
                                color: widget.isActive
                                    ? color
                                    : AppTheme.textMuted,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: widget.isActive
                                        ? color
                                        : AppTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.isActive
                                      ? 'ALERT ACTIVE - AI detected event'
                                      : widget.subtitle,
                                  maxLines: showInlineAction ? 2 : 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: widget.isActive
                                        ? color.withValues(alpha: 0.85)
                                        : AppTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: widget.isActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    height: 1.4,
                                  ),
                                ),
                                if (!showInlineAction &&
                                    actionButton != null) ...[
                                  const SizedBox(height: 12),
                                  actionButton,
                                ],
                              ],
                            ),
                          ),
                          if (showInlineAction && actionButton != null) ...[
                            const SizedBox(width: 14),
                            actionButton,
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
