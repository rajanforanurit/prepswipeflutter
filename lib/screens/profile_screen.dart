import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/analytics_provider.dart';
import '../providers/quiz_provider.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PSColors {
  static const Color primary = Color(0xFF7C4DFF);
  static const Color secondary = Color(0xFFFF9F1C);
  static const Color bg = Color(0xFF090C14);
  static const Color card = Color(0xFF161B2C);
  static const Color cardBorder = Color(0x1FFFFFFF);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textTertiary = Color(0x66FFFFFF);
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color gold = Color(0xFFFFD166);
  static const Color cyan = Color(0xFF4DD8FF);
}

const String _fontHeading = 'Poppins';
const String _fontBody = 'Inter';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _loadingProfile = false;
  Map<String, dynamic>? _profile;

  late TabController _analyticsTabs;

  final _userIdController = TextEditingController();
  String? _selectedExam;
  bool _savingSettings = false;
  bool _loadingSettingsProfile = false;
  String? _settingsError;
  bool _soundEnabled = true;
  static const String _soundPrefKey = 'sound_enabled';
  @override
  void initState() {
    super.initState();
    _analyticsTabs = TabController(length: 3, vsync: this);
    _analyticsTabs.addListener(_onAnalyticsTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProfile();
      _loadAnalytics();
      _loadSettingsProfile();
      _loadSoundPreference();
    });
  }

  void _onAnalyticsTabChanged() {
    if (_analyticsTabs.indexIsChanging) {
      setState(() {});
    }
    if (_analyticsTabs.index == 2) {
      context.read<AnalyticsProvider>().loadRank();
    }
  }

  Future<void> _toggleSound(bool value) async {
    setState(() => _soundEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundPrefKey, value);
  }

  Future<void> _loadAnalytics({bool force = false}) async {
    await context.read<AnalyticsProvider>().load(force: force);
  }

  Future<void> _fetchProfile() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    setState(() => _loadingProfile = true);
    try {
      final data = await ApiService().getUserProfile();
      if (mounted) {
        setState(() {
          _profile = data['profile'] as Map<String, dynamic>?;
          _loadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadSettingsProfile() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    setState(() => _loadingSettingsProfile = true);
    try {
      final data = await ApiService().getUserProfile();
      final profile = data['profile'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _userIdController.text = profile['userID']?.toString() ?? '';
          _selectedExam = profile['examType']?.toString();
          _loadingSettingsProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSettingsProfile = false);
    }
  }

  Future<void> _loadSoundPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _soundEnabled = prefs.getBool(_soundPrefKey) ?? true;
      });
    }
  }

  Future<void> _saveSettings() async {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty) {
      setState(() => _settingsError = 'Please enter a User ID');
      return;
    }
    if (_selectedExam == null) {
      setState(() => _settingsError = 'Please select an exam type');
      return;
    }
    setState(() {
      _savingSettings = true;
      _settingsError = null;
    });
    try {
      await ApiService().updateUserProfile({
        'userID': userId.toLowerCase(),
        'examType': _selectedExam,
      });
      await context.read<AuthProvider>().refreshProfile();
      if (mounted) {
        context.read<QuizProvider>().loadQuestions(_selectedExam!);
        setState(() => _savingSettings = false);
        await _fetchProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved',
                style: TextStyle(fontFamily: _fontBody)),
            backgroundColor: PSColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _savingSettings = false;
          _settingsError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _confirmSignOut(BuildContext context, AuthProvider auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PSColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Sign Out',
            style: TextStyle(
                fontFamily: _fontHeading,
                fontWeight: FontWeight.w700,
                color: PSColors.textPrimary)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(
                fontFamily: _fontBody, color: PSColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(
                    fontFamily: _fontBody, color: PSColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out',
                style: TextStyle(
                    fontFamily: _fontBody,
                    color: PSColors.error,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true) await auth.signOut();
  }

  @override
  void dispose() {
    _analyticsTabs.removeListener(_onAnalyticsTabChanged);
    _analyticsTabs.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _fetchProfile(),
      _loadAnalytics(force: true),
      _loadSettingsProfile(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: PSColors.bg,
      body: SafeArea(
        child: auth.user == null
            ? _NotAuthView(onSignIn: () => auth.signInWithGoogle(context))
            : _loadingProfile
                ? const _PSLoader(message: 'Loading profile…')
                : _buildBody(context, auth),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AuthProvider auth) {
    final ap = context.watch<AnalyticsProvider>();

    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: PSColors.primary,
      backgroundColor: PSColors.card,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildProfileHeader(context, auth),
                const SizedBox(height: 28),
                _sectionTitle(
                    'Analytics', Icons.bar_chart_rounded, PSColors.primary),
                const SizedBox(height: 14),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: _buildAnalyticsTabs(ap),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 48),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _sectionTitle(
                    'Settings', Icons.settings_rounded, PSColors.secondary),
                const SizedBox(height: 14),
                _buildSettingsSection(),
                const SizedBox(height: 40),
                _buildSignOutButton(context, auth),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String label, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontFamily: _fontHeading,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: PSColors.textPrimary,
                letterSpacing: -0.2)),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context, AuthProvider auth) {
    final user = auth.user!;
    final displayName =
        _profile?['displayName']?.toString().trim().isNotEmpty == true
            ? _profile!['displayName']!.toString().trim()
            : (user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : user.email?.split('@').first ?? 'User');

    final email = user.email ?? '';
    final examType = _profile?['examType']?.toString();
    final avatarLetter =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return _GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      glowColor: PSColors.primary,
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [PSColors.primary, PSColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                    color: PSColors.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: 1)
              ],
            ),
            child: ClipOval(
              child: Container(
                color: PSColors.card,
                child: user.photoURL != null
                    ? Image.network(user.photoURL!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _AvatarFallback(letter: avatarLetter))
                    : _AvatarFallback(letter: avatarLetter),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(displayName,
              style: const TextStyle(
                  fontFamily: _fontHeading,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: PSColors.textPrimary,
                  letterSpacing: -0.3),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            email.isNotEmpty ? email : 'No email',
            style: const TextStyle(
                fontFamily: _fontBody,
                fontSize: 13,
                color: PSColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: examType != null
                  ? PSColors.secondary.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: examType != null
                    ? PSColors.secondary.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_rounded,
                    size: 14,
                    color: examType != null
                        ? PSColors.secondary
                        : PSColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  examType ?? 'No exam selected',
                  style: TextStyle(
                      fontFamily: _fontBody,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: examType != null
                          ? PSColors.secondary
                          : PSColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTabs(AnalyticsProvider ap) {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _analyticsTabs,
                    labelStyle: const TextStyle(
                        fontFamily: _fontBody,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(
                        fontFamily: _fontBody,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    labelColor: Colors.white,
                    unselectedLabelColor: PSColors.textSecondary,
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [PSColors.primary, Color(0xFF9C6FFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                            color: PSColors.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Subjects'),
                      Tab(text: 'Rank'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (ap.isLoading)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: PSColors.primary))
              else
                GestureDetector(
                  onTap: () => _loadAnalytics(force: true),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.refresh_rounded,
                        color: PSColors.textSecondary, size: 18),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (ap.state == AnalyticsState.loading && ap.summary == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: _PSLoader(message: 'Loading analytics…'),
            )
          else if (ap.state == AnalyticsState.error && ap.summary == null)
            _PSEmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Failed to load',
              subtitle: ap.error,
              action: _PSButton(
                  label: 'Retry', onTap: () => _loadAnalytics(force: true)),
            )
          else
            _buildActiveTabContent(ap),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent(AnalyticsProvider ap) {
    final summary = ap.summary ?? const AnalyticsSummary();
    switch (_analyticsTabs.index) {
      case 1:
        return _SubjectsTabInline(summary: summary);
      case 2:
        return _RankTabInline(ap: ap);
      default:
        return _OverviewTabInline(summary: summary);
    }
  }

  Widget _buildSettingsSection() {
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: _loadingSettingsProfile
          ? const _PSLoader(message: 'Loading profile…')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PSSectionLabel('User ID'),
                const SizedBox(height: 10),
                _FieldShell(
                  child: TextField(
                    controller: _userIdController,
                    style: const TextStyle(
                        fontFamily: _fontBody,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: PSColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'e.g. aspirant2025',
                      hintStyle: TextStyle(
                          fontFamily: _fontBody, color: PSColors.textTertiary),
                      prefixIcon: Icon(Icons.person_outline_rounded,
                          color: PSColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This will be your unique identity on the leaderboard.',
                  style: TextStyle(
                      fontFamily: _fontBody,
                      fontSize: 12,
                      color: PSColors.textSecondary),
                ),
                const SizedBox(height: 22),
                const _PSSectionLabel('Target Exam'),
                const SizedBox(height: 10),
                _FieldShell(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedExam,
                      isExpanded: true,
                      hint: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Select your target exam',
                            style: TextStyle(
                                fontFamily: _fontBody,
                                color: PSColors.textTertiary,
                                fontSize: 15)),
                      ),
                      icon: const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: PSColors.textSecondary),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      dropdownColor: PSColors.card,
                      items: AppConstants.examTypes.map((exam) {
                        return DropdownMenuItem(
                          value: exam,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(exam,
                                style: const TextStyle(
                                    fontFamily: _fontBody,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: PSColors.textPrimary)),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedExam = v),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const _PSSectionLabel('Sound Effects'),
                const SizedBox(height: 10),
                _FieldShell(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          _soundEnabled
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          color: PSColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Answer sound effects',
                            style: TextStyle(
                                fontFamily: _fontBody,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: PSColors.textPrimary),
                          ),
                        ),
                        Switch(
                          value: _soundEnabled,
                          onChanged: _toggleSound,
                          activeThumbColor: PSColors.primary,
                          activeTrackColor:
                              PSColors.primary.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                if (_settingsError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PSColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: PSColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: PSColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_settingsError!,
                              style: const TextStyle(
                                  fontFamily: _fontBody,
                                  color: PSColors.error,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: _savingSettings
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: CircularProgressIndicator(
                                color: PSColors.primary, strokeWidth: 2.5),
                          ),
                        )
                      : _PSButton(
                          label: 'Save',
                          icon: Icons.check_rounded,
                          onTap: _saveSettings),
                ),
              ],
            ),
    );
  }

  Widget _buildSignOutButton(BuildContext context, AuthProvider auth) {
    return GestureDetector(
      onTap: () => _confirmSignOut(context, auth),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: PSColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PSColors.error.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: PSColors.error, size: 18),
            SizedBox(width: 10),
            Text('Sign Out',
                style: TextStyle(
                    fontFamily: _fontBody,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: PSColors.error)),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? glowColor;

  const _GlassCard(
      {required this.child,
      this.padding = const EdgeInsets.all(16),
      this.glowColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: glowColor != null
            ? [
                BoxShadow(
                    color: glowColor!.withValues(alpha: 0.12),
                    blurRadius: 30,
                    spreadRadius: -4)
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: PSColors.card.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.03),
                  Colors.transparent,
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

class _FieldShell extends StatelessWidget {
  final Widget child;
  const _FieldShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: child,
    );
  }
}

class _PSSectionLabel extends StatelessWidget {
  final String label;
  const _PSSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
          fontFamily: _fontBody,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: PSColors.textTertiary,
          letterSpacing: 0.8),
    );
  }
}

class _PSButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const _PSButton({required this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [PSColors.primary, Color(0xFF9C6FFF)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: PSColors.primary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: const TextStyle(
                      fontFamily: _fontHeading,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PSBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _PSBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35))),
      child: Text(label,
          style: TextStyle(
              fontFamily: _fontBody,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

class _PSLoader extends StatelessWidget {
  final String message;
  const _PSLoader({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
              color: PSColors.primary, strokeWidth: 2.5),
          const SizedBox(height: 14),
          Text(message,
              style: const TextStyle(
                  fontFamily: _fontBody,
                  fontSize: 13,
                  color: PSColors.textSecondary)),
        ],
      ),
    );
  }
}

class _PSEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const _PSEmptyState(
      {required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: PSColors.textTertiary),
            ),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: _fontHeading,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: PSColors.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: _fontBody,
                      fontSize: 13,
                      color: PSColors.textSecondary,
                      height: 1.5)),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String letter;
  const _AvatarFallback({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(letter,
          style: const TextStyle(
              fontFamily: _fontHeading,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: PSColors.primary)),
    );
  }
}

class _NotAuthView extends StatelessWidget {
  final VoidCallback onSignIn;
  const _NotAuthView({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return _PSEmptyState(
      icon: Icons.person_outline_rounded,
      title: 'Not signed in',
      subtitle: 'Sign in to view your profile.',
      action: _PSButton(
          label: 'Sign In', icon: Icons.login_rounded, onTap: onSignIn),
    );
  }
}

class _OverviewTabInline extends StatelessWidget {
  final AnalyticsSummary summary;
  const _OverviewTabInline({required this.summary});

  String _formatTime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    if (summary.totalAttempted == 0) {
      return const _PSEmptyState(
        icon: Icons.quiz_outlined,
        title: 'No questions attempted yet',
        subtitle:
            'Start practicing in the Home tab and\nyour stats will appear here.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GlassCard(
          glowColor: PSColors.primary,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [PSColors.primary, Color(0xFF9C6FFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${summary.currentStreak} Day Streak 🔥',
                        style: const TextStyle(
                            fontFamily: _fontHeading,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: PSColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Best: ${summary.longestStreak} days',
                        style: const TextStyle(
                            fontFamily: _fontBody,
                            fontSize: 13,
                            color: PSColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _PSSectionLabel('Performance'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _MetricTile(
                value: summary.totalAttempted.toString(),
                label: 'Attempted',
                accentColor: PSColors.primary,
                icon: Icons.quiz_outlined),
            _MetricTile(
                value: '${summary.overallAccuracy.toStringAsFixed(1)}%',
                label: 'Accuracy',
                accentColor: PSColors.success,
                icon: Icons.percent_rounded),
            _MetricTile(
                value: summary.totalCorrect.toString(),
                label: 'Correct',
                accentColor: PSColors.success,
                icon: Icons.check_circle_outline),
            _MetricTile(
                value: summary.totalIncorrect.toString(),
                label: 'Incorrect',
                accentColor: PSColors.error,
                icon: Icons.cancel_outlined),
            _MetricTile(
                value: summary.totalSkipped.toString(),
                label: 'Skipped',
                accentColor: PSColors.secondary,
                icon: Icons.skip_next_outlined),
            _MetricTile(
                value: _formatTime(summary.avgResponseTimeSeconds.toInt()),
                label: 'Avg Time/Q',
                accentColor: PSColors.cyan,
                icon: Icons.timer_outlined),
          ],
        ),
        const SizedBox(height: 20),
        const _PSSectionLabel('Accuracy Breakdown'),
        const SizedBox(height: 12),
        _GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _AccuracyBar(
                  label: 'Correct',
                  value: summary.totalCorrect,
                  total: summary.totalAttempted,
                  color: PSColors.success),
              const SizedBox(height: 12),
              _AccuracyBar(
                  label: 'Incorrect',
                  value: summary.totalIncorrect,
                  total: summary.totalAttempted,
                  color: PSColors.error),
              const SizedBox(height: 12),
              _AccuracyBar(
                  label: 'Skipped',
                  value: summary.totalSkipped,
                  total: summary.totalAttempted,
                  color: PSColors.secondary),
            ],
          ),
        ),
        if (summary.totalStudyTimeSeconds > 0) ...[
          const SizedBox(height: 20),
          const _PSSectionLabel('Study Time'),
          const SizedBox(height: 12),
          _GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: PSColors.cyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.access_time_rounded,
                      color: PSColors.cyan, size: 22),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_formatTime(summary.totalStudyTimeSeconds),
                        style: const TextStyle(
                            fontFamily: _fontHeading,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: PSColors.textPrimary)),
                    const Text('Total study time',
                        style: TextStyle(
                            fontFamily: _fontBody,
                            fontSize: 12,
                            color: PSColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (summary.performanceTrend.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _PSSectionLabel('Performance Trend'),
          const SizedBox(height: 12),
          _GlassCard(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: _TrendChart(trend: summary.performanceTrend),
          ),
        ],
        if (summary.strongSubjects.isNotEmpty ||
            summary.weakSubjects.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _PSSectionLabel('Subject Insights'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _SubjectGroup(
                      title: 'Strong',
                      subjects: summary.strongSubjects,
                      color: PSColors.success,
                      icon: Icons.trending_up_rounded)),
              const SizedBox(width: 12),
              Expanded(
                  child: _SubjectGroup(
                      title: 'Weak',
                      subjects: summary.weakSubjects,
                      color: PSColors.error,
                      icon: Icons.trending_down_rounded)),
            ],
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String value;
  final String label;
  final Color accentColor;
  final IconData icon;

  const _MetricTile(
      {required this.value,
      required this.label,
      required this.accentColor,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 16, color: accentColor),
          ),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontFamily: _fontHeading,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: PSColors.textPrimary)),
          Text(label,
              style: const TextStyle(
                  fontFamily: _fontBody,
                  fontSize: 11.5,
                  color: PSColors.textSecondary)),
        ],
      ),
    );
  }
}

class _AccuracyBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _AccuracyBar(
      {required this.label,
      required this.value,
      required this.total,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? value / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontFamily: _fontBody,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: PSColors.textSecondary)),
            ]),
            Text('$value (${(pct * 100).toStringAsFixed(1)}%)',
                style: const TextStyle(
                    fontFamily: _fontBody,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PSColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _SubjectGroup extends StatelessWidget {
  final String title;
  final List<String> subjects;
  final Color color;
  final IconData icon;

  const _SubjectGroup(
      {required this.title,
      required this.subjects,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.22))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    fontFamily: _fontBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 8),
          if (subjects.isEmpty)
            const Text('Not enough data yet',
                style: TextStyle(
                    fontFamily: _fontBody,
                    fontSize: 11,
                    color: PSColors.textTertiary))
          else
            ...subjects.map((s) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $s',
                      style: const TextStyle(
                          fontFamily: _fontBody,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: PSColors.textPrimary)),
                )),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> trend;
  const _TrendChart({required this.trend});

  @override
  Widget build(BuildContext context) {
    if (trend.length < 2) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text('Need more data to show trend',
              style: TextStyle(
                  fontFamily: _fontBody,
                  color: PSColors.textSecondary,
                  fontSize: 13)),
        ),
      );
    }
    final values =
        trend.map((e) => (e['accuracy'] as num?)?.toDouble() ?? 0.0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 140,
          child:
              CustomPaint(painter: _LinePainter(values), size: Size.infinite),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(trend.first['date']?.toString() ?? '',
                style: const TextStyle(
                    fontFamily: _fontBody,
                    fontSize: 10,
                    color: PSColors.textTertiary)),
            Text(trend.last['date']?.toString() ?? '',
                style: const TextStyle(
                    fontFamily: _fontBody,
                    fontSize: 10,
                    color: PSColors.textTertiary)),
          ],
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  const _LinePainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxVal = values.reduce(max);
    final minVal = values.reduce(min);
    final range = max(maxVal - minVal, 1.0);
    double toX(int i) => (i / (values.length - 1)) * size.width;
    double toY(double v) =>
        size.height -
        ((v - minVal) / range) * size.height * 0.8 -
        size.height * 0.1;

    final fillPath = Path()..moveTo(toX(0), size.height);
    for (int i = 0; i < values.length; i++) {
      fillPath.lineTo(toX(i), toY(values[i]));
    }
    fillPath.lineTo(toX(values.length - 1), size.height);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            PSColors.primary.withValues(alpha: 0.22),
            PSColors.primary.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    final linePath = Path()..moveTo(toX(0), toY(values[0]));
    for (int i = 1; i < values.length; i++) {
      final prev = Offset(toX(i - 1), toY(values[i - 1]));
      final curr = Offset(toX(i), toY(values[i]));
      final cp = Offset((prev.dx + curr.dx) / 2, prev.dy);
      final cp2 = Offset((prev.dx + curr.dx) / 2, curr.dy);
      linePath.cubicTo(cp.dx, cp.dy, cp2.dx, cp2.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = PSColors.primary
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    for (int i = 0; i < values.length; i++) {
      canvas.drawCircle(Offset(toX(i), toY(values[i])), 3.8,
          Paint()..color = PSColors.primary);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.values != values;
}

class _SubjectsTabInline extends StatelessWidget {
  final AnalyticsSummary summary;
  const _SubjectsTabInline({required this.summary});

  @override
  Widget build(BuildContext context) {
    final subjects = summary.subjectAccuracy;
    if (subjects.isEmpty) {
      return const _PSEmptyState(
        icon: Icons.book_outlined,
        title: 'No subject data yet',
        subtitle: 'Attempt more questions to\nsee subject-wise breakdown.',
      );
    }
    final sorted = List<Map<String, dynamic>>.from(subjects)
      ..sort((a, b) =>
          (b['attempted'] as num? ?? 0).compareTo(a['attempted'] as num? ?? 0));

    return Column(
      children: sorted.map((s) {
        final key = s['key']?.toString() ?? '';
        final attempted = (s['attempted'] as num?)?.toInt() ?? 0;
        final correct = (s['correct'] as num?)?.toInt() ?? 0;
        final accuracy = (s['accuracy'] as num?)?.toDouble() ?? 0;
        final color = accuracy >= 70
            ? PSColors.success
            : accuracy >= 40
                ? PSColors.secondary
                : PSColors.error;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.06))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(key,
                          style: const TextStyle(
                              fontFamily: _fontHeading,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: PSColors.textPrimary))),
                  _PSBadge(
                      label: '${accuracy.toStringAsFixed(0)}%', color: color),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (accuracy / 100).clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Text('$attempted attempted',
                      style: const TextStyle(
                          fontFamily: _fontBody,
                          fontSize: 12,
                          color: PSColors.textSecondary)),
                  const SizedBox(width: 12),
                  Text('$correct correct',
                      style: const TextStyle(
                          fontFamily: _fontBody,
                          fontSize: 12,
                          color: PSColors.success)),
                  const SizedBox(width: 12),
                  Text('${attempted - correct} incorrect',
                      style: const TextStyle(
                          fontFamily: _fontBody,
                          fontSize: 12,
                          color: PSColors.error)),
                ]),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RankTabInline extends StatefulWidget {
  final AnalyticsProvider ap;
  const _RankTabInline({required this.ap});

  @override
  State<_RankTabInline> createState() => _RankTabInlineState();
}

class _RankTabInlineState extends State<_RankTabInline> {
  bool _rankLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_rankLoaded) {
        _rankLoaded = true;
        widget.ap.loadRank();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AnalyticsProvider>();
    final auth = context.read<AuthProvider>();

    final rankData = ap.rankData;
    final leaderboard = ap.leaderboardData;

    if (rankData == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: _PSLoader(message: 'Loading rank…'),
      );
    }

    final hasRank = rankData['hasRank'] == true;
    final topList = (leaderboard?['leaderboard'] as List<dynamic>?) ?? [];
    final totalParticipants =
        rankData['totalParticipants'] ?? leaderboard?['totalParticipants'] ?? 0;

    final myUserID = auth.userProfile?.userID ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasRank) ...[
          _GlassCard(
            glowColor: PSColors.secondary,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.military_tech_rounded,
                    color: PSColors.secondary, size: 48),
                const SizedBox(height: 12),
                Text('#${rankData['rank']}',
                    style: const TextStyle(
                        fontFamily: _fontHeading,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: PSColors.secondary)),
                const Text('Your Rank',
                    style: TextStyle(
                        fontFamily: _fontBody,
                        fontSize: 14,
                        color: PSColors.textSecondary)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RankStat(
                        label: 'Total Marks',
                        value: (rankData['totalMarks'] as num?)
                                ?.toStringAsFixed(1) ??
                            '0',
                        color: PSColors.success),
                    _RankStat(
                        label: 'Correct',
                        value: '${rankData['totalCorrect'] ?? 0}',
                        color: PSColors.primary),
                    _RankStat(
                        label: 'Percentile',
                        value: '${rankData['percentile'] ?? 0}%',
                        color: PSColors.cyan),
                  ],
                ),
                const SizedBox(height: 8),
                Text('out of $totalParticipants participants',
                    style: const TextStyle(
                        fontFamily: _fontBody,
                        fontSize: 12,
                        color: PSColors.textTertiary)),
              ],
            ),
          ),
        ] else ...[
          const _PSEmptyState(
            icon: Icons.military_tech_rounded,
            title: 'No rank yet',
            subtitle: 'Submit your first answer to appear\non the leaderboard.',
          ),
        ],
        if (topList.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _PSSectionLabel('Top Performers'),
          const SizedBox(height: 12),
          ...topList.asMap().entries.map((e) {
            final index = e.key;
            final user = e.value as Map<String, dynamic>;

            final entryUserID = user['userID']?.toString() ?? '';
            final entryName = user['name']?.toString() ?? '';
            final rankNum = user['rank'] ?? (index + 1);
            final marks =
                (user['totalMarks'] as num?)?.toStringAsFixed(1) ?? '0';

            final isYou = myUserID.isNotEmpty && entryUserID == myUserID;

            final rawLabel = entryName.isNotEmpty
                ? entryName
                : entryUserID.isNotEmpty
                    ? entryUserID
                    : 'anonymous';

            final displayLabel = isYou
                ? '$rawLabel (You)'
                : rawLabel.length > 16
                    ? '${rawLabel.substring(0, 16)}…'
                    : rawLabel;

            Color rankColor = PSColors.textSecondary;
            if (rankNum == 1) rankColor = const Color(0xFFFFD700);
            if (rankNum == 2) rankColor = const Color(0xFFC0C0C0);
            if (rankNum == 3) rankColor = const Color(0xFFCD7F32);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isYou
                      ? PSColors.primary.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isYou
                          ? PSColors.primary.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text('#$rankNum',
                          style: TextStyle(
                              fontFamily: _fontHeading,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: rankColor)),
                    ),
                    Expanded(
                      child: Text(displayLabel,
                          style: TextStyle(
                              fontFamily: _fontBody,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isYou
                                  ? PSColors.primary
                                  : PSColors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('$marks pts',
                        style: const TextStyle(
                            fontFamily: _fontHeading,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: PSColors.textPrimary)),
                  ],
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _RankStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RankStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontFamily: _fontHeading,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontFamily: _fontBody,
                fontSize: 11,
                color: PSColors.textSecondary)),
      ],
    );
  }
}
