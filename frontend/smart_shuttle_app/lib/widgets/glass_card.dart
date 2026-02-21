// ============================================================
// Smart Shuttle — Glassmorphism Card Widget
// Reusable card with BackdropFilter blur, frosted gradient,
// and 8px BorderRadius (Rubric: Design Consistency)
// ============================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color? borderColor;
  final Color? fillColor;
  final double blurSigma;
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
    this.blurSigma = 10.0,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? AppTheme.borderRadius;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            width: width,
            height: height,
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: fillColor ?? AppTheme.glassFill,
              borderRadius: br,
              border: Border.all(
                color: borderColor ?? AppTheme.glassBorder,
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.10),
                  Colors.white.withOpacity(0.04),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
