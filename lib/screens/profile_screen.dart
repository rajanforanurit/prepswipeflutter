import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lottie/lottie.dart';
import 'package:prepswipe/models/question_model.dart';
import 'package:prepswipe/utils/app_theme.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/analytics_provider.dart';
import '../providers/quiz_provider.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// Required imports for loading the initial timeline configuration
import 'package:prepswipe/providers/timeline_settings_provider.dart';
import 'package:prepswipe/Timeline/feed_repository.dart';

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
  @override
  void initState() {
    super.initState();
    _analyticsTabs = TabController(length: 3, vsync: this);
    _analyticsTabs.addListener(_onAnalyticsTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProfile();
      _loadAnalytics();
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
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _fetchProfile(),
      _loadAnalytics(force: true),
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
            padding: EdgeInsets.fromLTRB(
                MediaQuery.of(context).size.width < 360 ? 14.0 : 20.0,
                10,
                MediaQuery.of(context).size.width < 360 ? 14.0 : 20.0,
                0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildProfileHeader(context, auth),
                const SizedBox(height: 12),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: _buildAnalyticsTabs(ap),
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
            textScaler: MediaQuery.textScalerOf(context),
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

    final userId = _profile?['userID']?.toString() ?? '';
    final examType = _profile?['examType']?.toString();
    final avatarLetter =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    final width = MediaQuery.of(context).size.width;
    bool small = width < 400;

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
      child: Row(
        children: [
          Container(
            width: small ? 50 : 60,
            height: small ? 50 : 60,
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
          const SizedBox(width: 18),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                small
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName,
                              style: const TextStyle(
                                  fontFamily: _fontHeading,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: PSColors.textPrimary,
                                  letterSpacing: -0.3),
                              textAlign: TextAlign.center),
                          Text("@$userId",
                              style: const TextStyle(
                                  fontFamily: _fontHeading,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: PSColors.textSecondary,
                                  letterSpacing: -0.3),
                              textAlign: TextAlign.center),
                        ],
                      )
                    : Row(
                        children: [
                          Text(displayName,
                              style: const TextStyle(
                                  fontFamily: _fontHeading,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: PSColors.textPrimary,
                                  letterSpacing: -0.3),
                              textAlign: TextAlign.center),
                          Text(" | @$userId",
                              style: const TextStyle(
                                  fontFamily: _fontHeading,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: PSColors.textSecondary,
                                  letterSpacing: -0.3),
                              textAlign: TextAlign.center),
                        ],
                      ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                          size: 12,
                          color: examType != null
                              ? PSColors.secondary
                              : PSColors.textTertiary),
                      const SizedBox(width: 6),
                      Text(
                        examType ?? 'No exam selected',
                        style: TextStyle(
                            fontFamily: _fontBody,
                            fontSize: small ? 10 : 11,
                            fontWeight: FontWeight.w600,
                            color: examType != null
                                ? PSColors.secondary
                                : PSColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ])),
          InkWell(
            child: GestureDetector(
              onTap: () => showModalBottomSheet(
                  context: context,
                  isDismissible: true,
                  isScrollControlled: true,
                  builder: (context) => SettingsBottomSheet(
                        sectiontitle: _sectionTitle('Settings',
                            Icons.settings_rounded, PSColors.secondary),
                        signoutbutton: _buildSignOutButton(context, auth),
                      )),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.textSecondary.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.settings_rounded,
                    size: 18, color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTabs(AnalyticsProvider ap) {
    return GlassCard(
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
                  constraints: const BoxConstraints.expand(height: 33.0),
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
                      borderRadius: BorderRadius.circular(10),
                      border: BoxBorder.all(color: PSColors.primary),
                      boxShadow: [
                        BoxShadow(
                            color: PSColors.primary.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: const Color.fromRGBO(0, 0, 0, 0),
                    tabs: const [
                      Tab(
                        text: 'Overview',
                      ),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, color: PSColors.error, size: 18),
            const SizedBox(width: 10),
            Text('Sign Out',
                textScaler: MediaQuery.textScalerOf(context),
                style: const TextStyle(
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

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? glowColor;

  const GlassCard(
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
    final small = MediaQuery.of(context).size.width < 360;
    return Text(
      label.toUpperCase(),
      textScaler: MediaQuery.textScalerOf(context),
      style: TextStyle(
          fontFamily: _fontBody,
          fontSize: small ? 9.5 : 11.5,
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
                  textScaler: MediaQuery.textScalerOf(context),
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
          textScaler: MediaQuery.textScalerOf(context),
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
              textScaler: MediaQuery.textScalerOf(context),
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
                textScaler: MediaQuery.textScalerOf(context),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: _fontHeading,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: PSColors.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textScaler: MediaQuery.textScalerOf(context),
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
          textScaler: MediaQuery.textScalerOf(context),
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color.fromARGB(255, 178, 77, 255)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                SizedBox(
                    width: 50,
                    height: 50,
                    child: LottieBuilder.asset(
                        "assets/animatedicons/Streak Fire.json")),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${summary.currentStreak} Day Streak 🔥',
                          textScaler: MediaQuery.textScalerOf(context),
                          style: const TextStyle(
                              fontFamily: _fontHeading,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: PSColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Best: ${summary.longestStreak} days',
                          textScaler: MediaQuery.textScalerOf(context),
                          style: const TextStyle(
                              fontFamily: _fontBody,
                              fontSize: 11,
                              color: PSColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const _PSSectionLabel('Performance'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CircularProgress(
                  value: summary.overallAccuracy,
                  total: 100,
                  insidetext: "${summary.overallAccuracy.toInt()}%",
                  label: "Accuracy",
                  accentColor: AppColors.accent),
              const SizedBox(height: 10),
              _CircularProgress(
                  value: summary.totalCorrect.toDouble(),
                  total: summary.totalAttempted.toDouble(),
                  insidetext: summary.totalCorrect.toString(),
                  label: "Correct",
                  accentColor: PSColors.success),
              const SizedBox(height: 10),
              _CircularProgress(
                  value: summary.totalIncorrect.toDouble(),
                  total: summary.totalAttempted.toDouble(),
                  insidetext: summary.totalIncorrect.toString(),
                  label: "Incorrect",
                  accentColor: PSColors.error),
            ],
          ),
        ),
        const SizedBox(
          height: 10,
        ),
        Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
              color: PSColors.card.withValues(alpha: 0.6)),
          child: ClipRRect(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                                color: PSColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(9)),
                            child: const Icon(Icons.quiz_outlined,
                                size: 16, color: PSColors.primary),
                          ),
                          const SizedBox(width: 8),
                          Text("Attempted",
                              textScaler: MediaQuery.textScalerOf(context),
                              style: const TextStyle(
                                  fontFamily: _fontBody,
                                  fontSize: 13,
                                  color: PSColors.textSecondary)),
                        ],
                      ),
                      Text(summary.totalAttempted.toString(),
                          textScaler: MediaQuery.textScalerOf(context),
                          style: const TextStyle(
                              fontFamily: _fontHeading,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: PSColors.textPrimary)),
                    ],
                  ),
                ),
                const Divider(
                  color: AppColors.cardBorder,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 5, 15, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                                color:
                                    AppColors.secondary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(9)),
                            child: const Icon(Icons.skip_next_outlined,
                                size: 16, color: AppColors.secondary),
                          ),
                          const SizedBox(width: 8),
                          Text("Skipped",
                              textScaler: MediaQuery.textScalerOf(context),
                              style: const TextStyle(
                                  fontFamily: _fontBody,
                                  fontSize: 13,
                                  color: PSColors.textSecondary)),
                        ],
                      ),
                      Text(summary.totalSkipped.toString(),
                          textScaler: MediaQuery.textScalerOf(context),
                          style: const TextStyle(
                              fontFamily: _fontHeading,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: PSColors.textPrimary)),
                    ],
                  ),
                ),
                const Divider(
                  color: AppColors.cardBorder,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 5, 15, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                                color: PSColors.cyan.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(9)),
                            child: const Icon(Icons.timer_outlined,
                                size: 16, color: PSColors.cyan),
                          ),
                          const SizedBox(width: 8),
                          Text("Avg Time/Q",
                              textScaler: MediaQuery.textScalerOf(context),
                              style: const TextStyle(
                                  fontFamily: _fontBody,
                                  fontSize: 13,
                                  color: PSColors.textSecondary)),
                        ],
                      ),
                      Text(_formatTime(summary.avgResponseTimeSeconds.toInt()),
                          textScaler: MediaQuery.textScalerOf(context),
                          style: const TextStyle(
                              fontFamily: _fontHeading,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: PSColors.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        if (summary.totalStudyTimeSeconds > 0) ...[
          const SizedBox(height: 15),
          const _PSSectionLabel('Study Time'),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
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
                        textScaler: MediaQuery.textScalerOf(context),
                        style: const TextStyle(
                            fontFamily: _fontHeading,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: PSColors.textPrimary)),
                    Text('Total study time',
                        textScaler: MediaQuery.textScalerOf(context),
                        style: const TextStyle(
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
          GlassCard(
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

class _CircularProgress extends StatelessWidget {
  final double value;
  final double total;
  final String insidetext;
  final String label;
  final Color accentColor;
  const _CircularProgress(
      {required this.value,
      required this.label,
      required this.accentColor,
      required this.total,
      required this.insidetext});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? value / total : 0.0;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: pct,
                strokeWidth: 6.0,
                backgroundColor: accentColor.withValues(alpha: 0.4),
                strokeCap: StrokeCap.round,
                color: Colors.white,
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
            Text(
              insidetext,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: PSColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontFamily: _fontHeading,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        )
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
                textScaler: MediaQuery.textScalerOf(context),
                style: TextStyle(
                    fontFamily: _fontBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 8),
          if (subjects.isEmpty)
            Text('Not enough data yet',
                textScaler: MediaQuery.textScalerOf(context),
                style: const TextStyle(
                    fontFamily: _fontBody,
                    fontSize: 11,
                    color: PSColors.textTertiary))
          else
            ...subjects.map((s) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $s',
                      textScaler: MediaQuery.textScalerOf(context),
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
      return SizedBox(
        height: 100,
        child: Center(
          child: Text('Need more data to show trend',
              textScaler: MediaQuery.textScalerOf(context),
              style: const TextStyle(
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
                textScaler: MediaQuery.textScalerOf(context),
                style: const TextStyle(
                    fontFamily: _fontBody,
                    fontSize: 10,
                    color: PSColors.textTertiary)),
            Text(trend.last['date']?.toString() ?? '',
                textScaler: MediaQuery.textScalerOf(context),
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
            padding: const EdgeInsets.all(10),
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
                          textScaler: MediaQuery.textScalerOf(context),
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
                      textScaler: MediaQuery.textScalerOf(context),
                      style: const TextStyle(
                          fontFamily: _fontBody,
                          fontSize: 12,
                          color: PSColors.textSecondary)),
                  const SizedBox(width: 12),
                  Text('$correct correct',
                      textScaler: MediaQuery.textScalerOf(context),
                      style: const TextStyle(
                          fontFamily: _fontBody,
                          fontSize: 12,
                          color: PSColors.success)),
                  const SizedBox(width: 12),
                  Text('${attempted - correct} incorrect',
                      textScaler: MediaQuery.textScalerOf(context),
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
  final GlobalKey _shareCardKey = GlobalKey();

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

  Future<void> _shareRankCard(Map<String, dynamic> rankData) async {
    try {
      final boundary = _shareCardKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;

      final image = await boundary.toImage(pixelRatio: 3);

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      final pngBytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();

      final file = File("${dir.path}/prepswipe_rank.png");

      await file.writeAsBytes(pngBytes);

      final rank = rankData["rank"];

      await Share.shareXFiles(
        [XFile(file.path)],
        text: "🏆 I'm ranked #$rank on PrepSwipe!\n\n"
            "Can you beat my rank?\n\n"
            "Boost your UPSC / PSC preparation with AI-powered practice questions, analytics and leaderboards.\n\n"
            "📲 Download PrepSwipe:\n"
            "https://play.google.com/store/apps/details?id=com.anuritinnovation.prepswipe",
      );
    } catch (e) {
      debugPrint(e.toString());
    }
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
          Stack(
            alignment: AlignmentGeometry.bottomRight,
            children: [
              RepaintBoundary(
                key: _shareCardKey,
                child: GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.military_tech_rounded,
                              color: PSColors.secondary, size: 40),
                          const SizedBox(height: 12),
                          Text('#${rankData['rank']}',
                              textScaler: MediaQuery.textScalerOf(context),
                              style: const TextStyle(
                                  fontFamily: _fontHeading,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: PSColors.secondary)),
                        ],
                      ),
                      Text('Your Rank',
                          textScaler: MediaQuery.textScalerOf(context),
                          style: const TextStyle(
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
                          textScaler: MediaQuery.textScalerOf(context),
                          style: const TextStyle(
                              fontFamily: _fontBody,
                              fontSize: 12,
                              color: PSColors.textTertiary)),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => _shareRankCard(rankData),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              AppColors.textSecondary.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.share,
                        size: 18, color: AppColors.textPrimary),
                  ),
                ),
              ),
            ],
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
                          : (rankNum != 1 && rankNum != 2 && rankNum != 3)
                              ? Colors.white.withValues(alpha: 0.06)
                              : rankColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text('#$rankNum',
                          textScaler: MediaQuery.textScalerOf(context),
                          style: TextStyle(
                              fontFamily: _fontHeading,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: rankColor)),
                    ),
                    Expanded(
                      child: Text(displayLabel,
                          textScaler: MediaQuery.textScalerOf(context),
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
                        textScaler: MediaQuery.textScalerOf(context),
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
            textScaler: MediaQuery.textScalerOf(context),
            style: TextStyle(
                fontFamily: _fontHeading,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            textScaler: MediaQuery.textScalerOf(context),
            style: const TextStyle(
                fontFamily: _fontBody,
                fontSize: 11,
                color: PSColors.textSecondary)),
      ],
    );
  }
}

class SettingsBottomSheet extends StatefulWidget {
  final Widget sectiontitle;
  final Widget signoutbutton;

  const SettingsBottomSheet({
    super.key,
    required this.sectiontitle,
    required this.signoutbutton,
  });

  @override
  State<SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends State<SettingsBottomSheet> {
  final _userIdController = TextEditingController();
  bool _loadingSettingsProfile = false;
  String? _selectedExam;
  AppLanguage? _selectedLanguage;
  bool _savingSettings = false;
  bool _soundEnabled = true;
  static const String _soundPrefKey = 'sound_enabled';
  String? _settingsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettingsProfile();
      _loadSoundPreference();
      setState(() {
        _selectedLanguage =
            Provider.of<QuizProvider>(context, listen: false).language;
      });
    });
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
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
    final quizProvider = Provider.of<QuizProvider>(context, listen: false);
    if (userId.isEmpty) {
      setState(() => _settingsError = 'Please enter a User ID');
      return;
    }
    if (_selectedExam == null) {
      setState(() => _settingsError = 'Please select an exam type');
      return;
    }
    if (_selectedLanguage == null) {
      setState(() => _settingsError = 'Please select a language');
      return;
    }
    setState(() {
      _savingSettings = true;
      _settingsError = null;
    });
    try {
      if (_selectedLanguage != quizProvider.language) {
        await quizProvider.setLanguage(_selectedLanguage!);
      }
      await ApiService().updateUserProfile({
        'userID': userId.toLowerCase(),
        'examType': _selectedExam,
      });
      await context.read<AuthProvider>().refreshProfile();
      if (mounted) {
        final settings = Provider.of<TimelineSettingsProvider>(context, listen: false);
        final feeds = await FeedRepository().loadFeed();
        
        await quizProvider.loadInitial(
          _selectedExam!,
          mode: settings.mode,
          feedCards: feeds,
          spacing: settings.spacing,
        );

        setState(() => _savingSettings = false);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settings saved',
                textScaler: MediaQuery.textScalerOf(context),
                style: const TextStyle(fontFamily: 'Inter')),
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

  Future<void> _toggleSound(bool value) async {
    setState(() => _soundEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundPrefKey, value);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 5, 20, 10),
          child: Column(
            children: [
              const SizedBox(height: 20),
              widget.sectiontitle,
              const SizedBox(height: 15),
              _buildSettingsSection(),
              const SizedBox(height: 5),
              widget.signoutbutton,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    final small = MediaQuery.of(context).size.width < 360;

    return _loadingSettingsProfile
        ? const _PSLoader(message: 'Loading settings…')
        : GlassCard(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PSSectionLabel('User ID'),
                const SizedBox(height: 5),
                Container(
                  constraints: const BoxConstraints(maxHeight: 48),
                  child: _FieldShell(
                    child: TextField(
                      controller: _userIdController,
                      style: TextStyle(
                          fontFamily: _fontBody,
                          fontSize: small ? 10 : 12,
                          fontWeight: FontWeight.w500,
                          color: PSColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'e.g. aspirant2025',
                        hintStyle: TextStyle(
                            fontFamily: _fontBody,
                            color: PSColors.textTertiary),
                        prefixIcon: Icon(Icons.person_outline_rounded,
                            color: PSColors.textSecondary, size: 20),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This will be your unique identity on the leaderboard.',
                  textScaler: MediaQuery.textScalerOf(context),
                  style: TextStyle(
                      fontFamily: _fontBody,
                      fontSize: small ? 10 : 12,
                      color: PSColors.textSecondary),
                ),
                const SizedBox(height: 15),
                const _PSSectionLabel('Target Exam'),
                const SizedBox(height: 5),
                Container(
                  constraints: const BoxConstraints(maxHeight: 48),
                  child: _FieldShell(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedExam,
                        isExpanded: true,
                        hint: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Select your target exam',
                              textScaler: MediaQuery.textScalerOf(context),
                              style: const TextStyle(
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(exam,
                                  textScaler: MediaQuery.textScalerOf(context),
                                  style: TextStyle(
                                      fontFamily: _fontBody,
                                      fontSize: small ? 12 : 15,
                                      fontWeight: FontWeight.w500,
                                      color: PSColors.textPrimary)),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedExam = v),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const _PSSectionLabel('Language'),
                const SizedBox(height: 5),
                Container(
                  constraints: const BoxConstraints(maxHeight: 48),
                  child: _FieldShell(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<AppLanguage>(
                        value: _selectedLanguage,
                        isExpanded: true,
                        hint: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Select Preffered Language',
                              textScaler: MediaQuery.textScalerOf(context),
                              style: const TextStyle(
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
                        items: AppLanguage.values.map((language) {
                          return DropdownMenuItem(
                            value: language,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(language.name,
                                  textScaler: MediaQuery.textScalerOf(context),
                                  style: TextStyle(
                                      fontFamily: _fontBody,
                                      fontSize: small ? 12 : 15,
                                      fontWeight: FontWeight.w500,
                                      color: PSColors.textPrimary)),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedLanguage = v),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const _PSSectionLabel('Sound Effects'),
                const SizedBox(height: 5),
                Container(
                  constraints: const BoxConstraints(maxHeight: 45),
                  child: _FieldShell(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            _soundEnabled
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            color: PSColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Answer sound effects',
                              textScaler: MediaQuery.textScalerOf(context),
                              style: TextStyle(
                                  fontFamily: _fontBody,
                                  fontSize: small ? 12 : 15,
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
                ),
                const SizedBox(height: 15),
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
                              textScaler: MediaQuery.textScalerOf(context),
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
}