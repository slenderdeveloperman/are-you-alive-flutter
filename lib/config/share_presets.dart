import '../models/share_models.dart';

const List<SharePreset> sharePresets = <SharePreset>[
  SharePreset(
    id: 'certificate_of_participation',
    title: 'Survey Plate',
    description: 'FLD-AYA-01 — the Bureau\'s plate on continued existence.',
    theme: ShareTheme.certificate,
    thumbnailAssetPath: 'assets/share_presets/survey_plate_vesalius.png',
    backgroundAssetPath: 'assets/share_presets/survey_plate_vesalius.png',
    imageTemplates: <String>[
      'PRIMA TABULA.',
      '{cumulative_hours_text} on record.',
      'Class: {rank_title}.',
      '{streak_days_text}',
    ],
    captionTemplate:
        'Filed under FLD-AYA-01. {cumulative_hours_text} on record. Classification: {rank_title}. #AreYouAlive',
    defaultFields: <ShareField>{
      ShareField.cumulativeHours,
      ShareField.rankTitle,
    },
    optionalFields: <ShareField>{ShareField.streakDays},
    privacyLevel: SharePrivacyLevel.medium,
  ),
  SharePreset(
    id: 'existential_battery',
    title: 'Melencolia',
    description: 'FLD-AYA-01 — the hour, weighed.',
    theme: ShareTheme.battery,
    thumbnailAssetPath: 'assets/share_presets/melencolia_durer.png',
    backgroundAssetPath: 'assets/share_presets/melencolia_durer.png',
    imageTemplates: <String>[
      'MELENCOLIA STATUS.',
      'Status: {stability_status}.',
      'Margin: {checkin_margin_text}.',
      'Next: {next_deadline_text}',
    ],
    captionTemplate:
        'Filed and still standing. Margin: {checkin_margin_text}. #AreYouAlive',
    defaultFields: <ShareField>{
      ShareField.checkInMargin,
      ShareField.stabilityStatus,
    },
    optionalFields: <ShareField>{ShareField.nextDeadline},
    privacyLevel: SharePrivacyLevel.medium,
  ),
  SharePreset(
    id: 'near_miss_save',
    title: 'Near Miss',
    description: 'Cut it close. Glitch/countdown artwork.',
    theme: ShareTheme.nearMiss,
    thumbnailAssetPath: '',
    backgroundAssetPath: '',
    imageTemplates: <String>[
      'T-MINUS {last_checkin_margin_text}.',
      'Hour {last_checkin_hour_mark} of 39.',
      'That\'s how close {user_name_or_fallback} cut it.',
      'Still here. Barely.',
    ],
    captionTemplate:
        'Checked in with {last_checkin_margin_text} left on the clock. Hour {last_checkin_hour_mark} of 39. #AreYouAlive',
    defaultFields: <ShareField>{ShareField.lastCheckInMargin},
    optionalFields: <ShareField>{ShareField.userName},
    privacyLevel: SharePrivacyLevel.medium,
  ),
];
