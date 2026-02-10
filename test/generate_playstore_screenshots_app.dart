import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:are_you_alive_flutter/screens/eulogy_screen.dart';
import 'package:are_you_alive_flutter/screens/home_screen.dart';
import 'package:are_you_alive_flutter/screens/onboarding_screen.dart';
import 'package:are_you_alive_flutter/screens/welcome_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ShotGeneratorApp());
}

class _ShotScenario {
  const _ShotScenario({
    required this.path,
    required this.size,
    required this.safePadding,
    required this.prep,
    required this.builder,
    required this.waitBeforeCapture,
  });

  final String path;
  final Size size;
  final EdgeInsets safePadding;
  final Future<void> Function() prep;
  final Widget Function() builder;
  final Duration waitBeforeCapture;
}

class _ShotGeneratorApp extends StatefulWidget {
  const _ShotGeneratorApp();

  @override
  State<_ShotGeneratorApp> createState() => _ShotGeneratorAppState();
}

class _ShotGeneratorAppState extends State<_ShotGeneratorApp> {
  final GlobalKey _shotKey = GlobalKey();
  _ShotScenario? _activeScenario;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _run();
    });
  }

  Future<void> _run() async {
    final scenarios = _scenarios();

    for (final scenario in scenarios) {
      await scenario.prep();
      setState(() {
        _activeScenario = scenario;
      });
      await Future.delayed(scenario.waitBeforeCapture);
      await _captureCurrentScenario(scenario.path);
    }

    exit(0);
  }

  List<_ShotScenario> _scenarios() {
    const phone = Size(1080, 1920);
    const tablet = Size(1600, 2560);
    const phoneSafe = EdgeInsets.only(top: 44, bottom: 24);
    const tabletSafe = EdgeInsets.only(top: 36, bottom: 24);

    return <_ShotScenario>[
      _ShotScenario(
        path: 'screenshots/playstore/phone/01_welcome.png',
        size: phone,
        safePadding: phoneSafe,
        prep: _prepEmpty,
        builder: () => WelcomeScreen(onComplete: () {}),
        waitBeforeCapture: const Duration(milliseconds: 900),
      ),
      _ShotScenario(
        path: 'screenshots/playstore/phone/02_onboarding.png',
        size: phone,
        safePadding: phoneSafe,
        prep: _prepEmpty,
        builder: () => OnboardingScreen(onComplete: () {}),
        waitBeforeCapture: const Duration(milliseconds: 700),
      ),
      _ShotScenario(
        path: 'screenshots/playstore/phone/03_home_precheckin.png',
        size: phone,
        safePadding: phoneSafe,
        prep: () => _prepHome(checkedInToday: false),
        builder: () => const HomeScreen(),
        waitBeforeCapture: const Duration(milliseconds: 1200),
      ),
      _ShotScenario(
        path: 'screenshots/playstore/phone/04_home_checkedin.png',
        size: phone,
        safePadding: phoneSafe,
        prep: () => _prepHome(checkedInToday: true),
        builder: () => const HomeScreen(),
        waitBeforeCapture: const Duration(milliseconds: 1200),
      ),
      _ShotScenario(
        path: 'screenshots/playstore/phone/05_eulogy.png',
        size: phone,
        safePadding: phoneSafe,
        prep: _prepEmpty,
        builder: () => EulogyScreen(
          userName: 'Yash',
          deathStreakCount: 12,
          onRiseAgain: () {},
        ),
        waitBeforeCapture: const Duration(milliseconds: 700),
      ),
      _ShotScenario(
        path: 'screenshots/playstore/tablet/01_welcome.png',
        size: tablet,
        safePadding: tabletSafe,
        prep: _prepEmpty,
        builder: () => WelcomeScreen(onComplete: () {}),
        waitBeforeCapture: const Duration(milliseconds: 900),
      ),
      _ShotScenario(
        path: 'screenshots/playstore/tablet/02_onboarding.png',
        size: tablet,
        safePadding: tabletSafe,
        prep: _prepEmpty,
        builder: () => OnboardingScreen(onComplete: () {}),
        waitBeforeCapture: const Duration(milliseconds: 700),
      ),
      _ShotScenario(
        path: 'screenshots/playstore/tablet/03_home_precheckin.png',
        size: tablet,
        safePadding: tabletSafe,
        prep: () => _prepHome(checkedInToday: false),
        builder: () => const HomeScreen(),
        waitBeforeCapture: const Duration(milliseconds: 1200),
      ),
      _ShotScenario(
        path: 'screenshots/playstore/tablet/04_home_checkedin.png',
        size: tablet,
        safePadding: tabletSafe,
        prep: () => _prepHome(checkedInToday: true),
        builder: () => const HomeScreen(),
        waitBeforeCapture: const Duration(milliseconds: 1200),
      ),
      _ShotScenario(
        path: 'screenshots/playstore/tablet/05_eulogy.png',
        size: tablet,
        safePadding: tabletSafe,
        prep: _prepEmpty,
        builder: () => EulogyScreen(
          userName: 'Yash',
          deathStreakCount: 12,
          onRiseAgain: () {},
        ),
        waitBeforeCapture: const Duration(milliseconds: 700),
      ),
    ];
  }

  Future<void> _prepEmpty() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> _prepHome({required bool checkedInToday}) async {
    final prefs = await SharedPreferences.getInstance();
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
        'timestampMs':
            now.subtract(const Duration(hours: 12)).millisecondsSinceEpoch,
        'remainingMs': const Duration(hours: 14).inMilliseconds,
      },
    ];

    await prefs.setString('userName', 'Yash');
    await prefs.setInt('streakCount', 12);
    await prefs.setInt('checkInsSinceDeath', 3);
    await prefs.setBool('hasDied', false);
    await prefs.setInt(
      'lastActiveTimestamp',
      now.subtract(const Duration(hours: 1, minutes: 20)).millisecondsSinceEpoch,
    );
    await prefs.setString('lastCheckInDate', checkedInToday ? today : yesterday);
    await prefs.setInt('metrics.open.total', 138);
    await prefs.setString('metrics.open.dailyBucketsJson', jsonEncode(dailyBuckets));
    await prefs.setString('metrics.checkin.historyJson', jsonEncode(checkInHistory));
    await prefs.setString('metrics.death.historyJson', '[]');
    await prefs.setInt('metrics.death.count', 0);
    await prefs.setString('metrics.badges.earnedJson', '{}');
    await prefs.setInt('metrics.schema.version', 1);
  }

  String _dateOnly(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _captureCurrentScenario(String outputPath) async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = data!.buffer.asUint8List();

    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Widget build(BuildContext context) {
    final scenario = _activeScenario;

    if (scenario == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(color: Colors.black),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Center(
        child: RepaintBoundary(
          key: _shotKey,
          child: MediaQuery(
            data: MediaQueryData(
              size: scenario.size,
              padding: scenario.safePadding,
              devicePixelRatio: 1,
            ),
            child: SizedBox(
              width: scenario.size.width,
              height: scenario.size.height,
              child: scenario.builder(),
            ),
          ),
        ),
      ),
    );
  }
}
