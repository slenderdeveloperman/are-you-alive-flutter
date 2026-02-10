import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:are_you_alive_flutter/screens/eulogy_screen.dart';
import 'package:are_you_alive_flutter/screens/home_screen.dart';
import 'package:are_you_alive_flutter/screens/onboarding_screen.dart';
import 'package:are_you_alive_flutter/screens/welcome_screen.dart';
import 'package:are_you_alive_flutter/widgets/badge_summary_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Generate Play Store screenshots for phone and tablet', (
    tester,
  ) async {
    await _generateForDevice(
      tester,
      deviceName: 'phone',
      size: const Size(360, 640),
      safePadding: const EdgeInsets.only(top: 44, bottom: 24),
    );

    await _generateForDevice(
      tester,
      deviceName: 'tablet',
      size: const Size(800, 1280),
      safePadding: const EdgeInsets.only(top: 36, bottom: 24),
    );
  });
}

Future<void> _generateForDevice(
  WidgetTester tester, {
  required String deviceName,
  required Size size,
  required EdgeInsets safePadding,
}) async {
  final baseDir = Directory('screenshots/playstore/$deviceName');
  await baseDir.create(recursive: true);

  SharedPreferences.setMockInitialValues(<String, Object>{});
  await _capture(
    tester,
    filePath: '${baseDir.path}/01_welcome.png',
    size: size,
    safePadding: safePadding,
    child: WelcomeScreen(onComplete: () {}),
    arrange: (tester) async {
      await tester.enterText(find.byType(TextField), 'Yash');
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

  SharedPreferences.setMockInitialValues(<String, Object>{});
  await _capture(
    tester,
    filePath: '${baseDir.path}/02_onboarding.png',
    size: size,
    safePadding: safePadding,
    child: OnboardingScreen(onComplete: () {}),
    settleFor: const Duration(milliseconds: 500),
  );

  SharedPreferences.setMockInitialValues(_homePrefs(checkedInToday: false));
  await _capture(
    tester,
    filePath: '${baseDir.path}/03_home_precheckin.png',
    size: size,
    safePadding: safePadding,
    child: const HomeScreen(),
    settleFor: const Duration(milliseconds: 700),
  );

  SharedPreferences.setMockInitialValues(_homePrefs(checkedInToday: true));
  await _capture(
    tester,
    filePath: '${baseDir.path}/04_home_checkedin.png',
    size: size,
    safePadding: safePadding,
    child: const HomeScreen(),
    settleFor: const Duration(milliseconds: 900),
  );

  SharedPreferences.setMockInitialValues(_homePrefs(checkedInToday: true));
  await _capture(
    tester,
    filePath: '${baseDir.path}/05_badges_sheet.png',
    size: size,
    safePadding: safePadding,
    child: const HomeScreen(),
    settleFor: const Duration(milliseconds: 900),
    arrange: (tester) async {
      await tester.tap(find.byType(BadgeSummaryCard));
      await tester.pump(const Duration(milliseconds: 700));
    },
  );

  SharedPreferences.setMockInitialValues(<String, Object>{});
  await _capture(
    tester,
    filePath: '${baseDir.path}/06_eulogy.png',
    size: size,
    safePadding: safePadding,
    child: EulogyScreen(
      userName: 'Yash',
      deathStreakCount: 12,
      onRiseAgain: () {},
    ),
    settleFor: const Duration(milliseconds: 500),
  );
}

Map<String, Object> _homePrefs({required bool checkedInToday}) {
  final now = DateTime.now();
  final today = _dateOnly(now);
  final yesterday = _dateOnly(now.subtract(const Duration(days: 1)));

  final dailyBuckets = <String, int>{
    today: 7,
    yesterday: 13,
    _dateOnly(now.subtract(const Duration(days: 2))): 10,
    _dateOnly(now.subtract(const Duration(days: 3))): 9,
  };

  final checkInHistory = <Map<String, Object>>[
    {
      'timestampMs': now.subtract(const Duration(days: 3)).millisecondsSinceEpoch,
      'remainingMs': const Duration(hours: 9).inMilliseconds,
    },
    {
      'timestampMs': now.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
      'remainingMs': const Duration(hours: 15).inMilliseconds,
    },
    {
      'timestampMs': now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      'remainingMs': const Duration(hours: 13).inMilliseconds,
    },
    {
      'timestampMs': now.subtract(const Duration(hours: 12)).millisecondsSinceEpoch,
      'remainingMs': const Duration(hours: 14).inMilliseconds,
    },
  ];

  return <String, Object>{
    'userName': 'Yash',
    'streakCount': 12,
    'checkInsSinceDeath': 3,
    'hasDied': false,
    'lastActiveTimestamp':
        now.subtract(const Duration(hours: 1, minutes: 20)).millisecondsSinceEpoch,
    'lastCheckInDate': checkedInToday ? today : yesterday,
    'metrics.open.total': 138,
    'metrics.open.dailyBucketsJson': jsonEncode(dailyBuckets),
    'metrics.checkin.historyJson': jsonEncode(checkInHistory),
    'metrics.death.historyJson': '[]',
    'metrics.death.count': 0,
    'metrics.badges.earnedJson': '{}',
    'metrics.schema.version': 1,
  };
}

String _dateOnly(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

Future<void> _capture(
  WidgetTester tester, {
  required String filePath,
  required Size size,
  required EdgeInsets safePadding,
  required Widget child,
  Duration settleFor = const Duration(milliseconds: 900),
  Future<void> Function(WidgetTester tester)? arrange,
}) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(size);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: safePadding,
          devicePixelRatio: 1,
        ),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: ColoredBox(
            key: key,
            color: Colors.transparent,
            child: child,
          ),
        ),
      ),
    ),
  );

  await tester.pump(settleFor);
  if (arrange != null) {
    await arrange(tester);
  }
  await tester.pump(const Duration(milliseconds: 300));

  await expectLater(find.byKey(key), matchesGoldenFile(filePath));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}
