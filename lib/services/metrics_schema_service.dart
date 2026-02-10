import 'package:shared_preferences/shared_preferences.dart';

class MetricsSchemaService {
  MetricsSchemaService._();
  static final MetricsSchemaService _instance = MetricsSchemaService._();
  factory MetricsSchemaService() => _instance;

  static const int _currentVersion = 1;
  static const String _schemaVersionKey = 'metrics.schema.version';

  Future<void> ensureCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final existingVersion = prefs.getInt(_schemaVersionKey) ?? 0;

    if (existingVersion >= _currentVersion) {
      return;
    }

    if (existingVersion < 1) {
      await _migrateToV1(prefs);
    }

    await prefs.setInt(_schemaVersionKey, _currentVersion);
  }

  Future<void> _migrateToV1(SharedPreferences prefs) async {
    if (!prefs.containsKey('metrics.open.total')) {
      await prefs.setInt('metrics.open.total', 0);
    }
    if (!prefs.containsKey('metrics.open.dailyBucketsJson')) {
      await prefs.setString('metrics.open.dailyBucketsJson', '{}');
    }
    if (!prefs.containsKey('metrics.checkin.historyJson')) {
      await prefs.setString('metrics.checkin.historyJson', '[]');
    }
    if (!prefs.containsKey('metrics.death.historyJson')) {
      await prefs.setString('metrics.death.historyJson', '[]');
    }
    if (!prefs.containsKey('metrics.death.count')) {
      await prefs.setInt('metrics.death.count', 0);
    }
    if (!prefs.containsKey('metrics.badges.earnedJson')) {
      await prefs.setString('metrics.badges.earnedJson', '{}');
    }
  }
}
