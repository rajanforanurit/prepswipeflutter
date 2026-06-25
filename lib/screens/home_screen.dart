import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/quiz_screen.dart';
import '../utils/app_theme.dart';
import '../widgets/ps_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Still loading Firebase auth state on first frame
    if (auth.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: PSLoader(message: ''),
      );
    }

    // Not signed in — show isolated login page
    if (!auth.isAuthenticated) {
      return const LoginPage();
    }

    final profile = auth.userProfile;
    final onboardingDone = profile != null && profile.profileComplete;

    if (!onboardingDone) {
      return OnboardingScreen(
        onCompleted: () async {
          // This is the ONLY place AuthProvider is touched for refresh.
          // OnboardingScreen has no provider dependency at all.
          await auth.refreshProfile();
        },
      );
    }

    // Fully set-up user — hand off to QuizScreen
    return const QuizScreen();
  }
}
