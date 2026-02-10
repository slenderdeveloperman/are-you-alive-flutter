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
    '30 hours? I’ve seen abandoned malls with more signs of life than this account.',
    'I’m not saying you’re dead, but I’ve already started browsing for your replacement.',
    'Checking in. Or is this one of those \'main character\' moments where you disappear for a montage?',
    'Still breathing? Or should I start listing your sneakers on eBay?',
    'Knock knock. Who’s there? Not your pulse, apparently.',
    'Is this a \'ghosting\' situation, or are you actually a ghost? Clarification is appreciated.',
    'I’ve started drafting your eulogy. So far, it’s just a list of your unread notifications.',
    '30 hours is a long time to be \'finding yourself.\' You’re right here. Tap the screen.',
    'I’m five minutes away from DMing your ex to see if they’ve heard anything. Don\'t test me.',
    'If you don\'t respond in the next hour, I\'m legally obligated to assume you\'ve been recruited by a cult.',
  ];

  Future<String> nextThirtyHourMessage() async {
    final prefs = await SharedPreferences.getInstance();
    var order = prefs.getStringList(_orderKey);
    var index = prefs.getInt(_indexKey) ?? 0;

    final needsFreshShuffle =
        order == null ||
        order.length != _thirtyHourMessages.length ||
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
