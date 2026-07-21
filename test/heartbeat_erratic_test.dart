import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:are_you_alive_flutter/screens/home_screen.dart';

/// See streak_and_death_test.dart's _settleHome for why this many discrete
/// pumps are needed to flush HomeScreen's chained async init.
Future<void> _settleHome(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

double _heartScale(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.byKey(const ValueKey('heartbeat-scale')),
  );
  return transform.transform.entry(0, 0);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'erratic heartbeat never reverses direction before completing a full beat '
    '(regression test for the mid-cycle stop()+repeat() restart bug)',
    (tester) async {
      final now = DateTime(2026, 3, 10, 9, 0);
      SharedPreferences.setMockInitialValues(<String, Object>{
        'streakCount': 5,
        'checkInsSinceDeath': 3,
        'lastCheckInDate': '2026-03-09',
        // 30h elapsed: inside the 24h-39h erratic window.
        'lastActiveTimestamp': now
            .subtract(const Duration(hours: 30))
            .millisecondsSinceEpoch,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(nowProvider: () => now, random: Random(20260310)),
        ),
      );
      await _settleHome(tester);

      // Sample the displayed heart scale densely enough to resolve
      // individual beats (shortest possible beat leg is 350ms).
      const sampleStep = Duration(milliseconds: 10);
      const sampleWindow = Duration(milliseconds: 4000);
      final samples = <double>[];
      final sampleTimesMs = <int>[];
      var elapsedMs = 0;
      while (elapsedMs < sampleWindow.inMilliseconds) {
        await tester.pump(sampleStep);
        elapsedMs += sampleStep.inMilliseconds;
        samples.add(_heartScale(tester));
        sampleTimesMs.add(elapsedMs);
      }

      // Find turning points (local extrema) in the trace.
      final extremaIndices = <int>[];
      for (var i = 1; i < samples.length - 1; i++) {
        final prevDelta = samples[i] - samples[i - 1];
        final nextDelta = samples[i + 1] - samples[i];
        if (prevDelta == 0 || nextDelta == 0) continue;
        if ((prevDelta > 0) != (nextDelta > 0)) {
          extremaIndices.add(i);
        }
      }

      // Sanity check: the erratic phase should actually be producing beats
      // during this window, or the test isn't exercising anything.
      expect(
        extremaIndices.length,
        greaterThan(2),
        reason:
            'expected several heartbeat reversals in a 4s window while '
            'erratic - if this is 0, the fixture likely failed to reach '
            'the erratic phase',
      );

      // Each run between consecutive turning points is one beat leg. A
      // genuine beat leg takes the controller's full configured duration
      // (350-899ms per _applyErraticBeatProfile) because
      // _onHeartbeatStatusChanged only restarts the controller at a status
      // boundary (dismissed/completed). Before that fix, a mid-cycle
      // stop()+repeat() could truncate a leg to any length down to ~0ms.
      // Exclude the first and last runs: their true start/end lies outside
      // the sampled window, so their measured length is an artifact of
      // when sampling began/ended, not a real beat.
      const minPlausibleLegMs = 300; // 350ms floor minus sampling slack
      for (var i = 1; i < extremaIndices.length - 1; i++) {
        final legMs =
            sampleTimesMs[extremaIndices[i]] -
            sampleTimesMs[extremaIndices[i - 1]];
        expect(
          legMs,
          greaterThanOrEqualTo(minPlausibleLegMs),
          reason:
              'beat leg from t=${sampleTimesMs[extremaIndices[i - 1]]}ms to '
              't=${sampleTimesMs[extremaIndices[i]]}ms lasted only ${legMs}ms '
              '- shorter than the 350ms minimum beat duration, meaning the '
              'heartbeat reversed direction mid-beat instead of at a clean '
              'boundary',
        );
      }
    },
  );
}
