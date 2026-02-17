import '../models/share_models.dart';

const List<SharePreset> sharePresets = <SharePreset>[
  SharePreset(
    id: 'certificate_of_participation',
    title: 'Certificate',
    description: 'Existential battery artwork',
    theme: ShareTheme.certificate,
    thumbnailAssetPath: 'assets/share_presets/certificate_preset.png',
    backgroundAssetPath: 'assets/share_presets/certificate_preset.png',
    imageTemplates: <String>[
      'Certificate of Participation in Reality.',
      'I\'ve wasted {cumulative_hours_text} on this app.',
      'Current Rank: {rank_title}.',
      '{streak_days_text}',
    ],
    captionTemplate:
        'Certified alive. {cumulative_hours_text} invested. Rank: {rank_title}. #AreYouAlive',
    defaultFields: <ShareField>{
      ShareField.cumulativeHours,
      ShareField.rankTitle,
    },
    optionalFields: <ShareField>{ShareField.streakDays},
    privacyLevel: SharePrivacyLevel.medium,
  ),
  SharePreset(
    id: 'existential_battery',
    title: 'Battery',
    description: 'Participation certificate artwork',
    theme: ShareTheme.battery,
    thumbnailAssetPath: 'assets/share_presets/battery_preset.png',
    backgroundAssetPath: 'assets/share_presets/battery_preset.png',
    imageTemplates: <String>[
      'Existential dread battery status: FULLY CHARGED.',
      'I beat the clock by {checkin_margin_text}.',
      'Status: {stability_status}.',
      'Deadline: {next_deadline_text}',
    ],
    captionTemplate:
        'Temporarily stable. Margin: {checkin_margin_text}. #AreYouAlive',
    defaultFields: <ShareField>{
      ShareField.checkInMargin,
      ShareField.stabilityStatus,
    },
    optionalFields: <ShareField>{ShareField.nextDeadline},
    privacyLevel: SharePrivacyLevel.medium,
  ),
];
