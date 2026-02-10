import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/badge_models.dart';
import 'metrics_schema_service.dart';

class AppOpenTrackerService {
  AppOpenTrackerService._();
  static final AppOpenTrackerService _instance = AppOpenTrackerService._();
  factory AppOpenTrackerService() => _instance;

  static const String _totalKey = 'metrics.open.total';
  static const String _dailyBucketsKey = 'metrics.open.dailyBucketsJson';
  static const int _maxHistoryDays = 400;

  Future<void> recordOpen({required DateTime now}) async {
    await MetricsSchemaService().ensureCurrent();
    final prefs = await SharedPreferences.getInstance();
    final buckets = _loadBuckets(prefs);
    final key = _dateKey(now);

    buckets[key] = (buckets[key] ?? 0) + 1;
    _pruneBuckets(buckets, now);

    final total = (prefs.getInt(_totalKey) ?? 0) + 1;
    await prefs.setInt(_totalKey, total);
    await prefs.setString(_dailyBucketsKey, jsonEncode(buckets));
  }

  Future<AppOpenStats> getStats({required DateTime now}) async {
    await MetricsSchemaService().ensureCurrent();
    final prefs = await SharedPreferences.getInstance();
    final buckets = _loadBuckets(prefs);
    _pruneBuckets(buckets, now);
    await prefs.setString(_dailyBucketsKey, jsonEncode(buckets));

    final todayKey = _dateKey(now);
    final today = buckets[todayKey] ?? 0;

    final startOfWeek = _startOfWeek(now);
    final week = buckets.entries
        .where((entry) => _parseDate(entry.key)?.isBefore(startOfWeek) == false)
        .fold<int>(0, (sum, entry) => sum + entry.value);

    final month = buckets.entries
        .where((entry) {
          final date = _parseDate(entry.key);
          return date != null &&
              date.year == now.year &&
              date.month == now.month;
        })
        .fold<int>(0, (sum, entry) => sum + entry.value);

    final year = buckets.entries
        .where((entry) {
          final date = _parseDate(entry.key);
          return date != null && date.year == now.year;
        })
        .fold<int>(0, (sum, entry) => sum + entry.value);

    return AppOpenStats(
      total: prefs.getInt(_totalKey) ?? 0,
      today: today,
      week: week,
      month: month,
      year: year,
      dailyBuckets: Map<String, int>.from(buckets),
    );
  }

  Map<String, int> _loadBuckets(SharedPreferences prefs) {
    final encoded = prefs.getString(_dailyBucketsKey);
    if (encoded == null || encoded.isEmpty) return <String, int>{};

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return <String, int>{};
      return decoded.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      );
    } catch (_) {
      return <String, int>{};
    }
  }

  void _pruneBuckets(Map<String, int> buckets, DateTime now) {
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: _maxHistoryDays));
    final keysToRemove = buckets.keys.where((key) {
      final date = _parseDate(key);
      return date == null || date.isBefore(cutoff);
    }).toList();

    for (final key in keysToRemove) {
      buckets.remove(key);
    }
  }

  DateTime _startOfWeek(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final daysFromMonday = today.weekday - DateTime.monday;
    return today.subtract(Duration(days: daysFromMonday));
  }

  String _dateKey(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  DateTime? _parseDate(String value) {
    try {
      final parts = value.split('-');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }
}
