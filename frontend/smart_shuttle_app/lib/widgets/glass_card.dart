import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GlassCard extends StatefulWidget {
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
    this.blurSigma = 0,
    this.borderRadius,
    this.onTap,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? AppTheme.cardRadius;
    final fillColor = widget.fillColor ??
        (AppTheme.isDarkMode
            ? AppTheme.surface
            : AppTheme.surface.withOpacity(0.98));
    final borderColor = widget.borderColor ?? AppTheme.border;
    final isInteractive = widget.onTap != null;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: (isInteractive && _hovered)
              ? AppTheme.accent.withOpacity(AppTheme.isDarkMode ? 0.40 : 0.30)
              : borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowSoft
                .withOpacity(AppTheme.isDarkMode ? 0.36 : 0.14),
            blurRadius: isInteractive && _hovered ? 30 : 20,
            offset: Offset(0, isInteractive && _hovered ? 16 : 10),
          ),
          if (isInteractive && _hovered)
            BoxShadow(
              color: AppTheme.accent.withOpacity(
                AppTheme.isDarkMode ? 0.12 : 0.10,
              ),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Padding(
        padding: widget.padding ?? const EdgeInsets.all(16),
        child: widget.child,
      ),
    );

    if (!isInteractive) {
      return card;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: borderRadius,
            splashColor: AppTheme.accent.withOpacity(0.10),
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: card,
          ),
        ),
      ),
    );
  }
}
