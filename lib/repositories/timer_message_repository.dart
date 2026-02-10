import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class TimerMessageRepository {
  static final TimerMessageRepository _instance =
      TimerMessageRepository._internal();
  factory TimerMessageRepository() => _instance;
  TimerMessageRepository._internal();

  static const String _orderKey = 'timerMessageOrder';
  static const String _indexKey = 'timerMessageIndex';
  static const String _lastDateKey = 'timerMessageLastDate';

  static const List<String> _templates = [
    'Beat the clock, [Name]. You have X hours before I get weird.',
    'X hours left to prove you exist, [Name]. Don\'t make me ask.',
    'Tick tock, [Name]. Tap the button in X hours or the existential dread begins.',
    'You\'ve got X hours, [Name]. Avoid the notification of doom. Your move.',
    'Don\'t trigger me, [Name]. You have X hours to check in.',
  ];

  Future<String> getDailyMessage({
    required String userName,
    required String countdownText,
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final date = _dateOnly(now ?? DateTime.now());

    var order = prefs.getStringList(_orderKey);
    var index = prefs.getInt(_indexKey);
    final lastDate = prefs.getString(_lastDateKey);

    final invalidState =
        order == null ||
        order.length != _templates.length ||
        index == null ||
        index < 0 ||
        index >= _templates.length;

    if (invalidState) {
      order = List<String>.from(_templates)..shuffle(Random());
      index = 0;
      await prefs.setStringList(_orderKey, order);
      await prefs.setInt(_indexKey, index);
      await prefs.setString(_lastDateKey, date);
      return _render(
        template: order[index],
        userName: userName,
        countdownText: countdownText,
      );
    }

    if (lastDate != date) {
      index += 1;

      if (index >= _templates.length) {
        order = List<String>.from(_templates)..shuffle(Random());
        index = 0;
      }

      await prefs.setStringList(_orderKey, order);
      await prefs.setInt(_indexKey, index);
      await prefs.setString(_lastDateKey, date);
    }

    return _render(
      template: order[index],
      userName: userName,
      countdownText: countdownText,
    );
  }

  String _render({
    required String template,
    required String userName,
    required String countdownText,
  }) {
    final safeName = userName.trim().isEmpty ? 'human' : userName.trim();
    return template
        .replaceAll('[Name]', safeName)
        .replaceAll('X', countdownText);
  }

  String _dateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
