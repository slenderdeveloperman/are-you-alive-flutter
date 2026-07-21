import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/eulogy_screen.dart';
import 'screens/home_screen.dart';
import 'services/app_open_tracker_service.dart';
import 'services/badge_service.dart';
import 'services/metrics_schema_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MetricsSchemaService().ensureCurrent();
  await NotificationService().init();
  runApp(const AreYouAliveApp());
}

class AreYouAliveApp extends StatelessWidget {
  const AreYouAliveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Are You Alive?',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: const AppRouter(),
    );
  }
}

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> with WidgetsBindingObserver {
  bool _showSplash = true;
  bool _isLoading = true;
  bool _wasInBackground = false;

  // Navigation state flags
  bool _hasCompletedOnboarding = false;
  bool _hasSeenOnboarding = false;
  bool _hasDied = false;

  // Data for eulogy screen
  String _userName = 'human';
  int _deathStreakCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _trackAppOpen();
    _checkNavigationStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _wasInBackground = true;
      return;
    }

    if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      _trackAppOpen();
      _checkNavigationStatus();
    }
  }

  Future<void> _trackAppOpen() async {
    await AppOpenTrackerService().recordOpen(now: DateTime.now());
  }

  Future<void> _checkNavigationStatus() async {
    final prefs = await SharedPreferences.getInstance();

    final hasCompleted = prefs.getBool('hasCompletedOnboarding') ?? false;
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    final userName = prefs.getString('userName') ?? 'human';

    // Check if user has died (timer expired)
    bool hasDied = prefs.getBool('hasDied') ?? false;
    int deathStreakCount = prefs.getInt('deathStreakCount') ?? 0;

    // Check if timer has expired (only if user hasn't already been marked as dead)
    if (!hasDied && hasCompleted) {
      final lastActiveTimestamp = prefs.getInt('lastActiveTimestamp');
      if (lastActiveTimestamp != null) {
        final elapsed =
            DateTime.now().millisecondsSinceEpoch - lastActiveTimestamp;
        final expired = elapsed >= const Duration(hours: 39).inMilliseconds;

        if (expired) {
          // User has died - save death state
          hasDied = true;
          deathStreakCount = prefs.getInt('streakCount') ?? 0;
          await prefs.setBool('hasDied', true);
          await prefs.setInt('deathStreakCount', deathStreakCount);
          await BadgeService().recordDeathEvent(now: DateTime.now());
        }
      }
    }

    setState(() {
      _hasCompletedOnboarding = hasCompleted;
      _hasSeenOnboarding = hasSeenOnboarding;
      _hasDied = hasDied;
      _userName = userName;
      _deathStreakCount = deathStreakCount;
      _isLoading = false;
    });
  }

  void _onSplashComplete() {
    setState(() {
      _showSplash = false;
    });
  }

  void _onWelcomeComplete() {
    setState(() {
      _hasCompletedOnboarding = true;
    });
  }

  Future<void> _onOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    setState(() {
      _hasSeenOnboarding = true;
    });
  }

  Future<void> _onRiseAgain() async {
    final prefs = await SharedPreferences.getInstance();

    // Reset all death-related state
    await prefs.setInt('streakCount', 0);
    await prefs.setString('lastCheckInDate', '');
    await prefs.setBool('hasDied', false);
    await prefs.setInt('checkInsSinceDeath', 0); // Start healing process

    // Schedule fresh notification
    await NotificationService().scheduleInactivityNotification();

    setState(() {
      _hasDied = false;
    });
  }

  /// Returns a unique key for the current screen to trigger AnimatedSwitcher transitions.
  String _getScreenKey() {
    if (!_hasCompletedOnboarding) return 'welcome';
    if (!_hasSeenOnboarding) return 'onboarding';
    if (_hasDied) return 'eulogy';
    return 'home';
  }

  /// Determines which screen to show based on navigation state.
  Widget _buildCurrentScreen() {
    // Flow 1: User hasn't entered name yet
    if (!_hasCompletedOnboarding) {
      return WelcomeScreen(onComplete: _onWelcomeComplete);
    }

    // Flow 2: User hasn't seen onboarding explanation
    if (!_hasSeenOnboarding) {
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }

    // Flow 3: User has died (timer expired)
    if (_hasDied) {
      return EulogyScreen(
        userName: _userName,
        deathStreakCount: _deathStreakCount,
        onRiseAgain: _onRiseAgain,
      );
    }

    // Flow 4: Normal home screen
    return const HomeScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show splash screen first
    if (_showSplash) {
      return SplashScreen(onComplete: _onSplashComplete);
    }

    // Show loading spinner while checking status
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    // Use AnimatedSwitcher with custom transitions for screen changes
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_getScreenKey()),
        child: _buildCurrentScreen(),
      ),
    );
  }
}
