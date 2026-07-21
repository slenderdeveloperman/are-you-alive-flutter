import 'dart:convert';

import 'package:are_you_alive_flutter/config/share_presets.dart';
import 'package:are_you_alive_flutter/models/share_models.dart';
import 'package:are_you_alive_flutter/widgets/share_preset_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final input = SharePayloadInput(
    streakDays: 3,
    remaining: Duration(hours: 10),
    timerMessage: 'check in',
    userName: 'Yash',
    now: DateTime(2026, 2, 9, 12, 0),
    badgeSnapshot: null,
    notificationTimestampMs: null,
  );

  testWidgets('preset picker shows two thumbnail presets', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SharePresetSheet(input: input))),
    );
    await tester.pump();

    expect(sharePresets.length, 3);
    expect(
      find.byKey(
        const ValueKey('share-preset-card-certificate_of_participation'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('share-preset-card-existential_battery')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('share-preset-thumb-certificate_of_participation'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('share-preset-thumb-existential_battery')),
      findsOneWidget,
    );
    // Near-miss is hidden by default: no check-in history means it hasn't
    // been earned yet.
    expect(
      find.byKey(const ValueKey('share-preset-card-near_miss_save')),
      findsNothing,
    );
  });

  testWidgets('selected preset uses high-contrast white state and can switch', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SharePresetSheet(input: input))),
    );
    await tester.pump();

    final selectedBefore = tester.widget<AnimatedContainer>(
      find.byKey(
        const ValueKey('share-preset-container-certificate_of_participation'),
      ),
    );
    final beforeBorder = (selectedBefore.decoration! as BoxDecoration).border!
        as Border;
    expect(beforeBorder.top.color, Colors.white);
    expect(beforeBorder.top.width, 2.0);

    await tester.tap(
      find.byKey(const ValueKey('share-preset-card-existential_battery')),
    );
    await tester.pump(const Duration(milliseconds: 250));

    final selectedAfter = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('share-preset-container-existential_battery')),
    );
    final afterBorder = (selectedAfter.decoration! as BoxDecoration).border!
        as Border;
    expect(afterBorder.top.color, Colors.white);
    expect(afterBorder.top.width, 2.0);

    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Check-in margin'), findsOneWidget);
    expect(find.text('Total cumulative hours'), findsNothing);
  });

  testWidgets('near-miss preset appears once a close call is on record', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'metrics.checkin.historyJson': jsonEncode(<Map<String, int>>[
        <String, int>{
          'timestampMs': 1000,
          'remainingMs': const Duration(hours: 2).inMilliseconds,
        },
      ]),
    });

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SharePresetSheet(input: input))),
    );
    await tester.pumpAndSettle();

    final nearMissCard = find.byKey(
      const ValueKey('share-preset-card-near_miss_save'),
    );
    await tester.scrollUntilVisible(
      nearMissCard,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(nearMissCard, findsOneWidget);
  });
}
