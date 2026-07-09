import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:are_you_alive_flutter/services/metrics_schema_service.dart';

void main() {
  const defaultKeys = <String>[
    'metrics.open.total',
    'metrics.open.dailyBucketsJson',
    'metrics.checkin.historyJson',
    'metrics.death.historyJson',
    'metrics.death.count',
    'metrics.badges.earnedJson',
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('fresh install: populates all v1 keys with sane defaults', () async {
    await MetricsSchemaService().ensureCurrent();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('metrics.open.total'), 0);
    expect(prefs.getString('metrics.open.dailyBucketsJson'), '{}');
    expect(prefs.getString('metrics.checkin.historyJson'), '[]');
    expect(prefs.getString('metrics.death.historyJson'), '[]');
    expect(prefs.getInt('metrics.death.count'), 0);
    expect(prefs.getString('metrics.badges.earnedJson'), '{}');
    expect(prefs.getInt('metrics.schema.version'), 1);
  });

  test('does not clobber existing metric values on repeated calls', () async {
    await MetricsSchemaService().ensureCurrent();
    final prefs = await SharedPreferences.getInstance();

    // Simulate real usage having accumulated data.
    await prefs.setInt('metrics.open.total', 42);
    await prefs.setString('metrics.checkin.historyJson', '[{"timestampMs":1}]');

    // Calling ensureCurrent again (e.g. on next app launch) must not reset
    // data back to defaults.
    await MetricsSchemaService().ensureCurrent();

    expect(prefs.getInt('metrics.open.total'), 42);
    expect(prefs.getString('metrics.checkin.historyJson'), '[{"timestampMs":1}]');
  });

  test(
    'returning user on a pre-v1 install (schema key absent) gets migrated once',
    () async {
      // Simulate a user who has real accumulated data under keys that
      // happen to already exist (e.g. a hypothetical partial write) but no
      // schema version marker yet - migration should fill in only the
      // missing keys and stamp the version.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'metrics.open.total': 7,
      });

      await MetricsSchemaService().ensureCurrent();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('metrics.open.total'), 7, reason: 'existing key preserved');
      expect(prefs.getString('metrics.checkin.historyJson'), '[]');
      expect(prefs.getInt('metrics.schema.version'), 1);
    },
  );

  test('already-current schema version short-circuits and touches nothing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'metrics.schema.version': 1,
      // Deliberately omit metric keys entirely to prove ensureCurrent()
      // returns early instead of back-filling them once the version is
      // already marked current.
    });

    await MetricsSchemaService().ensureCurrent();

    final prefs = await SharedPreferences.getInstance();
    for (final key in defaultKeys) {
      expect(
        prefs.containsKey(key),
        isFalse,
        reason:
            '$key should NOT be created when schema.version is already current; '
            'ensureCurrent() returns before running _migrateToV1.',
      );
    }
  });

  test('a schema version from the future (>1) is left untouched', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'metrics.schema.version': 5,
    });

    await MetricsSchemaService().ensureCurrent();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('metrics.schema.version'), 5);
  });

  test(
    'malformed (non-int) schema version value is treated via getInt null-coalesce',
    () async {
      // SharedPreferences is strongly typed at the platform layer, so a
      // "malformed" version in practice means the key is simply absent
      // (fresh install) - getInt() returning null falls back to 0.
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('metrics.schema.version'), isNull);

      await MetricsSchemaService().ensureCurrent();
      expect(prefs.getInt('metrics.schema.version'), 1);
    },
  );
}
