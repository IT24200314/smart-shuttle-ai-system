import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_config.dart';
import '../../widgets/theme_toggle_button.dart';
import '../admin/admin_dashboard_screen.dart';
import '../driver/driver_dashboard_screen.dart';
import '../student/student_map_screen.dart';
import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isLoading = false;
  final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _autofillDemo(String email) {
    _emailCtrl.text = email;
    _passwordCtrl.text = 'password';
    setState(() {});
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });

    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text;

    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(json.decode(res.body));
        final token = data['access_token'] ?? data['token'];
        final roleStr = data['role']?.toString() ?? 'student';
        final name = data['name']?.toString() ?? 'User';
        final userId = data['user_id']?.toString();
        final userEmail = data['email']?.toString() ?? email;

        context.read<AppStateProvider>().setSession(
              token?.toString(),
              userEmail,
              userId: userId,
              userName: name,
            );

        Widget destination;
        if (roleStr == 'admin') {
          context.read<AppStateProvider>().setRole(UserRole.admin);
          destination = const AdminDashboardScreen();
        } else if (roleStr == 'driver') {
          context.read<AppStateProvider>().setRole(UserRole.driver);
          destination = const DriverDashboardScreen();
        } else {
          context.read<AppStateProvider>().setRole(UserRole.student);
          destination = const StudentMapScreen();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sign-in successful.',
              style: GoogleFonts.inter(color: AppTheme.onAccent),
            ),
            backgroundColor: AppTheme.positive,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => destination),
        );
        return;
      }

      String message;
      if (res.statusCode == 503 || res.statusCode == 429) {
        message =
            'Server busy or Firestore quota exceeded. Please try again in a few minutes.';
      } else if (res.statusCode == 500) {
        message = 'Internal server error. Contact admin for assistance.';
      } else {
        message = 'Invalid email or password.';
      }

      try {
        final payload = Map<String, dynamic>.from(json.decode(res.body));
        message = _messageFromPayload(payload, message);
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.inter(color: AppTheme.onAccent),
          ),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      String errorMsg =
          'Cannot connect to server. Make sure the FastAPI backend is running.';
      if (e is http.ClientException ||
          e.toString().contains('SocketException')) {
        errorMsg = 'No internet connection or backend is unreachable.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMsg =
            'Connection timed out. The server is taking too long to respond.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMsg,
            style: GoogleFonts.inter(color: AppTheme.onAccent),
          ),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _messageFromPayload(Map<String, dynamic> payload, String fallback) {
    final detail = payload['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] != null) {
        return first['msg'].toString();
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppStateProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _LoginBackdrop()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 800;
                final horizontalPadding = isDesktop ? 28.0 : 18.0;
                final verticalPadding = isDesktop ? 20.0 : 18.0;
                final minContentHeight = math.max(
                  0.0,
                  constraints.maxHeight - (verticalPadding * 2),
                );

                final content = ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildBrandPanel(compact: false),
                            ),
                            const SizedBox(width: 28),
                            Expanded(
                              child: _buildLoginFormCard(
                                isWideLayout: true,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildBrandPanel(compact: true),
                            const SizedBox(height: 16),
                            _buildLoginFormCard(isWideLayout: false),
                          ],
                        ),
                );

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    verticalPadding,
                    horizontalPadding,
                    verticalPadding,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minContentHeight),
                    child: Center(
                      child: content,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandPanel({required bool compact}) {
    final titleSize = compact ? 14.0 : 15.0;
    final headlineSize = compact ? 28.0 : 42.0;
    final bodySize = compact ? 13.0 : 15.0;

    return Container(
      padding: EdgeInsets.all(compact ? 20 : 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surface.withOpacity(0.96),
            AppTheme.surfaceHigh.withOpacity(0.94),
            AppTheme.gradientAccent.withOpacity(
              AppTheme.isDarkMode ? 0.26 : 0.34,
            ),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowSoft
                .withOpacity(AppTheme.isDarkMode ? 0.34 : 0.10),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: compact ? -28 : -40,
            right: compact ? -20 : -26,
            child: _GlowOrb(
              size: compact ? 150 : 220,
              color: AppTheme.accent.withOpacity(
                AppTheme.isDarkMode ? 0.24 : 0.16,
              ),
            ),
          ),
          Positioned(
            bottom: compact ? -70 : -88,
            left: compact ? -52 : -68,
            child: _GlowOrb(
              size: compact ? 180 : 250,
              color: AppTheme.secondaryAccent.withOpacity(
                AppTheme.isDarkMode ? 0.18 : 0.12,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withOpacity(0.72),
                      borderRadius: AppTheme.cardRadius,
                      border: Border.all(
                        color: AppTheme.borderStrong.withOpacity(0.7),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 16,
                          color: AppTheme.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Campus mobility suite',
                          style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ThemeToggleButton(compact: compact),
                ],
              ),
              SizedBox(height: compact ? 22 : 34),
              Text(
                'Smart Shuttle',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Operate every campus trip from one clean command surface.',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: headlineSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.3,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                compact
                    ? 'Sign in to access live student tracking, AI driver monitoring, and admin operations without the desktop layout feeling squeezed onto a phone.'
                    : 'Smart Shuttle brings route visibility, driver safety monitoring, feedback operations, and admin workflows into one secure product experience built for campus transport teams.',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: bodySize,
                  height: 1.6,
                ),
              ),
              SizedBox(height: compact ? 18 : 24),
              const Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _RoleHint(label: 'Students', icon: Icons.school_rounded),
                  _RoleHint(label: 'Drivers', icon: Icons.badge_rounded),
                  _RoleHint(
                    label: 'Admin teams',
                    icon: Icons.admin_panel_settings_rounded,
                  ),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withOpacity(0.70),
                    borderRadius: AppTheme.cardRadius,
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FeatureLine(
                        icon: Icons.route_rounded,
                        title: 'Live transport visibility',
                        description:
                            'Track student routes, ETA updates, and vehicle activity from a cleaner shared control layer.',
                      ),
                      SizedBox(height: 14),
                      _FeatureLine(
                        icon: Icons.health_and_safety_rounded,
                        title: 'AI-backed driver safety',
                        description:
                            'Surface drowsiness, phone-use, and yawn alerts while preserving the existing operational flow.',
                      ),
                      SizedBox(height: 14),
                      _FeatureLine(
                        icon: Icons.dashboard_customize_rounded,
                        title: 'Role-based admin workflow',
                        description:
                            'Handle revenue, feedback, lost and found, users, and audit review without clutter.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _BrandCapability(
                      title: 'Live operations',
                      subtitle: 'Responsive desktop and mobile access',
                      accentIcon: Icons.radar_rounded,
                    ),
                    _BrandCapability(
                      title: 'Secure workflows',
                      subtitle: 'Role-aware sign-in and trusted access',
                      accentIcon: Icons.lock_rounded,
                    ),
                    _BrandCapability(
                      title: 'Support ready',
                      subtitle: 'Built for service teams and real alerts',
                      accentIcon: Icons.support_agent_rounded,
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 16),
                const Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _BrandMiniMetric(
                      label: 'Live ops',
                      value: 'Students + drivers',
                    ),
                    _BrandMiniMetric(
                      label: 'Admin',
                      value: 'Revenue and support',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginFormCard({required bool isWideLayout}) {
    return Container(
      padding: EdgeInsets.all(isWideLayout ? 32 : 22),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowSoft
                .withOpacity(AppTheme.isDarkMode ? 0.40 : 0.10),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accentDim,
                borderRadius: AppTheme.cardRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Secure sign in',
                    style: GoogleFonts.inter(
                      color: AppTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Welcome back',
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: isWideLayout ? 34 : 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.1,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Use your registered account to continue into the correct Smart Shuttle workspace.',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 26),
            const _Label('Email Address'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 14,
              ),
              decoration: _inputDeco(
                hint: 'admin@shuttle.lk',
                icon: Icons.email_outlined,
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) {
                  return 'Enter your email';
                }
                if (!_emailPattern.hasMatch(email)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            const _Label('Password'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 14,
              ),
              decoration: _inputDeco(
                hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
              ).copyWith(
                suffixIcon: SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppTheme.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _buildPrimaryButton(),
            const SizedBox(height: 20),
            _buildDemoAccessSection(),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistrationScreen(),
                    ),
                  ),
                  child: Text(
                    'Sign Up',
                    style: GoogleFonts.inter(
                      color: AppTheme.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton() {
    final gradientColors = _isLoading
        ? [
            AppTheme.accent.withOpacity(0.55),
            AppTheme.accentHover.withOpacity(0.55),
          ]
        : [AppTheme.accent, AppTheme.accentHover];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: gradientColors,
        ),
        borderRadius: AppTheme.cardRadius,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(
              AppTheme.isDarkMode ? 0.28 : 0.18,
            ),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: AppTheme.onAccent,
            shape: const RoundedRectangleBorder(
              borderRadius: AppTheme.cardRadius,
            ),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.onAccent,
                  ),
                )
              : Text(
                  'Continue to workspace',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onAccent,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDemoAccessSection() {
    const demos = [
      _DemoAccount(
        label: 'Admin Demo',
        email: 'admin@shuttle.lk',
        icon: Icons.admin_panel_settings_rounded,
      ),
      _DemoAccount(
        label: 'Driver Demo',
        email: 'driver@shuttle.lk',
        icon: Icons.badge_rounded,
      ),
      _DemoAccount(
        label: 'Student Demo',
        email: 'student1@shuttle.lk',
        icon: Icons.school_rounded,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withOpacity(0.78),
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AppTheme.accent,
              ),
              const SizedBox(width: 8),
              Text(
                'Quick demo login',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tap any role to fill the demo credentials instantly.',
            style: GoogleFonts.inter(
              color: AppTheme.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 420;

              if (isStacked) {
                return Column(
                  children: demos
                      .map(
                        (demo) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DemoChip(
                            label: demo.label,
                            email: demo.email,
                            icon: demo.icon,
                            onTap: () => _autofillDemo(demo.email),
                          ),
                        ),
                      )
                      .toList(),
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: demos
                    .map(
                      (demo) => SizedBox(
                        width: 170,
                        child: _DemoChip(
                          label: demo.label,
                          email: demo.email,
                          icon: demo.icon,
                          onTap: () => _autofillDemo(demo.email),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: AppTheme.textMuted,
        fontSize: 13,
      ),
      prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
      filled: true,
      fillColor: AppTheme.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: AppTheme.inputRadius,
        borderSide: BorderSide(color: AppTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppTheme.inputRadius,
        borderSide: BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppTheme.inputRadius,
        borderSide: BorderSide(
          color: AppTheme.accent,
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppTheme.inputRadius,
        borderSide: BorderSide(color: AppTheme.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppTheme.inputRadius,
        borderSide: BorderSide(color: AppTheme.danger, width: 1.6),
      ),
      errorStyle: GoogleFonts.inter(
        color: AppTheme.danger,
        fontSize: 11,
      ),
    );
  }
}

class _DemoAccount {
  final String label;
  final String email;
  final IconData icon;

  const _DemoAccount({
    required this.label,
    required this.email,
    required this.icon,
  });
}

class _RoleHint extends StatelessWidget {
  final String label;
  final IconData icon;

  const _RoleHint({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.74),
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureLine({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accentDim,
            borderRadius: AppTheme.chipRadius,
          ),
          child: Icon(icon, color: AppTheme.accent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrandCapability extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData accentIcon;

  const _BrandCapability({
    required this.title,
    required this.subtitle,
    required this.accentIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.68),
          borderRadius: AppTheme.cardRadius,
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(accentIcon, color: AppTheme.secondaryAccent, size: 18),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _BrandMiniMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.72),
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoChip extends StatelessWidget {
  final String label;
  final String email;
  final IconData icon;
  final VoidCallback onTap;

  const _DemoChip({
    required this.label,
    required this.email,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.cardRadius,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: AppTheme.cardRadius,
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.accentDim,
                  borderRadius: AppTheme.chipRadius,
                ),
                child: Icon(icon, color: AppTheme.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Use',
                style: GoogleFonts.inter(
                  color: AppTheme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.background,
              AppTheme.surface.withOpacity(AppTheme.isDarkMode ? 0.88 : 0.82),
              AppTheme.background,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -70,
              child: _GlowOrb(
                size: 320,
                color: AppTheme.accent.withOpacity(
                  AppTheme.isDarkMode ? 0.14 : 0.10,
                ),
              ),
            ),
            Positioned(
              top: 90,
              right: -90,
              child: _GlowOrb(
                size: 280,
                color: AppTheme.secondaryAccent.withOpacity(
                  AppTheme.isDarkMode ? 0.10 : 0.08,
                ),
              ),
            ),
            Positioned(
              bottom: -140,
              right: 40,
              child: _GlowOrb(
                size: 360,
                color: AppTheme.gradientAccent.withOpacity(
                  AppTheme.isDarkMode ? 0.22 : 0.18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}
