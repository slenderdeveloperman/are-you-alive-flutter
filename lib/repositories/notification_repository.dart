import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationRepository {
  static final NotificationRepository _instance =
      NotificationRepository._internal();
  factory NotificationRepository() => _instance;
  NotificationRepository._internal();

  static const String _orderKey = 'thirtyHourNotificationOrder';
  static const String _indexKey = 'thirtyHourNotificationIndex';

  static const List<String> _thirtyHourMessages = [
    'FILING NOTICE / 30 HOURS ELAPSED / confirmation requested.',
    'CONTINUED EXISTENCE REGISTER / no new filing received in 30 hours.',
    'FLD-AYA-01 / filing window remains open / confirmation requested.',
    'BUREAU NOTICE / continued existence requires a current filing.',
    'RECORD STATUS / active, approaching deadline / file when able.',
    'F.C.C.D.B. / 30-hour reminder / no action has been recorded.',
    'EXISTENCE REGISTER / filing outstanding / window closes at 39 hours.',
    'FLD-AYA-01 / subject record awaiting confirmation.',
  ];

  Future<String> nextThirtyHourMessage() async {
    final prefs = await SharedPreferences.getInstance();
    var order = prefs.getStringList(_orderKey);
    var index = prefs.getInt(_indexKey) ?? 0;

    final needsFreshShuffle =
        order == null ||
        order.length != _thirtyHourMessages.length ||
        index < 0 ||
        index >= order.length;

    if (needsFreshShuffle) {
      order = List<String>.from(_thirtyHourMessages)..shuffle(Random());
      index = 0;
    }

    final message = order[index];
    final nextIndex = index + 1;

    if (nextIndex >= order.length) {
      final reshuffled = List<String>.from(_thirtyHourMessages)
        ..shuffle(Random());
      await prefs.setStringList(_orderKey, reshuffled);
      await prefs.setInt(_indexKey, 0);
    } else {
      await prefs.setStringList(_orderKey, order);
      await prefs.setInt(_indexKey, nextIndex);
    }

    return message;
  }
}
