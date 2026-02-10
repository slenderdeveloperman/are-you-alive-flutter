import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:are_you_alive_flutter/config/share_presets.dart';
import 'package:are_you_alive_flutter/models/badge_models.dart';
import 'package:are_you_alive_flutter/models/share_models.dart';
import 'package:are_you_alive_flutter/services/progress_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProgressShareService', () {
    test('builds certificate content with cumulative hours and rank', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'metrics.checkin.historyJson': jsonEncode(<Map<String, int>>[
          <String, int>{'timestampMs': 1000},
          <String, int>{'timestampMs': 1000 + 5 * 60 * 60 * 1000},
          <String, int>{'timestampMs': 1000 + 8 * 60 * 60 * 1000},
        ]),
      });

      final service = ProgressShareService();
      final preset = sharePresets.firstWhere(
        (item) => item.id == 'certificate_of_participation',
      );

      final snapshot = BadgeSnapshot(
        appOpenStats: const AppOpenStats(
          total: 10,
          today: 1,
          week: 3,
          month: 10,
          year: 10,
          dailyBuckets: <String, int>{},
        ),
        badges: const <BadgeProgress>[
          BadgeProgress(
            definition: BadgeDefinition(
              id: BadgeId.metronome,
              title: 'Metronome',
              description: 'desc',
            ),
            earned: true,
            earnedAtMs: 12345,
            progress: 1,
            current: 1,
            target: 1,
            hint: 'Unlocked',
          ),
        ],
        topBadge: const BadgeProgress(
          definition: BadgeDefinition(
            id: BadgeId.metronome,
            title: 'Metronome',
            description: 'desc',
          ),
          earned: true,
          earnedAtMs: 12345,
          progress: 1,
          current: 1,
          target: 1,
          hint: 'Unlocked',
        ),
      );

      final content = await service.buildContent(
        preset: preset,
        selectedFields: preset.defaultFields,
        input: SharePayloadInput(
          streakDays: 12,
          remaining: const Duration(hours: 10),
          timerMessage: 'check in',
          userName: 'Yash',
          now: DateTime(2026, 2, 9, 12, 0),
          badgeSnapshot: snapshot,
          notificationTimestampMs: DateTime(
            2026,
            2,
            10,
            12,
            0,
          ).millisecondsSinceEpoch,
        ),
      );

      expect(content.caption, contains('8 hours'));
      expect(content.caption, contains('Metronome'));
      expect(content.imageLines.join(' '), contains('8 hours'));
    });

    test('battery preset uses battery template and keeps username private', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final service = ProgressShareService();
      final preset = sharePresets.firstWhere(
        (item) => item.id == 'existential_battery',
      );

      final content = await service.buildContent(
        preset: preset,
        selectedFields: preset.defaultFields,
        input: SharePayloadInput(
          streakDays: 2,
          remaining: const Duration(hours: 4),
          timerMessage: 'check in',
          userName: 'Private Name',
          now: DateTime(2026, 2, 9, 18, 0),
          badgeSnapshot: null,
          notificationTimestampMs: null,
        ),
      );

      expect(content.imageLines.join(' '), isNot(contains('Private Name')));
      expect(content.imageLines.join(' '), contains('Existential dread battery'));
      expect(content.caption, contains('Temporarily stable'));
    });
  });
}
