enum ExistenceStatus { unfiled, active, dueSoon, actionRequired, lapsed }

class ExistenceRecord {
  const ExistenceRecord({
    required this.lastCheckIn,
    required this.deadline,
    required this.remaining,
    required this.status,
  });

  static const Duration filingWindow = Duration(hours: 39);
  static const Duration reminderAt = Duration(hours: 30);
  static const Duration actionRequiredAt = Duration(hours: 36);
  static const Duration witnessGrace = Duration(hours: 2);

  final DateTime? lastCheckIn;
  final DateTime? deadline;
  final Duration remaining;
  final ExistenceStatus status;

  bool get hasFiling => lastCheckIn != null;
  bool get isLapsed => status == ExistenceStatus.lapsed;

  static ExistenceRecord fromLastCheckIn({
    required DateTime? lastCheckIn,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    if (lastCheckIn == null) {
      return const ExistenceRecord(
        lastCheckIn: null,
        deadline: null,
        remaining: filingWindow,
        status: ExistenceStatus.unfiled,
      );
    }

    final deadline = lastCheckIn.add(filingWindow);
    final rawRemaining = deadline.difference(current);
    final remaining = rawRemaining.isNegative ? Duration.zero : rawRemaining;
    final elapsed = current.difference(lastCheckIn);

    final status = rawRemaining.isNegative || rawRemaining == Duration.zero
        ? ExistenceStatus.lapsed
        : elapsed >= actionRequiredAt
        ? ExistenceStatus.actionRequired
        : elapsed >= reminderAt
        ? ExistenceStatus.dueSoon
        : ExistenceStatus.active;

    return ExistenceRecord(
      lastCheckIn: lastCheckIn,
      deadline: deadline,
      remaining: remaining,
      status: status,
    );
  }

  static String statusLabel(ExistenceStatus status) {
    switch (status) {
      case ExistenceStatus.unfiled:
        return 'UNFILED';
      case ExistenceStatus.active:
        return 'ACTIVE';
      case ExistenceStatus.dueSoon:
        return 'DUE SOON';
      case ExistenceStatus.actionRequired:
        return 'ACTION REQUIRED';
      case ExistenceStatus.lapsed:
        return 'LAPSED';
    }
  }
}
