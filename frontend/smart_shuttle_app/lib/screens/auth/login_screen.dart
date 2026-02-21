// ============================================================
// Smart Shuttle — Login Screen
// Initial route for all users. Mock role-based routing.
// Demo fallback: "Skip for Demo" → RoleSelectionScreen
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../navigation/home_navigator.dart';
import '../admin/admin_dashboard_screen.dart';
import '../driver/driver_dashboard_screen.dart';
import '../student/student_map_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isLoading       = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Mock role-based login ───────────────────────────────────
  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // Simulate a network delay
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _isLoading = false);

    final email = _emailCtrl.text.trim().toLowerCase();
    Widget destination;

    if (email.contains('admin')) {
      destination = AdminDashboardScreen();
    } else if (email.contains('driver')) {
      destination = DriverDashboardScreen();
    } else {
      destination = StudentMapScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  // ── Skip for Demo ───────────────────────────────────────────
  void _skipForDemo() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeNavigator()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.darkBlue, AppTheme.deepBlue, Color(0xFF1B3A6B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Logo & Title ──────────────────────────
                    Container(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.emerald.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.directions_bus_rounded,
                          color: AppTheme.emerald,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Smart Shuttle',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'AI-Powered University Transport System',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppTheme.emerald,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Email Field ───────────────────────────
                    _InputLabel('Email Address'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: _inputDecoration(
                        hint: 'e.g. admin@shuttle.lk',
                        icon: Icons.email_outlined,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter your email';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // ── Password Field ────────────────────────
                    _InputLabel('Password'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: _inputDecoration(
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppTheme.textSecondary,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter your password';
                        if (v.length < 4) return 'Password too short';
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // ── Login Button ──────────────────────────
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emerald,
                          disabledBackgroundColor: AppTheme.emerald.withOpacity(0.5),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppTheme.borderRadius,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Login',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Demo Hint ─────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: AppTheme.borderRadius,
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        'Hint — Email routing: admin@… → Admin  ·  driver@… → Driver  ·  other → Student',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // ── Skip for Demo ─────────────────────────
                    TextButton(
                      onPressed: _skipForDemo,
                      child: Text(
                        'Skip for Demo  →  Role Selection',
                        style: GoogleFonts.inter(
                          color: AppTheme.emerald.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13),
      prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: AppTheme.borderRadius,
        borderSide: const BorderSide(color: AppTheme.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppTheme.borderRadius,
        borderSide: const BorderSide(color: AppTheme.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppTheme.borderRadius,
        borderSide: const BorderSide(color: AppTheme.emerald, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppTheme.borderRadius,
        borderSide: const BorderSide(color: AppTheme.danger),
      ),
      errorStyle: GoogleFonts.inter(color: AppTheme.danger, fontSize: 11),
    );
  }
}

class _InputLabel extends StatelessWidget {
  final String text;
  const _InputLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.inter(
      color: AppTheme.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  );
}
