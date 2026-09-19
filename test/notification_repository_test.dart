import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:are_you_alive_flutter/repositories/notification_repository.dart';

void main() {
  // Mirrors the private message list in NotificationRepository so tests can
  // verify rotation/coverage without reaching into implementation details.
  const messages = <String>[
    'FILING NOTICE / 30 HOURS ELAPSED / confirmation requested.',
    'CONTINUED EXISTENCE REGISTER / no new filing received in 30 hours.',
    'FLD-AYA-01 / filing window remains open / confirmation requested.',
    'BUREAU NOTICE / continued existence requires a current filing.',
    'RECORD STATUS / active, approaching deadline / file when able.',
    'F.C.C.D.B. / 30-hour reminder / no action has been recorded.',
    'EXISTENCE REGISTER / filing outstanding / window closes at 39 hours.',
    'FLD-AYA-01 / subject record awaiting confirmation.',
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('first call initializes a shuffled order and persists index 1', () async {
    final repo = NotificationRepository();
    final message = await repo.nextThirtyHourMessage();

    expect(messages.contains(message), isTrue);

    final prefs = await SharedPreferences.getInstance();
    final order = prefs.getStringList('thirtyHourNotificationOrder');
    expect(order, isNotNull);
    expect(order!.length, messages.length);
    expect(order.toSet(), messages.toSet());
    expect(prefs.getInt('thirtyHourNotificationIndex'), 1);
  });

  test(
    'a full cycle of calls returns every message exactly once (no repeats, no skips)',
    () async {
      final repo = NotificationRepository();
      final seen = <String>[];
      for (var i = 0; i < messages.length; i++) {
        seen.add(await repo.nextThirtyHourMessage());
      }

      expect(seen.length, messages.length);
      expect(seen.toSet(), messages.toSet()); // every message appears
      expect(seen.toSet().length, messages.length); // none repeated
    },
  );

  test(
    'wraparound after exhausting the order reshuffles and resets index to 0',
    () async {
      final repo = NotificationRepository();
      for (var i = 0; i < messages.length; i++) {
        await repo.nextThirtyHourMessage();
      }

      final prefs = await SharedPreferences.getInstance();
      // The (messages.length)-th call should have already reshuffled and
      // reset the index for the *next* call, even though it returned the
      // final message from the exhausted order.
      expect(prefs.getInt('thirtyHourNotificationIndex'), 0);
      final freshOrder = prefs.getStringList('thirtyHourNotificationOrder');
      expect(freshOrder!.length, messages.length);
      expect(freshOrder.toSet(), messages.toSet());

      // The next call continues seamlessly from the fresh order.
      final next = await repo.nextThirtyHourMessage();
      expect(messages.contains(next), isTrue);
      expect(prefs.getInt('thirtyHourNotificationIndex'), 1);
    },
  );

  test(
    'stale order length (e.g. after a code change to the message list) triggers a fresh shuffle',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'thirtyHourNotificationOrder': <String>['stale-message-1', 'stale-message-2'],
        'thirtyHourNotificationIndex': 1,
      });

      final repo = NotificationRepository();
      final message = await repo.nextThirtyHourMessage();

      expect(messages.contains(message), isTrue);
      final prefs = await SharedPreferences.getInstance();
      final order = prefs.getStringList('thirtyHourNotificationOrder');
      expect(order!.length, messages.length);
    },
  );

  test(
    'an out-of-range persisted index self-heals instead of throwing a RangeError',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'thirtyHourNotificationOrder': messages,
        'thirtyHourNotificationIndex': messages.length + 5,
      });

      final repo = NotificationRepository();
      final message = await repo.nextThirtyHourMessage();

      expect(messages.contains(message), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('thirtyHourNotificationIndex'), 1);
    },
  );

  test(
    'a negative persisted index self-heals with a fresh shuffle '
    '(matches TimerMessageRepository\'s `index < 0` guard)',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'thirtyHourNotificationOrder': messages,
        'thirtyHourNotificationIndex': -1,
      });

      final repo = NotificationRepository();
      final message = await repo.nextThirtyHourMessage();

      expect(messages.contains(message), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('thirtyHourNotificationIndex'), 1);
    },
  );
}
