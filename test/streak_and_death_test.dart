import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:are_you_alive_flutter/main.dart';
import 'package:are_you_alive_flutter/screens/eulogy_screen.dart';
import 'package:are_you_alive_flutter/screens/home_screen.dart';
import 'package:are_you_alive_flutter/screens/onboarding_screen.dart';
import 'package:are_you_alive_flutter/screens/welcome_screen.dart';

Future<void> _tapCheckIn(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('check-in-button')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  // Flush the delayed streak-pop-animation timer started inside
  // _incrementStreakIfNewDay so pending timers don't leak between tests.
  await tester.pump(const Duration(milliseconds: 900));
}

/// HomeScreen's initState kicks off a chain of several sequential awaits
/// (SharedPreferences.getInstance() -> BadgeService().evaluate() ->
/// AppOpenTrackerService().getStats() -> MetricsSchemaService().ensureCurrent()
/// -> more SharedPreferences round-trips) before _hasCheckedIn/_streakCount
/// reach their loaded values. A single `tester.pump(largeDuration)` only
/// advances one frame and does not reliably flush that many chained
/// microtask/await boundaries, so callers must pump multiple discrete times.
Future<void> _settleHome(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// AppRouter always shows SplashScreen first. SplashScreen's spiral
/// animation advances its internal state by real elapsed time (measured via
/// AnimationController.lastElapsedDuration), so pumping in many small steps
/// - rather than one or two large-duration pumps - keeps each frame's delta
/// bounded the way a real device would produce it. Getting through the full
/// spiralIn -> pause -> textOut -> hold -> resetPause sequence takes a bit
/// over 7.5 simulated seconds; pump generously past that, then let the
/// destination screen's own async init settle.
Future<void> _skipSplashAndSettle(WidgetTester tester) async {
  for (var i = 0; i < 800; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await _settleHome(tester);
}

void main() {
  group('HomeScreen streak counting (_incrementStreakIfNewDay)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('normal daily check-in increments streak by 1 and records the date', (
      tester,
    ) async {
      final now = DateTime(2026, 3, 10, 9, 0);
      SharedPreferences.setMockInitialValues(<String, Object>{
        'streakCount': 4,
        'lastCheckInDate': '2026-03-09',
        'lastActiveTimestamp': now
            .subtract(const Duration(hours: 20))
            .millisecondsSinceEpoch,
      });

      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(nowProvider: () => now)),
      );
      await _settleHome(tester);

      await _tapCheckIn(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('streakCount'), 5);
      expect(prefs.getString('lastCheckInDate'), '2026-03-10');
    });

    testWidgets(
      'reopening the app the same day after check-in does not double-increment the streak',
      (tester) async {
        final now = DateTime(2026, 3, 10, 9, 0);
        SharedPreferences.setMockInitialValues(<String, Object>{
          'streakCount': 4,
          'lastCheckInDate': '2026-03-10', // already checked in today
          'lastActiveTimestamp': now
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch,
        });

        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(nowProvider: () => now)),
        );
        await _settleHome(tester);

        // Already checked in today: button must be gone, streak untouched.
        expect(find.byKey(const ValueKey('check-in-button')), findsNothing);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('streakCount'), 4);
      },
    );

    testWidgets(
      'check-ins that straddle a calendar-day boundary within minutes both increment the streak '
      '(streak gating is calendar-date-based, not a minimum-elapsed-time based)',
      (tester) async {
        var now = DateTime(2026, 3, 10, 23, 59, 30);
        SharedPreferences.setMockInitialValues(<String, Object>{
          'streakCount': 4,
          'lastCheckInDate': '2026-03-09',
          'lastActiveTimestamp': now
              .subtract(const Duration(hours: 20))
              .millisecondsSinceEpoch,
        });

        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(nowProvider: () => now)),
        );
        await _settleHome(tester);
        await _tapCheckIn(tester);

        var prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('streakCount'), 5);
        expect(prefs.getString('lastCheckInDate'), '2026-03-10');

        // Simulate reopening the app 90 seconds later, now past midnight.
        now = DateTime(2026, 3, 11, 0, 1, 0);
        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(nowProvider: () => now)),
        );
        await _settleHome(tester);
        await _tapCheckIn(tester);

        prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getInt('streakCount'),
          6,
          reason:
              'Two check-ins 90 seconds apart both counted because they land on '
              'different calendar dates - streak logic only compares '
              'lastCheckInDate to the current date string, not elapsed duration.',
        );
      },
    );

    testWidgets(
      'skipping an entire calendar day (without dying) still increments the streak by 1, '
      'not reset - streak has no "missed day" detection independent of the 39h death timer',
      (tester) async {
        // Check in late on day 1 (2026-03-10 23:00), then skip day 2 entirely
        // and check in on day 3 (2026-03-12 10:00). That is a ~35h gap - long
        // enough to skip a full calendar day, but still under the 39h death
        // threshold, so the app never routes through the eulogy/death reset
        // path. If streak were meant to represent "consecutive calendar
        // days," it should reset to 1 here. It doesn't.
        final day1 = DateTime(2026, 3, 10, 23, 0);
        SharedPreferences.setMockInitialValues(<String, Object>{
          'streakCount': 4,
          'lastCheckInDate': '2026-03-09',
          'lastActiveTimestamp': day1
              .subtract(const Duration(hours: 20))
              .millisecondsSinceEpoch,
        });

        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(nowProvider: () => day1)),
        );
        await _settleHome(tester);
        await _tapCheckIn(tester);

        var prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('streakCount'), 5);
        expect(prefs.getString('lastCheckInDate'), '2026-03-10');

        // Day 2 (2026-03-11) is entirely skipped - no check-in.

        final day3 = DateTime(2026, 3, 12, 10, 0);
        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(nowProvider: () => day3)),
        );
        await _settleHome(tester);
        await _tapCheckIn(tester);

        prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getInt('streakCount'),
          6,
          reason:
              'Documents current (arguably buggy) behavior: streak keeps '
              'incrementing across a fully skipped calendar day as long as the '
              '39h death timer has not expired.',
        );
      },
    );
  });

  group('AppRouter death detection (main.dart _checkNavigationStatus)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets(
      'elapsed just under 39h since last check-in: user is alive, home screen shown',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'hasCompletedOnboarding': true,
          'hasSeenOnboarding': true,
          'userName': 'Yash',
          'streakCount': 3,
          'lastActiveTimestamp': DateTime.now()
              .subtract(const Duration(hours: 38, minutes: 55))
              .millisecondsSinceEpoch,
        });

        await tester.pumpWidget(const AreYouAliveApp());
        await _skipSplashAndSettle(tester);

        expect(find.byType(EulogyScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('hasDied') ?? false, isFalse);
      },
    );

    testWidgets(
      'elapsed at/over 39h since last check-in: user dies, eulogy screen shown, '
      'hasDied + deathStreakCount persisted',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'hasCompletedOnboarding': true,
          'hasSeenOnboarding': true,
          'userName': 'Yash',
          'streakCount': 7,
          'lastActiveTimestamp': DateTime.now()
              .subtract(const Duration(hours: 39, minutes: 5))
              .millisecondsSinceEpoch,
        });

        await tester.pumpWidget(const AreYouAliveApp());
        await _skipSplashAndSettle(tester);

        expect(find.byType(EulogyScreen), findsOneWidget);
        expect(find.text('They survived 7 days.'), findsOneWidget);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('hasDied'), isTrue);
        expect(prefs.getInt('deathStreakCount'), 7);
      },
    );

    testWidgets('a previously-persisted hasDied=true routes straight to eulogy', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'hasCompletedOnboarding': true,
        'hasSeenOnboarding': true,
        'userName': 'Yash',
        'hasDied': true,
        'deathStreakCount': 12,
        // lastActiveTimestamp deliberately recent - hasDied being already
        // true must short-circuit the elapsed-time check entirely.
        'lastActiveTimestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await tester.pumpWidget(const AreYouAliveApp());
      await _skipSplashAndSettle(tester);

      expect(find.byType(EulogyScreen), findsOneWidget);
      expect(find.text('They survived 12 days.'), findsOneWidget);
    });

    testWidgets(
      '"Rise again" resets streak, lastCheckInDate, and hasDied, returning to home',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'hasCompletedOnboarding': true,
          'hasSeenOnboarding': true,
          'userName': 'Yash',
          'hasDied': true,
          'deathStreakCount': 12,
          'streakCount': 12,
          'lastCheckInDate': '2026-03-01',
          'lastActiveTimestamp': DateTime.now().millisecondsSinceEpoch,
        });

        await tester.pumpWidget(const AreYouAliveApp());
        await _skipSplashAndSettle(tester);

        expect(find.byType(EulogyScreen), findsOneWidget);
        await tester.tap(find.text('Rise again'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(EulogyScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('hasDied'), isFalse);
        expect(prefs.getInt('streakCount'), 0);
        expect(prefs.getString('lastCheckInDate'), '');
        expect(prefs.getInt('checkInsSinceDeath'), 0);
      },
    );

    testWidgets('fresh install (no prefs at all) shows the welcome screen', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await tester.pumpWidget(const AreYouAliveApp());
      await _skipSplashAndSettle(tester);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets(
      'onboarding completed but explanation not yet seen shows the onboarding screen',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'hasCompletedOnboarding': true,
          'hasSeenOnboarding': false,
          'userName': 'Yash',
        });

        await tester.pumpWidget(const AreYouAliveApp());
        await _skipSplashAndSettle(tester);

        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
      },
    );

    testWidgets(
      'returning user with no lastActiveTimestamp yet (completed onboarding, never scheduled a '
      'countdown) is not treated as dead',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'hasCompletedOnboarding': true,
          'hasSeenOnboarding': true,
          'userName': 'Yash',
          // No 'lastActiveTimestamp' key at all.
        });

        await tester.pumpWidget(const AreYouAliveApp());
        await _skipSplashAndSettle(tester);

        expect(find.byType(EulogyScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );
  });
}
