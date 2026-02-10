import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/badge_models.dart';
import 'app_open_tracker_service.dart';
import 'metrics_schema_service.dart';

class BadgeService {
  BadgeService._();
  static final BadgeService _instance = BadgeService._();
  factory BadgeService() => _instance;

  static const String _checkInHistoryKey = 'metrics.checkin.historyJson';
  static const String _deathHistoryKey = 'metrics.death.historyJson';
  static const String _deathCountKey = 'metrics.death.count';
  static const String _earnedBadgesKey = 'metrics.badges.earnedJson';

  static const int _maxCheckInHistory = 500;
  static const int _maxDeathHistory = 200;

  static const Map<BadgeId, BadgeDefinition> _definitions = {
    BadgeId.pulseParanoid: BadgeDefinition(
      id: BadgeId.pulseParanoid,
      title: 'Pulse Paranoid',
      description: 'Opened the app 56+ times this week.',
    ),
    BadgeId.hypervigilant: BadgeDefinition(
      id: BadgeId.hypervigilant,
      title: 'Hypervigilant',
      description: 'Opened the app 20+ times in a day.',
    ),
    BadgeId.cliffhanger: BadgeDefinition(
      id: BadgeId.cliffhanger,
      title: 'Cliffhanger',
      description: 'Saved it with <=2h left, 3+ times in 14 days.',
    ),
    BadgeId.lastBreath: BadgeDefinition(
      id: BadgeId.lastBreath,
      title: 'Last Breath',
      description: 'Checked in with <=10m remaining.',
    ),
    BadgeId.metronome: BadgeDefinition(
      id: BadgeId.metronome,
      title: 'Metronome',
      description: '14-day streak with consistent check-in timing.',
    ),
    BadgeId.safeKeeper: BadgeDefinition(
      id: BadgeId.safeKeeper,
      title: 'Safe Keeper',
      description: '7 early check-ins in a row (>=12h left).',
    ),
    BadgeId.ironRoutine: BadgeDefinition(
      id: BadgeId.ironRoutine,
      title: 'Iron Routine',
      description: '30-day streak.',
    ),
    BadgeId.phoenix: BadgeDefinition(
      id: BadgeId.phoenix,
      title: 'Phoenix',
      description: 'Recovered to a 7-day streak after death.',
    ),
  };

  Future<void> recordCheckInEvent({
    required DateTime now,
    required Duration remaining,
  }) async {
    await MetricsSchemaService().ensureCurrent();
    final prefs = await SharedPreferences.getInstance();
    final history = _loadList(prefs.getString(_checkInHistoryKey));

    history.add({
      'timestampMs': now.millisecondsSinceEpoch,
      'remainingMs': remaining.inMilliseconds,
    });

    if (history.length > _maxCheckInHistory) {
      history.removeRange(0, history.length - _maxCheckInHistory);
    }

    await prefs.setString(_checkInHistoryKey, jsonEncode(history));
  }

  Future<void> recordDeathEvent({required DateTime now}) async {
    await MetricsSchemaService().ensureCurrent();
    final prefs = await SharedPreferences.getInstance();
    final history = _loadList(prefs.getString(_deathHistoryKey));

    history.add({'timestampMs': now.millisecondsSinceEpoch});

    if (history.length > _maxDeathHistory) {
      history.removeRange(0, history.length - _maxDeathHistory);
    }

    await prefs.setString(_deathHistoryKey, jsonEncode(history));
    await prefs.setInt(_deathCountKey, (prefs.getInt(_deathCountKey) ?? 0) + 1);
  }

  Future<BadgeSnapshot> evaluate({required DateTime now}) async {
    await MetricsSchemaService().ensureCurrent();
    final prefs = await SharedPreferences.getInstance();
    final appOpenStats = await AppOpenTrackerService().getStats(now: now);

    final streakCount = prefs.getInt('streakCount') ?? 0;
    final checkIns = _loadList(prefs.getString(_checkInHistoryKey));
    final deaths = _loadList(prefs.getString(_deathHistoryKey));
    final earnedMap = _loadEarnedMap(prefs.getString(_earnedBadgesKey));

    final lateCheckIns14 = _countLateCheckIns(
      checkIns: checkIns,
      maxRemaining: const Duration(hours: 2),
      withinDays: 14,
      now: now,
    );

    final lastBreathCount = _countLateCheckIns(
      checkIns: checkIns,
      maxRemaining: const Duration(minutes: 10),
      withinDays: 365,
      now: now,
    );

    final earlyStreak = _countConsecutiveEarlyCheckIns(
      checkIns: checkIns,
      minRemaining: const Duration(hours: 12),
    );

    final dayPeak = appOpenStats.dailyBuckets.values.fold<int>(
      0,
      (maxValue, item) => item > maxValue ? item : maxValue,
    );

    final metronomeConsistency = _metronomeConsistency(checkIns);

    final progressByBadge =
        <
          BadgeId,
          ({
            int current,
            int target,
            bool unlocked,
            String hint,
            double progress,
          })
        >{
          BadgeId.pulseParanoid: (
            current: appOpenStats.week,
            target: 56,
            unlocked: appOpenStats.week >= 56,
            hint:
                '${(56 - appOpenStats.week).clamp(0, 56)} opens left this week',
            progress: (appOpenStats.week / 56).clamp(0, 1),
          ),
          BadgeId.hypervigilant: (
            current: dayPeak,
            target: 20,
            unlocked: dayPeak >= 20,
            hint:
                '${(20 - dayPeak).clamp(0, 20)} opens away from your busiest day',
            progress: (dayPeak / 20).clamp(0, 1),
          ),
          BadgeId.cliffhanger: (
            current: lateCheckIns14,
            target: 3,
            unlocked: lateCheckIns14 >= 3,
            hint: '${(3 - lateCheckIns14).clamp(0, 3)} clutch check-ins left',
            progress: (lateCheckIns14 / 3).clamp(0, 1),
          ),
          BadgeId.lastBreath: (
            current: lastBreathCount,
            target: 1,
            unlocked: lastBreathCount >= 1,
            hint: 'Check in with under 10 minutes once',
            progress: (lastBreathCount / 1).clamp(0, 1),
          ),
          BadgeId.metronome: (
            current: streakCount,
            target: 14,
            unlocked: streakCount >= 14 && metronomeConsistency >= 1,
            hint: streakCount < 14
                ? '${(14 - streakCount).clamp(0, 14)} streak days left'
                : 'Keep check-in times tightly consistent',
            progress: ((streakCount / 14).clamp(0, 1) * metronomeConsistency)
                .clamp(0, 1),
          ),
          BadgeId.safeKeeper: (
            current: earlyStreak,
            target: 7,
            unlocked: earlyStreak >= 7,
            hint:
                '${(7 - earlyStreak).clamp(0, 7)} early check-ins in a row left',
            progress: (earlyStreak / 7).clamp(0, 1),
          ),
          BadgeId.ironRoutine: (
            current: streakCount,
            target: 30,
            unlocked: streakCount >= 30,
            hint:
                '${(30 - streakCount).clamp(0, 30)} streak days to iron routine',
            progress: (streakCount / 30).clamp(0, 1),
          ),
          BadgeId.phoenix: (
            current: streakCount,
            target: 7,
            unlocked: deaths.isNotEmpty && streakCount >= 7,
            hint: deaths.isEmpty
                ? 'First, survive a death and rise again'
                : '${(7 - streakCount).clamp(0, 7)} streak days since rebirth',
            progress: deaths.isEmpty ? 0 : (streakCount / 7).clamp(0, 1),
          ),
        };

    var earnedChanged = false;
    for (final entry in progressByBadge.entries) {
      if (entry.value.unlocked && !earnedMap.containsKey(entry.key.name)) {
        earnedMap[entry.key.name] = now.millisecondsSinceEpoch;
        earnedChanged = true;
      }
    }

    if (earnedChanged) {
      await prefs.setString(_earnedBadgesKey, jsonEncode(earnedMap));
    }

    final badges = <BadgeProgress>[];
    for (final id in BadgeId.values) {
      final definition = _definitions[id]!;
      final metric = progressByBadge[id]!;
      final earnedAt = earnedMap[id.name];
      badges.add(
        BadgeProgress(
          definition: definition,
          earned: earnedAt != null,
          earnedAtMs: earnedAt,
          progress: earnedAt != null ? 1 : metric.progress,
          current: metric.current,
          target: metric.target,
          hint: earnedAt != null ? 'Unlocked' : metric.hint,
        ),
      );
    }

    badges.sort((a, b) {
      if (a.earned != b.earned) return a.earned ? -1 : 1;
      return b.progress.compareTo(a.progress);
    });

    return BadgeSnapshot(
      appOpenStats: appOpenStats,
      badges: badges,
      topBadge: badges.first,
    );
  }

  List<Map<String, dynamic>> _loadList(String? encoded) {
    if (encoded == null || encoded.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded.whereType<Map>().map((item) {
        return item.map((key, value) => MapEntry('$key', value));
      }).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Map<String, int> _loadEarnedMap(String? encoded) {
    if (encoded == null || encoded.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return <String, int>{};
      return decoded.map(
        (key, value) => MapEntry('$key', (value as num?)?.toInt() ?? 0),
      );
    } catch (_) {
      return <String, int>{};
    }
  }

  int _countLateCheckIns({
    required List<Map<String, dynamic>> checkIns,
    required Duration maxRemaining,
    required int withinDays,
    required DateTime now,
  }) {
    final cutoff = now
        .subtract(Duration(days: withinDays))
        .millisecondsSinceEpoch;
    return checkIns.where((item) {
      final ts = (item['timestampMs'] as num?)?.toInt() ?? 0;
      final remaining = (item['remainingMs'] as num?)?.toInt() ?? 0;
      return ts >= cutoff && remaining <= maxRemaining.inMilliseconds;
    }).length;
  }

  int _countConsecutiveEarlyCheckIns({
    required List<Map<String, dynamic>> checkIns,
    required Duration minRemaining,
  }) {
    var count = 0;
    for (var i = checkIns.length - 1; i >= 0; i--) {
      final remaining = (checkIns[i]['remainingMs'] as num?)?.toInt() ?? 0;
      if (remaining >= minRemaining.inMilliseconds) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  double _metronomeConsistency(List<Map<String, dynamic>> checkIns) {
    if (checkIns.length < 5) return 0;

    final recent = checkIns.skip(max(0, checkIns.length - 10)).toList();
    final minuteMarks = recent.map((item) {
      final ts = (item['timestampMs'] as num?)?.toInt() ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      return dt.hour * 60 + dt.minute;
    }).toList();

    final mean = minuteMarks.reduce((a, b) => a + b) / minuteMarks.length;
    final variance =
        minuteMarks
            .map((value) => pow(value - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        minuteMarks.length;
    final stdDevMinutes = sqrt(variance);

    if (stdDevMinutes <= 90) return 1;
    if (stdDevMinutes >= 240) return 0;
    return (1 - ((stdDevMinutes - 90) / 150)).clamp(0, 1);
  }
}
