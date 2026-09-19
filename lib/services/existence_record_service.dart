import 'package:shared_preferences/shared_preferences.dart';

import '../models/existence_record.dart';

class ExistenceRecordService {
  ExistenceRecordService({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  static const String lastCheckInTimestampKey = 'lastActiveTimestamp';

  Future<ExistenceRecord> load() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(lastCheckInTimestampKey);
    final last = timestamp == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(timestamp);
    return ExistenceRecord.fromLastCheckIn(lastCheckIn: last, now: _now());
  }

  Future<ExistenceRecord> fileNow() async {
    final prefs = await SharedPreferences.getInstance();
    final now = _now();
    await prefs.setInt(lastCheckInTimestampKey, now.millisecondsSinceEpoch);
    return ExistenceRecord.fromLastCheckIn(lastCheckIn: now, now: now);
  }

  Future<void> setForTest(DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(lastCheckInTimestampKey, value.millisecondsSinceEpoch);
  }
}
