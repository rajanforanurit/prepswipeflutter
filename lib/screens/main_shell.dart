import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepswipe/models/question_model.dart';
import 'package:prepswipe/providers/quiz_provider.dart';
import 'package:prepswipe/screens/community/community_lobby_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import 'home_screen.dart';
import 'opennews_screen.dart';
import 'revision_screen.dart';
import 'profile_screen.dart';

class PrepSwipeTitle extends StatelessWidget {
  final String tabName;

  const PrepSwipeTitle({super.key, required this.tabName});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Prep',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
              TextSpan(
                text: 'Swipe',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFFD700),
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '| $tabName',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    const HomeScreen(),
    const CommunityLobbyScreen(),
    const RevisionScreen(),
    const OpenNewsScreen(),
    const ProfileScreen(),
  ];

  static const List<String> _tabNames = [
    'Home',
    'Community',
    'Revision',
    'News',
    'Profile',
  ];

  @override
  initState() {
    loadSettings();
    super.initState();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String language = prefs.getString('language') ?? 'english';
    await Provider.of<QuizProvider>(context, listen: false).setLanguage(
      language == 'english' ? AppLanguage.english : AppLanguage.hindi,
    );
  }

  void _onTabTap(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrepSwipeTitle(tabName: _tabNames[_currentIndex]),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      const _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
      ),
      const _NavItem(
        icon: Icons.diversity_3_outlined,
        activeIcon: Icons.diversity_3_rounded,
        label: 'Community',
      ),
      const _NavItem(
        icon: Icons.bookmark_outline_rounded,
        activeIcon: Icons.bookmark_rounded,
        label: 'Revision',
      ),
      const _NavItem(
        icon: Icons.newspaper_outlined,
        activeIcon: Icons.newspaper_rounded,
        label: 'News',
      ),
      const _NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile',
      ),
    ];

    final bottomSafePadding = MediaQuery.paddingOf(context).bottom;

    return Padding(
        padding: EdgeInsets.fromLTRB(
          16, // Left floating spacing
          0,
          16, // Right floating spacing
          bottomSafePadding > 0
              ? bottomSafePadding + 5
              : 5, // Elegantly floats above the bottom edge [1]
        ),
        child: ClipRRect(
          borderRadius: BorderRadiusGeometry.circular(
              24), //const BorderRadius.vertical(top: Radius.circular(18)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card.withValues(alpha: 0.55),
                border: Border.all(color: Colors.white10),
                borderRadius: BorderRadius.circular(24),
                // border: const Border(
                //   top: BorderSide(color: Colors.white12, width: 1),
                // ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: items.asMap().entries.map((e) {
                    final i = e.key;
                    final item = e.value;
                    final isActive = currentIndex == i;

                    return GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          // border: isActive
                          //     ? Border.all(
                          //         color: AppColors.accent.withValues(alpha: 0.3),
                          //         width: 1,
                          //       )
                          //     : null,
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isActive ? item.activeIcon : item.icon,
                              size: 18,
                              color: Colors.white
                                  .withValues(alpha: isActive ? 1.0 : 0.6),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                color: Colors.white
                                    .withValues(alpha: isActive ? 1.0 : 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ));
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
