import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/share_models.dart';

class ProgressShareService {
  static const String _checkInHistoryKey = 'metrics.checkin.historyJson';
  static const Duration _checkInWindow = Duration(hours: 39);
  static const Duration _nearMissThreshold = Duration(hours: 6);

  static const Map<String, ShareField> _tokenFieldMap = <String, ShareField>{
    '{cumulative_hours_text}': ShareField.cumulativeHours,
    '{rank_title}': ShareField.rankTitle,
    '{checkin_margin_text}': ShareField.checkInMargin,
    '{stability_status}': ShareField.stabilityStatus,
    '{next_deadline_text}': ShareField.nextDeadline,
    '{streak_days_text}': ShareField.streakDays,
    '{tally_text}': ShareField.tallyGroups,
    '{user_name_or_fallback}': ShareField.userName,
    '{proof_timestamp_text}': ShareField.proofTimestamp,
    '{last_checkin_margin_text}': ShareField.lastCheckInMargin,
    '{last_checkin_hour_mark}': ShareField.lastCheckInMargin,
  };

  /// Whether the most recorded check-in landed within [_nearMissThreshold]
  /// of the 39-hour deadline — the moment the near-miss preset is built for.
  Future<bool> isNearMissEligible() async {
    final margin = await _lastCheckInMargin();
    return margin != null && margin <= _nearMissThreshold;
  }

  Future<Duration?> _lastCheckInMargin() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_checkInHistoryKey);
    if (encoded == null || encoded.isEmpty) return null;

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List || decoded.isEmpty) return null;

      final entries = decoded.whereType<Map>().toList()
        ..sort((a, b) {
          final aMs = (a['timestampMs'] as num?)?.toInt() ?? 0;
          final bMs = (b['timestampMs'] as num?)?.toInt() ?? 0;
          return aMs.compareTo(bMs);
        });

      final remainingMs = (entries.last['remainingMs'] as num?)?.toInt();
      if (remainingMs == null) return null;

      return Duration(milliseconds: remainingMs.clamp(0, 1 << 40));
    } catch (_) {
      return null;
    }
  }

  Future<ShareContent> buildContent({
    required SharePreset preset,
    required Set<ShareField> selectedFields,
    required SharePayloadInput input,
  }) async {
    final tokenValues = await _resolveTokenValues(
      selectedFields: selectedFields,
      input: input,
    );

    final imageLines = preset.imageTemplates
        .map((template) => _fillTemplate(template, tokenValues, selectedFields))
        .where((line) => line.isNotEmpty)
        .toList();

    final caption = _fillTemplate(
      preset.captionTemplate,
      tokenValues,
      selectedFields,
    );

    return ShareContent(
      preset: preset,
      imageLines: imageLines,
      caption: caption.isEmpty ? 'Still alive. #AreYouAlive' : caption,
    );
  }

  Future<void> shareProgress({
    required String caption,
    Uint8List? imageBytes,
  }) async {
    final normalizedCaption = caption.trim().isEmpty
        ? 'Still alive. #AreYouAlive'
        : caption.trim();

    if (imageBytes != null && imageBytes.isNotEmpty) {
      try {
        await Share.shareXFiles(
          <XFile>[
            XFile.fromData(
              imageBytes,
              mimeType: 'image/png',
              name: 'are-you-alive-share.png',
            ),
          ],
          text: normalizedCaption,
          subject: 'Are You Alive?',
        );
        return;
      } catch (_) {
        // Fall through to text-only share.
      }
    }

    await Share.share(normalizedCaption, subject: 'Are You Alive?');
  }

  Future<Map<String, String>> _resolveTokenValues({
    required Set<ShareField> selectedFields,
    required SharePayloadInput input,
  }) async {
    final cumulativeHours = await _calculateCumulativeHours(
      fallbackStreak: input.streakDays,
    );
    final lastCheckInMargin = await _lastCheckInMargin() ?? input.remaining;

    return <String, String>{
      '{cumulative_hours_text}': '$cumulativeHours hours',
      '{rank_title}': _resolveRankTitle(input),
      '{checkin_margin_text}': _humanizeDuration(input.remaining),
      '{stability_status}': _resolveStabilityStatus(input.remaining),
      '{next_deadline_text}': _formatDeadline(input.notificationTimestampMs),
      '{streak_days_text}':
          '${input.streakDays} ${input.streakDays == 1 ? 'day' : 'days'} alive',
      '{tally_text}': selectedFields.contains(ShareField.tallyGroups)
          ? _buildTallyMarks(input.streakDays)
          : '',
      '{user_name_or_fallback}':
          selectedFields.contains(ShareField.userName) &&
              input.userName.trim().isNotEmpty
          ? input.userName.trim()
          : 'Subject',
      '{proof_timestamp_text}': _formatDateTime(input.now),
      '{last_checkin_margin_text}': _humanizeDuration(lastCheckInMargin),
      '{last_checkin_hour_mark}': '${_hourMark(lastCheckInMargin)}',
    };
  }

  int _hourMark(Duration margin) {
    final used = _checkInWindow - margin;
    if (used.isNegative) return 1;
    final wholeHours = used.inHours;
    final hasRemainder = used.inMinutes % 60 > 0;
    return (wholeHours + (hasRemainder ? 1 : 0)).clamp(1, 39);
  }

  Future<int> _calculateCumulativeHours({required int fallbackStreak}) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_checkInHistoryKey);
    if (encoded == null || encoded.isEmpty) {
      return fallbackStreak * 24;
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List || decoded.length < 2) {
        return fallbackStreak * 24;
      }

      final timestamps =
          decoded
              .whereType<Map>()
              .map((entry) => (entry['timestampMs'] as num?)?.toInt())
              .whereType<int>()
              .toList()
            ..sort();

      if (timestamps.length < 2) {
        return fallbackStreak * 24;
      }

      var totalMs = 0;
      for (var i = 1; i < timestamps.length; i++) {
        final delta = timestamps[i] - timestamps[i - 1];
        if (delta <= 0) continue;
        totalMs += delta.clamp(0, const Duration(hours: 39).inMilliseconds);
      }

      final hours = (totalMs / const Duration(hours: 1).inMilliseconds)
          .round()
          .clamp(0, 999999);

      if (hours == 0 && fallbackStreak > 0) {
        return fallbackStreak * 24;
      }

      return hours;
    } catch (_) {
      return fallbackStreak * 24;
    }
  }

  String _fillTemplate(
    String template,
    Map<String, String> values,
    Set<ShareField> selectedFields,
  ) {
    var resolved = template;

    for (final entry in _tokenFieldMap.entries) {
      final token = entry.key;
      final field = entry.value;
      final replacement = selectedFields.contains(field)
          ? values[token] ?? ''
          : '';
      resolved = resolved.replaceAll(token, replacement);
    }

    resolved = resolved
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s+([,.!?;:])'), r'$1')
        .trim();

    if (resolved == '.' || resolved == ',' || resolved == ':') {
      return '';
    }

    return resolved;
  }

  String _resolveRankTitle(SharePayloadInput input) {
    final snapshot = input.badgeSnapshot;
    if (snapshot == null) return 'Unranked Survivor';

    final earned = snapshot.badges.where((badge) => badge.earned).toList()
      ..sort((a, b) => (b.earnedAtMs ?? 0).compareTo(a.earnedAtMs ?? 0));

    if (earned.isNotEmpty) {
      return earned.first.definition.title;
    }

    return snapshot.topBadge.definition.title;
  }

  String _resolveStabilityStatus(Duration remaining) {
    if (remaining >= const Duration(hours: 12)) {
      return 'TEMPORARILY STABLE';
    }
    if (remaining >= const Duration(hours: 2)) {
      return 'CAUTIOUSLY STABLE';
    }
    return 'CRITICALLY MOTIVATED';
  }

  String _formatDeadline(int? notificationTimestampMs) {
    if (notificationTimestampMs == null) return 'unknown deadline';
    return _formatDateTime(
      DateTime.fromMillisecondsSinceEpoch(notificationTimestampMs),
    );
  }

  String _formatDateTime(DateTime value) {
    final monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = monthNames[value.month - 1];
    final day = value.day;
    final year = value.year;
    final hour24 = value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final meridiem = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$month $day, $year $hour12:$minute $meridiem';
  }

  String _humanizeDuration(Duration duration) {
    var safe = duration;
    if (safe.isNegative) safe = Duration.zero;
    final hours = safe.inHours;
    final minutes = safe.inMinutes % 60;
    if (hours == 0) {
      return '${minutes}m';
    }
    if (minutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${minutes}m';
  }

  String _buildTallyMarks(int streakDays) {
    if (streakDays <= 0) return '';
    final requestedGroups = (streakDays / 5).ceil();
    final groups = requestedGroups.clamp(1, 20);
    final marks = List<String>.filled(groups, '||||/').join(' ');
    final overflow = requestedGroups - groups;
    if (overflow > 0) {
      return '$marks +$overflow';
    }
    return marks;
  }
}
