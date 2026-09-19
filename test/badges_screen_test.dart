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

double _scaleOf(WidgetTester tester, BadgeId id) {
  final transform = tester.widget<Transform>(
    find.byKey(ValueKey('badge-scale-${id.name}')),
  );
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

  testWidgets(
    'a badge timestamped in the future does not celebrate',
    (tester) async {
      final now = DateTime(2026, 1, 1, 12);
      final futureEarned = _badge(
        id: BadgeId.metronome,
        earned: true,
        earnedAtMs: now.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BadgesScreen(
            snapshot: _snapshot([futureEarned]),
            nowProvider: () => now,
          ),
        ),
      );
      await tester.pump();

      expect(_scaleOf(tester, BadgeId.metronome), 1.0);
    },
  );
}
