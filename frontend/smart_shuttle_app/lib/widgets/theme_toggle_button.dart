import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../theme/app_theme.dart';

class ThemeToggleButton extends StatelessWidget {
  final bool compact;

  const ThemeToggleButton({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final isDark = appState.isDarkMode;
    final icon = isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded;
    final tooltip = isDark ? 'Switch to light mode' : 'Switch to dark mode';

    if (compact) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.read<AppStateProvider>().toggleThemeMode(),
            borderRadius: AppTheme.chipRadius,
            child: Ink(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: AppTheme.chipRadius,
                border: Border.all(color: AppTheme.border),
              ),
              child: Icon(icon, color: AppTheme.textPrimary, size: 20),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.read<AppStateProvider>().toggleThemeMode(),
        borderRadius: AppTheme.cardRadius,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh,
            borderRadius: AppTheme.cardRadius,
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.accentDim,
                  borderRadius: AppTheme.chipRadius,
                ),
                child: Icon(icon, color: AppTheme.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isDark ? 'Light mode' : 'Dark mode',
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Appearance',
                    style: GoogleFonts.inter(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
