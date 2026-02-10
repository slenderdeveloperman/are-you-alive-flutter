class AppOpenStats {
  const AppOpenStats({
    required this.total,
    required this.today,
    required this.week,
    required this.month,
    required this.year,
    required this.dailyBuckets,
  });

  final int total;
  final int today;
  final int week;
  final int month;
  final int year;
  final Map<String, int> dailyBuckets;
}

enum BadgeId {
  pulseParanoid,
  hypervigilant,
  cliffhanger,
  lastBreath,
  metronome,
  safeKeeper,
  ironRoutine,
  phoenix,
}

class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.title,
    required this.description,
  });

  final BadgeId id;
  final String title;
  final String description;
}

class BadgeProgress {
  const BadgeProgress({
    required this.definition,
    required this.earned,
    required this.earnedAtMs,
    required this.progress,
    required this.current,
    required this.target,
    required this.hint,
  });

  final BadgeDefinition definition;
  final bool earned;
  final int? earnedAtMs;
  final double progress;
  final int current;
  final int target;
  final String hint;
}

class BadgeSnapshot {
  const BadgeSnapshot({
    required this.appOpenStats,
    required this.badges,
    required this.topBadge,
  });

  final AppOpenStats appOpenStats;
  final List<BadgeProgress> badges;
  final BadgeProgress topBadge;
}
