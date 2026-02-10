import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:are_you_alive_flutter/repositories/timer_message_repository.dart';

void main() {
  const templates = <String>[
    'Beat the clock, [Name]. You have X hours before I get weird.',
    'X hours left to prove you exist, [Name]. Don\'t make me ask.',
    'Tick tock, [Name]. Tap the button in X hours or the existential dread begins.',
    'You\'ve got X hours, [Name]. Avoid the notification of doom. Your move.',
    'Don\'t trigger me, [Name]. You have X hours to check in.',
  ];

  int templateIndex(String message, String name, String countdown) {
    for (var i = 0; i < templates.length; i++) {
      final expected = templates[i]
          .replaceAll('[Name]', name)
          .replaceAll('X', countdown);
      if (expected == message) return i;
    }
    return -1;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('initializes order and replaces placeholders', () async {
    final repo = TimerMessageRepository();
    final message = await repo.getDailyMessage(
      userName: 'Yash',
      countdownText: '38:52:42',
      now: DateTime(2026, 2, 9),
    );

    expect(message.contains('[Name]'), isFalse);
    expect(message.contains('X'), isFalse);
    expect(message.contains('Yash'), isTrue);
    expect(message.contains('38:52:42'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('timerMessageOrder')?.length, templates.length);
    expect(prefs.getInt('timerMessageIndex'), isNotNull);
    expect(prefs.getString('timerMessageLastDate'), '2026-02-09');
  });

  test(
    'same day keeps the same template while allowing updated countdown',
    () async {
      final repo = TimerMessageRepository();
      final sameDate = DateTime(2026, 2, 9);

      final first = await repo.getDailyMessage(
        userName: 'Yash',
        countdownText: '39:00:00',
        now: sameDate,
      );
      final second = await repo.getDailyMessage(
        userName: 'Yash',
        countdownText: '38:59:10',
        now: sameDate,
      );

      final index1 = templateIndex(first, 'Yash', '39:00:00');
      final index2 = templateIndex(second, 'Yash', '38:59:10');
      expect(index1, greaterThanOrEqualTo(0));
      expect(index2, index1);
    },
  );

  test('next day advances to the next template in stored order', () async {
    final repo = TimerMessageRepository();
    final day1 = DateTime(2026, 2, 9);
    final day2 = DateTime(2026, 2, 10);

    final first = await repo.getDailyMessage(
      userName: 'Yash',
      countdownText: '39:00:00',
      now: day1,
    );
    final second = await repo.getDailyMessage(
      userName: 'Yash',
      countdownText: '39:00:00',
      now: day2,
    );

    final index1 = templateIndex(first, 'Yash', '39:00:00');
    final index2 = templateIndex(second, 'Yash', '39:00:00');
    expect(index1, greaterThanOrEqualTo(0));
    expect(index2, greaterThanOrEqualTo(0));
    expect(index2, isNot(index1));
  });

  test(
    'corrupt persisted state self-heals and still returns valid message',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'timerMessageOrder': <String>['bad-template'],
        'timerMessageIndex': 999,
        'timerMessageLastDate': '2026-02-09',
      });

      final repo = TimerMessageRepository();
      final message = await repo.getDailyMessage(
        userName: 'Yash',
        countdownText: '10:00:00',
        now: DateTime(2026, 2, 9),
      );

      expect(message.contains('Yash'), isTrue);
      expect(message.contains('10:00:00'), isTrue);
      expect(
        templateIndex(message, 'Yash', '10:00:00'),
        greaterThanOrEqualTo(0),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('timerMessageOrder')?.length,
        templates.length,
      );
      final index = prefs.getInt('timerMessageIndex');
      expect(index, isNotNull);
      expect(index, inInclusiveRange(0, templates.length - 1));
    },
  );
}
