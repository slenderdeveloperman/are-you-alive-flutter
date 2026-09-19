import 'package:flutter_test/flutter_test.dart';

import 'package:are_you_alive_flutter/models/existence_record.dart';

void main() {
  final filed = DateTime.utc(2026, 9, 19, 0);

  test('39 hours is the single filing window', () {
    final record = ExistenceRecord.fromLastCheckIn(
      lastCheckIn: filed,
      now: filed.add(const Duration(hours: 10)),
    );
    expect(record.deadline, filed.add(const Duration(hours: 39)));
    expect(record.remaining, const Duration(hours: 29));
    expect(record.status, ExistenceStatus.active);
  });

  test('30h and 36h thresholds produce due states', () {
    expect(
      ExistenceRecord.fromLastCheckIn(
        lastCheckIn: filed,
        now: filed.add(const Duration(hours: 30)),
      ).status,
      ExistenceStatus.dueSoon,
    );
    expect(
      ExistenceRecord.fromLastCheckIn(
        lastCheckIn: filed,
        now: filed.add(const Duration(hours: 36)),
      ).status,
      ExistenceStatus.actionRequired,
    );
  });

  test('lapse does not silently create a fresh window', () {
    final record = ExistenceRecord.fromLastCheckIn(
      lastCheckIn: filed,
      now: filed.add(const Duration(hours: 41)),
    );
    expect(record.status, ExistenceStatus.lapsed);
    expect(record.remaining, Duration.zero);
    expect(record.deadline, filed.add(const Duration(hours: 39)));
  });

  test('clock rollback cannot produce a lapsed/negative record', () {
    final record = ExistenceRecord.fromLastCheckIn(
      lastCheckIn: filed,
      now: filed.subtract(const Duration(minutes: 5)),
    );
    expect(record.status, ExistenceStatus.active);
    expect(record.remaining, greaterThan(const Duration(hours: 39)));
  });
}
