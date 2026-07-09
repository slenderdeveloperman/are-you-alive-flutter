import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:are_you_alive_flutter/main.dart';
import 'package:are_you_alive_flutter/screens/home_screen.dart';
import 'package:are_you_alive_flutter/screens/splash_screen.dart';
import 'package:are_you_alive_flutter/widgets/are_you_alive_loop.dart';
import 'package:are_you_alive_flutter/widgets/typewriter_text.dart';

Iterable<TextSpan> _flattenTextSpans(InlineSpan span) sync* {
  if (span is! TextSpan) {
    return;
  }
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* _flattenTextSpans(child);
  }
}

String _textFromRichTextWidget(Text widget) {
  return widget.textSpan?.toPlainText() ?? widget.data ?? '';
}

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  bool canLaunchResult = true;
  bool launchResult = true;
  String? launchedUrl;
  LaunchOptions? launchedOptions;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => canLaunchResult;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    launchedOptions = options;
    return launchResult;
  }

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrl = url;
    return launchResult;
  }

  @override
  Future<void> closeWebView() async {}
}

void main() {
  late UrlLauncherPlatform originalUrlLauncher;
  late _FakeUrlLauncherPlatform fakeUrlLauncher;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lastActiveTimestamp': DateTime.now().millisecondsSinceEpoch,
      'streakCount': 1,
      'hasCompletedOnboarding': true,
      'hasSeenOnboarding': true,
    });
    originalUrlLauncher = UrlLauncherPlatform.instance;
    fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = originalUrlLauncher;
  });

  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AreYouAliveApp());
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('Badges icon opens badges screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    final badgesIconFinder = find.byIcon(Icons.military_tech);
    expect(badgesIconFinder, findsOneWidget);

    await tester.tap(badgesIconFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('badges'), findsOneWidget);
    expect(find.textContaining('unlocked'), findsWidgets);
  });

  testWidgets('Splash screen renders spiral animation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: SplashScreen(onComplete: () {})));
    await tester.pump();

    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('Pre-check-in state hides timer and message', (
    WidgetTester tester,
  ) async {
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lastActiveTimestamp': DateTime.now().millisecondsSinceEpoch,
      'streakCount': 1,
      'hasCompletedOnboarding': true,
      'hasSeenOnboarding': true,
      'lastCheckInDate': yesterday,
    });

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.byKey(const ValueKey('check-in-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('timer-message-glitch')), findsNothing);
  });

  testWidgets(
    'Checked-in state shows live countdown, mixed-color message, and tomorrow prompt',
    (WidgetTester tester) async {
      var fakeNow = DateTime(2026, 2, 9, 12, 0, 5);
      final today = fakeNow.toIso8601String().substring(0, 10);
      SharedPreferences.setMockInitialValues(<String, Object>{
        'lastActiveTimestamp': fakeNow
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
        'streakCount': 1,
        'hasCompletedOnboarding': true,
        'hasSeenOnboarding': true,
        'lastCheckInDate': today,
        'userName': 'Yash',
      });

      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(nowProvider: () => fakeNow)),
      );
      await tester.pump(const Duration(milliseconds: 2500));
      // A second pump lets the streak-count TweenAnimationBuilder (600ms)
      // finish animating from its default 0 to the loaded streak value,
      // since the underlying setState only lands mid-way through the first
      // pump's single simulated frame.
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.textContaining('day alive'), findsOneWidget);
      expect(find.byKey(const ValueKey('live-countdown-text')), findsNothing);

      final glitchFinder = find.byKey(const ValueKey('timer-message-glitch'));
      expect(glitchFinder, findsOneWidget);
      final richTextFinder = find.descendant(
        of: glitchFinder,
        matching: find.byType(Text),
      );
      expect(richTextFinder, findsOneWidget);

      final beforeTick = _textFromRichTextWidget(
        tester.widget<Text>(richTextFinder),
      );
      expect(beforeTick, matches(RegExp(r'\d{2}:\d{2}:\d{2}')));

      fakeNow = fakeNow.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      final afterTick = _textFromRichTextWidget(
        tester.widget<Text>(richTextFinder),
      );
      expect(afterTick, isNot(equals(beforeTick)));
      expect(afterTick, matches(RegExp(r'\d{2}:\d{2}:\d{2}')));

      final tomorrowFinder = find.byKey(const ValueKey('typewriter-tomorrow'));
      expect(tomorrowFinder, findsOneWidget);
      final tomorrowWidget = tester.widget<TypewriterText>(tomorrowFinder);
      expect(tomorrowWidget.text, 'CHECK BACK IN TOMORROW');

      final timerText = tester.widget<Text>(richTextFinder);
      final span = timerText.textSpan;
      expect(span, isNotNull);

      final colors = _flattenTextSpans(
        span!,
      ).map((it) => it.style?.color).toSet();
      expect(colors.contains(Colors.white), isTrue);
      expect(colors.contains(Colors.red.withValues(alpha: 0.9)), isTrue);
    },
  );

  testWidgets('Midnight rollover resets checked-in UI immediately', (
    WidgetTester tester,
  ) async {
    var fakeNow = DateTime(2026, 2, 9, 23, 59, 58);
    final dayKey = fakeNow.toIso8601String().substring(0, 10);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lastActiveTimestamp': fakeNow
          .subtract(const Duration(minutes: 5))
          .millisecondsSinceEpoch,
      'streakCount': 2,
      'hasCompletedOnboarding': true,
      'hasSeenOnboarding': true,
      'lastCheckInDate': dayKey,
    });

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(nowProvider: () => fakeNow)),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('timer-message-glitch')),
      findsOneWidget,
    );

    fakeNow = DateTime(2026, 2, 10, 0, 0, 1);
    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey('check-in-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('timer-message-glitch')), findsNothing);
  });

  testWidgets('Bottom action buttons render with semantics labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.bySemanticsLabel('Share'), findsOneWidget);
    expect(find.bySemanticsLabel('Badges'), findsOneWidget);
    expect(find.bySemanticsLabel('Builder'), findsOneWidget);
  });

  testWidgets('Builder button opens X profile externally', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 1200));

    await tester.tap(find.byIcon(Icons.build));
    await tester.pump();

    expect(fakeUrlLauncher.launchedUrl, 'https://x.com/slndrtweeterman');
    expect(
      fakeUrlLauncher.launchedOptions?.mode,
      PreferredLaunchMode.externalApplication,
    );
  });

  testWidgets('Builder button shows snackbar when profile launch fails', (
    WidgetTester tester,
  ) async {
    fakeUrlLauncher.launchResult = false;
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 1200));

    await tester.tap(find.byIcon(Icons.build));
    await tester.pump();

    expect(find.text('Could not open profile.'), findsOneWidget);
  });

  testWidgets('Check-in button responds to tap and reveals post-check-in UI', (
    WidgetTester tester,
  ) async {
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lastActiveTimestamp': DateTime.now().millisecondsSinceEpoch,
      'streakCount': 1,
      'hasCompletedOnboarding': true,
      'hasSeenOnboarding': true,
      'lastCheckInDate': yesterday,
    });

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.byKey(const ValueKey('check-in-button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('check-in-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('check-in-button')), findsNothing);
    expect(find.byKey(const ValueKey('timer-message-glitch')), findsOneWidget);
    expect(find.byKey(const ValueKey('typewriter-tomorrow')), findsOneWidget);

    // Flush delayed streak animation timer started during check-in.
    await tester.pump(const Duration(milliseconds: 900));
  });

  testWidgets('Loop sits above bottom pill and does not capture pointers', (
    WidgetTester tester,
  ) async {
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lastActiveTimestamp': DateTime.now().millisecondsSinceEpoch,
      'streakCount': 1,
      'hasCompletedOnboarding': true,
      'hasSeenOnboarding': true,
      'lastCheckInDate': yesterday,
    });

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 1200));

    final loopFinder = find.byType(AreYouAliveLoop);
    final pillFinder = find.byKey(const ValueKey('bottom-action-pill'));
    expect(loopFinder, findsOneWidget);
    expect(pillFinder, findsOneWidget);

    final loopBottom = tester.getBottomLeft(loopFinder).dy;
    final pillTop = tester.getTopLeft(pillFinder).dy;
    expect(loopBottom, lessThan(pillTop));

    final ignorePointerFinder = find.byType(IgnorePointer);
    final ignorePointerWidgets =
        tester.widgetList<IgnorePointer>(ignorePointerFinder).toList();
    expect(ignorePointerWidgets.any((widget) => widget.ignoring), isTrue);
  });
}
