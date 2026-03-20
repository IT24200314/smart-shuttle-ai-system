// ============================================================
// Smart Shuttle — App Card Widget (Redesigned GlassCard)
// Clean surface card with subtle border, 14px radius
// Kept as GlassCard for backward compatibility
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color? borderColor;
  final Color? fillColor;
  final double blurSigma; // kept for API compat, unused
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.borderColor,
    this.fillColor,
    this.blurSigma = 0,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? AppTheme.cardRadius;
    final fill = fillColor ?? AppTheme.surface;
    final bc = borderColor ?? AppTheme.border;

    final card = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: br,
        border: Border.all(color: bc, width: 1),
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: br,
        child: card,
      );
    }
    return card;
  }
}
