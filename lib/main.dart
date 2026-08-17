import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:prepswipe/providers/community_quiz_provider.dart';
import 'package:prepswipe/providers/timeline_settings_provider.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/quiz_provider.dart';
import 'providers/analytics_provider.dart';
import 'screens/main_shell.dart';
import 'screens/login_screen.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await MobileAds.instance.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const PrepSwipeApp());
}

class PrepSwipeApp extends StatelessWidget {
  const PrepSwipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
        ChangeNotifierProvider(
          create: (_) => TimelineSettingsProvider()..load(),
        ),
      ],
      child: MaterialApp(
        title: 'PrepSwipe',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _AppRoot(),
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: SizedBox.shrink(),
      );
    }

    FlutterNativeSplash.remove();

    if (!auth.isAuthenticated) {
      return const LoginPage();
    }

    return const MainShell();
  }
}
