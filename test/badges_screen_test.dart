import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:are_you_alive_flutter/models/badge_models.dart';
import 'package:are_you_alive_flutter/screens/badges_screen.dart';

BadgeProgress _badge({
  required BadgeId id,
  required bool earned,
  int? earnedAtMs,
}) {
  return BadgeProgress(
    definition: BadgeDefinition(id: id, title: id.name, description: id.name),
    earned: earned,
    earnedAtMs: earnedAtMs,
    progress: earned ? 1 : 0,
    current: earned ? 1 : 0,
    target: 1,
    hint: 'hint',
  );
}

BadgeSnapshot _snapshot(List<BadgeProgress> badges) {
  return BadgeSnapshot(
    appOpenStats: const AppOpenStats(
      total: 1,
      today: 1,
      week: 1,
      month: 1,
      year: 1,
      dailyBuckets: {},
    ),
    badges: badges,
    topBadge: badges.first,
  );
}

/// The celebration entrance animates scale from 0.7 → 1.0 over 500ms. A
/// freshly-pumped celebrating chip is caught mid-entrance (scale < 1.0); a
/// non-celebrating chip renders at rest (scale == 1.0) immediately.
double _scaleOf(WidgetTester tester, BadgeId id) {
  final transform = tester.widget<Transform>(
    find.byKey(ValueKey('badge-scale-${id.name}')),
  );
  // Transform.scale builds Matrix4.diagonal3Values(scale, scale, 1.0) — the
  // X-axis entry (entry 0,0) is the scale factor itself. (Not
  // getMaxScaleOnAxis(): that also considers the always-1.0 Z axis, so it
  // never reads below 1.0 for a 2D Transform.scale.)
  return transform.transform.entry(0, 0);
}

void main() {
  testWidgets(
    'a badge earned 1 minute ago plays the unlock celebration',
    (tester) async {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      final recentlyEarned = _badge(
        id: BadgeId.metronome,
        earned: true,
        earnedAtMs: now
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BadgesScreen(
            snapshot: _snapshot([recentlyEarned]),
            nowProvider: () => now,
          ),
        ),
      );
      // Advance partway through the 500ms entrance — long enough to leave
      // the 0.7 starting scale, short enough not to have settled at 1.0.
      await tester.pump(const Duration(milliseconds: 100));

      expect(_scaleOf(tester, BadgeId.metronome), lessThan(1.0));
    },
  );

  testWidgets(
    'a badge earned 15 minutes ago renders without the celebration',
    (tester) async {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      final oldEarned = _badge(
        id: BadgeId.metronome,
        earned: true,
        earnedAtMs: now
            .subtract(const Duration(minutes: 15))
            .millisecondsSinceEpoch,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BadgesScreen(
            snapshot: _snapshot([oldEarned]),
            nowProvider: () => now,
          ),
        ),
      );
      await tester.pump();

      expect(_scaleOf(tester, BadgeId.metronome), 1.0);
    },
  );

  testWidgets(
    'an unearned badge never celebrates regardless of timestamp',
    (tester) async {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      // earnedAtMs set (e.g. stale data) but earned:false must still win.
      final unearned = _badge(
        id: BadgeId.metronome,
        earned: false,
        earnedAtMs: now
            .subtract(const Duration(seconds: 5))
            .millisecondsSinceEpoch,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BadgesScreen(
            snapshot: _snapshot([unearned]),
            nowProvider: () => now,
          ),
        ),
      );
      await tester.pump();

      expect(_scaleOf(tester, BadgeId.metronome), 1.0);
    },
  );
}
