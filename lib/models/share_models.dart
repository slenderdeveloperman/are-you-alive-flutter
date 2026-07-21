import 'package:flutter/foundation.dart';

import 'badge_models.dart';

enum ShareField {
  cumulativeHours,
  rankTitle,
  checkInMargin,
  stabilityStatus,
  nextDeadline,
  streakDays,
  tallyGroups,
  userName,
  proofTimestamp,
  lastCheckInMargin,
}

enum SharePrivacyLevel { low, medium, high }

enum ShareTheme { certificate, battery, timeServed, proofOfLife, nearMiss }

@immutable
class SharePreset {
  const SharePreset({
    required this.id,
    required this.title,
    required this.description,
    required this.theme,
    required this.thumbnailAssetPath,
    required this.backgroundAssetPath,
    required this.imageTemplates,
    required this.captionTemplate,
    required this.defaultFields,
    required this.optionalFields,
    required this.privacyLevel,
    this.supportsImage = true,
    this.supportsCaption = true,
  });

  final String id;
  final String title;
  final String description;
  final ShareTheme theme;
  final String thumbnailAssetPath;
  final String backgroundAssetPath;
  final List<String> imageTemplates;
  final String captionTemplate;
  final Set<ShareField> defaultFields;
  final Set<ShareField> optionalFields;
  final SharePrivacyLevel privacyLevel;
  final bool supportsImage;
  final bool supportsCaption;

  Set<ShareField> get allFields => <ShareField>{
    ...defaultFields,
    ...optionalFields,
  };
}

@immutable
class SharePayloadInput {
  const SharePayloadInput({
    required this.streakDays,
    required this.remaining,
    required this.timerMessage,
    required this.userName,
    required this.now,
    required this.badgeSnapshot,
    required this.notificationTimestampMs,
  });

  final int streakDays;
  final Duration remaining;
  final String timerMessage;
  final String userName;
  final DateTime now;
  final BadgeSnapshot? badgeSnapshot;
  final int? notificationTimestampMs;
}

@immutable
class ShareContent {
  const ShareContent({
    required this.preset,
    required this.imageLines,
    required this.caption,
  });

  final SharePreset preset;
  final List<String> imageLines;
  final String caption;
}
