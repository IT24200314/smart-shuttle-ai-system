import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_config.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/theme_toggle_button.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  final _tableScrollController = ScrollController();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _error;
  String? _roleFilter;
  String? _statusFilter;
  AppStateProvider? _appState;
  String? _sessionSignature;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _appState = context.read<AppStateProvider>();
      _sessionSignature = _buildSessionSignature(_appState!);
      _appState!.addListener(_handleAppStateChanged);
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _appState?.removeListener(_handleAppStateChanged);
    _searchCtrl.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  String _buildSessionSignature(AppStateProvider appState) {
    final token = appState.jwtToken ?? '';
    return '${appState.currentRole.name}|$token';
  }

  void _handleAppStateChanged() {
    final appState = _appState;
    if (!mounted || appState == null) return;

    final nextSignature = _buildSessionSignature(appState);
    if (nextSignature == _sessionSignature) return;

    _sessionSignature = nextSignature;
    final hasAdminSession = (appState.jwtToken ?? '').isNotEmpty &&
        appState.currentRole == UserRole.admin;
    if (hasAdminSession) {
      _loadUsers();
    }
  }

  Map<String, String> _headers({bool includeJson = false}) {
    final token = context.read<AppStateProvider>().jwtToken;
    return {
      if (includeJson) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _buildUsersUri() {
    final queryParameters = <String, String>{};
    if ((_roleFilter ?? '').isNotEmpty) {
      queryParameters['role'] = _roleFilter!;
    }
    if ((_statusFilter ?? '').isNotEmpty) {
      queryParameters['status'] = _statusFilter!;
    }
    if (_searchCtrl.text.trim().isNotEmpty) {
      queryParameters['search'] = _searchCtrl.text.trim();
    }
    return Uri.parse('${ApiConfig.baseUrl}/users')
        .replace(queryParameters: queryParameters);
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final appState = context.read<AppStateProvider>();
    if ((appState.jwtToken ?? '').isEmpty ||
        appState.currentRole != UserRole.admin) {
      debugPrint(
        '[AdminUsers] blocked load: tokenPresent=${(appState.jwtToken ?? '').isNotEmpty} '
        'role=${appState.currentRole.name}',
      );
      setState(() {
        _isLoading = false;
        _error = 'Please sign in as an admin to manage users.';
      });
      return;
    }

    final uri = _buildUsersUri();
    try {
      debugPrint('[AdminUsers] GET $uri');
      final response = await http
          .get(
            uri,
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final users = List<Map<String, dynamic>>.from(
          (decoded as List).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        debugPrint('[AdminUsers] parsed ${users.length} users');
        setState(() => _users = users);
      } else {
        final detail = _detailFromResponse(response, 'Unable to load users.');
        debugPrint(
          '[AdminUsers] request failed: status=${response.statusCode} detail=$detail',
        );
        setState(() => _error = detail);
      }
    } catch (error) {
      if (!mounted) return;
      debugPrint('[AdminUsers] request threw: $error');
      setState(() => _error = 'Unable to connect to the user management API.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _detailFromResponse(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded['detail']?.toString() ?? fallback;
      }
    } catch (_) {}
    return fallback;
  }

  Future<void> _updateUser(String id, Map<String, dynamic> body) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/users/$id'),
        headers: _headers(includeJson: true),
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        await _loadUsers();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User updated successfully.',
                style: GoogleFonts.inter(color: AppTheme.onAccent)),
            backgroundColor: AppTheme.positive,
          ),
        );
      } else {
        final payload = Map<String, dynamic>.from(jsonDecode(response.body));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(payload['detail']?.toString() ?? 'Unable to update user.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Server error while updating the user.'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _changeUserStatus(String id, String mode) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/users/$id?mode=$mode'),
        headers: _headers(),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        await _loadUsers();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mode == 'deleted'
                  ? 'User soft-deleted successfully.'
                  : 'User disabled successfully.',
              style: GoogleFonts.inter(color: AppTheme.onAccent),
            ),
            backgroundColor: AppTheme.positive,
          ),
        );
      } else {
        final payload = Map<String, dynamic>.from(jsonDecode(response.body));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(payload['detail']?.toString() ??
                'Unable to update user status.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Server error while changing user status.'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> user) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl =
        TextEditingController(text: user['name']?.toString() ?? '');
    final emailCtrl =
        TextEditingController(text: user['email']?.toString() ?? '');
    final passwordCtrl = TextEditingController();
    String role = user['role']?.toString() ?? 'student';
    String status = user['status']?.toString() ?? 'active';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        title: Text(
          'Edit User',
          style: GoogleFonts.inter(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    style: GoogleFonts.inter(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    style: GoogleFonts.inter(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter an email';
                      }
                      if (!value.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    dropdownColor: AppTheme.surfaceHigh,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(
                          value: 'student', child: Text('Student')),
                      DropdownMenuItem(value: 'driver', child: Text('Driver')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (value) => role = value ?? role,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    dropdownColor: AppTheme.surfaceHigh,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                          value: 'disabled', child: Text('Disabled')),
                      DropdownMenuItem(
                          value: 'deleted', child: Text('Deleted')),
                    ],
                    onChanged: (value) => status = value ?? status,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: true,
                    style: GoogleFonts.inter(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Reset Password',
                      helperText: 'Leave blank to keep the current password.',
                    ),
                    validator: (value) {
                      if (value != null &&
                          value.isNotEmpty &&
                          value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final payload = <String, dynamic>{
        'name': nameCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'role': role,
        'status': status,
      };
      if (passwordCtrl.text.trim().isNotEmpty) {
        payload['password'] = passwordCtrl.text.trim();
      }
      await _updateUser(user['id'].toString(), payload);
    }
  }

  String _formatDate(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) return '--';
    try {
      return DateFormat('MMM d, yyyy')
          .format(DateTime.parse(rawValue).toLocal());
    } catch (_) {
      return rawValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    context
        .select<AppStateProvider, ThemeMode>((provider) => provider.themeMode);
    final activeUsers =
        _users.where((user) => user['status'] == 'active').length;
    final disabledUsers =
        _users.where((user) => user['status'] == 'disabled').length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Management',
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            Text(
              'Account roles, status control, and lifecycle actions',
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary, fontSize: 11),
            ),
          ],
        ),
        actions: const [
          ThemeToggleButton(compact: true),
          SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        color: AppTheme.accent,
        backgroundColor: AppTheme.surfaceHigh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1360),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassCard(
                      fillColor: AppTheme.accent.withValues(alpha: 0.07),
                      borderColor: AppTheme.accent.withValues(alpha: 0.22),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Workspace Accounts',
                            style: GoogleFonts.inter(
                              color: AppTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Use filters for quick targeting, then update user role, status, and password from one table.',
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filters',
                            style: GoogleFonts.inter(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final stackControls = constraints.maxWidth < 680;
                              final searchWidth =
                                  stackControls ? constraints.maxWidth : 280.0;
                              final filterWidth =
                                  stackControls ? constraints.maxWidth : 170.0;
                              final actionWidth =
                                  stackControls ? constraints.maxWidth : null;

                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: searchWidth,
                                    child: TextField(
                                      controller: _searchCtrl,
                                      style: GoogleFonts.inter(
                                          color: AppTheme.textPrimary),
                                      decoration: const InputDecoration(
                                        labelText: 'Search name, email, or id',
                                        prefixIcon: Icon(Icons.search_rounded),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: filterWidth,
                                    child: DropdownButtonFormField<String?>(
                                      key: ValueKey(
                                          'role-${_roleFilter ?? 'all'}'),
                                      initialValue: _roleFilter,
                                      dropdownColor: AppTheme.surfaceHigh,
                                      decoration: const InputDecoration(
                                          labelText: 'Role'),
                                      items: const [
                                        DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text('All roles')),
                                        DropdownMenuItem<String?>(
                                            value: 'student',
                                            child: Text('Student')),
                                        DropdownMenuItem<String?>(
                                            value: 'driver',
                                            child: Text('Driver')),
                                        DropdownMenuItem<String?>(
                                            value: 'admin',
                                            child: Text('Admin')),
                                      ],
                                      onChanged: (value) =>
                                          setState(() => _roleFilter = value),
                                    ),
                                  ),
                                  SizedBox(
                                    width: filterWidth,
                                    child: DropdownButtonFormField<String?>(
                                      key: ValueKey(
                                          'status-${_statusFilter ?? 'all'}'),
                                      initialValue: _statusFilter,
                                      dropdownColor: AppTheme.surfaceHigh,
                                      decoration: const InputDecoration(
                                          labelText: 'Status'),
                                      items: const [
                                        DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text('All statuses')),
                                        DropdownMenuItem<String?>(
                                            value: 'active',
                                            child: Text('Active')),
                                        DropdownMenuItem<String?>(
                                            value: 'disabled',
                                            child: Text('Disabled')),
                                        DropdownMenuItem<String?>(
                                            value: 'deleted',
                                            child: Text('Deleted')),
                                      ],
                                      onChanged: (value) =>
                                          setState(() => _statusFilter = value),
                                    ),
                                  ),
                                  SizedBox(
                                    width: actionWidth,
                                    child: ElevatedButton.icon(
                                      onPressed: _loadUsers,
                                      icon: const Icon(
                                        Icons.filter_alt_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Apply'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: actionWidth,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _searchCtrl.clear();
                                          _roleFilter = null;
                                          _statusFilter = null;
                                        });
                                        _loadUsers();
                                      },
                                      child: const Text('Reset'),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.accent)),
                      )
                    else if (_error != null)
                      GlassCard(
                        fillColor: AppTheme.danger.withValues(alpha: 0.12),
                        borderColor: AppTheme.danger.withValues(alpha: 0.28),
                        child: Text(_error!,
                            style:
                                GoogleFonts.inter(color: AppTheme.textPrimary)),
                      )
                    else ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 980;
                          final cards = [
                            _UserSummaryCard(
                              label: 'Visible Users',
                              value: '${_users.length}',
                              accent: AppTheme.accent,
                            ),
                            _UserSummaryCard(
                              label: 'Active',
                              value: '$activeUsers',
                              accent: AppTheme.positive,
                            ),
                            _UserSummaryCard(
                              label: 'Disabled',
                              value: '$disabledUsers',
                              accent: AppTheme.warning,
                            ),
                          ];

                          if (!isWide) {
                            return Column(
                              children: cards
                                  .map((card) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: card,
                                      ))
                                  .toList(),
                            );
                          }

                          return Row(
                            children: [
                              for (var i = 0; i < cards.length; i++) ...[
                                Expanded(child: cards[i]),
                                if (i != cards.length - 1)
                                  const SizedBox(width: 12),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      if (_users.isEmpty)
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No users match the current filters.',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try clearing the search or resetting role and status filters.',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _searchCtrl.clear();
                                    _roleFilter = null;
                                    _statusFilter = null;
                                  });
                                  _loadUsers();
                                },
                                child: const Text('Reset Filters'),
                              ),
                            ],
                          ),
                        )
                      else
                        GlassCard(
                          padding: const EdgeInsets.all(12),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Scrollbar(
                                controller: _tableScrollController,
                                thumbVisibility: constraints.maxWidth < 1180,
                                child: SingleChildScrollView(
                                  controller: _tableScrollController,
                                  scrollDirection: Axis.horizontal,
                                  physics: const ClampingScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth,
                                    ),
                                    child: DataTable(
                                      horizontalMargin: 12,
                                      columnSpacing: 24,
                                      dataRowMinHeight: 64,
                                      dataRowMaxHeight: 74,
                                      headingTextStyle: GoogleFonts.inter(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      dataTextStyle: GoogleFonts.inter(
                                        color: AppTheme.textPrimary,
                                      ),
                                      columns: const [
                                        DataColumn(label: Text('Name')),
                                        DataColumn(label: Text('Email')),
                                        DataColumn(label: Text('Role')),
                                        DataColumn(label: Text('Status')),
                                        DataColumn(label: Text('Created')),
                                        DataColumn(label: Text('Actions')),
                                      ],
                                      rows: _users.map((user) {
                                        final status =
                                            user['status']?.toString() ??
                                                'active';
                                        final isPrimaryAdmin =
                                            user['id'] == 'admin-01';
                                        return DataRow(
                                          color: WidgetStateProperty
                                              .resolveWith<Color?>(
                                            (_) => status == 'deleted'
                                                ? AppTheme.danger
                                                    .withValues(alpha: 0.05)
                                                : null,
                                          ),
                                          cells: [
                                            DataCell(
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    user['name']?.toString() ??
                                                        '',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  if (isPrimaryAdmin)
                                                    Text(
                                                      'Primary admin',
                                                      style: GoogleFonts.inter(
                                                        color: AppTheme.warning,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            DataCell(
                                              ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                  maxWidth: 240,
                                                ),
                                                child: Text(
                                                  user['email']?.toString() ??
                                                      '',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.accent
                                                      .withValues(alpha: 0.14),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  (user['role']?.toString() ??
                                                          '')
                                                      .toUpperCase(),
                                                  style: GoogleFonts.inter(
                                                    color: AppTheme.textPrimary,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                status,
                                                style: GoogleFonts.inter(
                                                  color: status == 'active'
                                                      ? AppTheme.positive
                                                      : status == 'disabled'
                                                          ? AppTheme.warning
                                                          : AppTheme.danger,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                _formatDate(
                                                  user['created_at']
                                                      ?.toString(),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    tooltip: 'Edit user',
                                                    onPressed: isPrimaryAdmin
                                                        ? null
                                                        : () => _showEditDialog(
                                                            user),
                                                    icon: const Icon(
                                                      Icons.edit_rounded,
                                                      size: 18,
                                                    ),
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                                  PopupMenuButton<String>(
                                                    tooltip: 'Status actions',
                                                    color: AppTheme.surfaceHigh,
                                                    onSelected: isPrimaryAdmin
                                                        ? null
                                                        : (value) =>
                                                            _changeUserStatus(
                                                              user['id']
                                                                  .toString(),
                                                              value,
                                                            ),
                                                    itemBuilder: (context) =>
                                                        const [
                                                      PopupMenuItem(
                                                        value: 'disabled',
                                                        child: Text(
                                                          'Disable User',
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'deleted',
                                                        child: Text(
                                                          'Soft Delete User',
                                                        ),
                                                      ),
                                                    ],
                                                    icon: Icon(
                                                      Icons.more_vert_rounded,
                                                      size: 18,
                                                      color: isPrimaryAdmin
                                                          ? AppTheme.textMuted
                                                          : AppTheme
                                                              .textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _UserSummaryCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
                color: accent, fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
