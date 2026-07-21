import 'package:flutter_test/flutter_test.dart';

import 'package:are_you_alive_flutter/models/emergency_contact_models.dart';
import 'package:are_you_alive_flutter/services/emergency_contact_service.dart';

class InMemoryKV implements SecureKV {
  final Map<String, String> store = <String, String>{};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async => store[key] = value;

  @override
  Future<void> delete(String key) async => store.remove(key);
}

EmergencyContactService _service({String? region = 'IN'}) =>
    EmergencyContactService(storage: InMemoryKV(), regionCode: () => region);

void main() {
  group('pairing code', () {
    test('has AYA- prefix, 6 Crockford chars, no ambiguous letters', () {
      final service = _service();
      for (var i = 0; i < 200; i++) {
        final code = service.generatePairingCode();
        expect(code, matches(RegExp(r'^AYA-[0-9A-HJKMNP-TV-Z]{6}$')));
        expect(code, isNot(matches(RegExp(r'[ILOU]'))));
      }
    });

    test('codes are not repeated in a small sample', () {
      final service = _service();
      final codes = {for (var i = 0; i < 100; i++) service.generatePairingCode()};
      expect(codes.length, 100);
    });
  });

  group('invite message', () {
    test('contains name, code, and referrer link', () {
      final message = _service().buildInviteMessage(
        userName: 'Yash',
        code: 'AYA-7F3K2M',
      );
      expect(message, contains('Yash picked you'));
      expect(message, contains('code AYA-7F3K2M'));
      expect(message, contains('&referrer=AYA-7F3K2M'));
      expect(
        message,
        contains('play.google.com/store/apps/details'
            '?id=com.areyoualive.are_you_alive_flutter'),
      );
    });

    test('falls back to "Someone" for a blank user name', () {
      final message = _service().buildInviteMessage(
        userName: '   ',
        code: 'AYA-ABC123',
      );
      expect(message, startsWith('Someone picked you'));
    });
  });

  group('phone normalization (region IN)', () {
    test('local Indian formats resolve to 91 digits', () {
      final service = _service();
      expect(service.normalizeToWhatsAppDigits('98765 43210'), '919876543210');
      expect(
        service.normalizeToWhatsAppDigits('+91 98765-43210'),
        '919876543210',
      );
      expect(service.normalizeToWhatsAppDigits('09876543210'), '919876543210');
    });

    test('already-international number keeps its own country', () {
      final service = _service();
      expect(service.normalizeToWhatsAppDigits('+1 415 555 2671'), '14155552671');
    });

    test('garbage and empty input return null, never throw', () {
      final service = _service();
      expect(service.normalizeToWhatsAppDigits(''), isNull);
      expect(service.normalizeToWhatsAppDigits('not a number'), isNull);
      expect(service.normalizeToWhatsAppDigits('12'), isNull);
    });

    test('unknown region still parses fully international input', () {
      final service = _service(region: null);
      expect(
        service.normalizeToWhatsAppDigits('+91 98765 43210'),
        '919876543210',
      );
    });
  });

  test('wa.me URI carries digits in path and text as query', () {
    final uri = _service().buildWhatsAppUri(
      digits: '919876543210',
      message: 'hello there & welcome',
    );
    expect(uri.host, 'wa.me');
    expect(uri.path, '/919876543210');
    expect(uri.queryParameters['text'], 'hello there & welcome');
  });

  group('state persistence', () {
    test('save/load round-trips and clear removes', () async {
      final kv = InMemoryKV();
      final service = EmergencyContactService(
        storage: kv,
        regionCode: () => 'IN',
      );
      const state = EmergencyContactState(
        name: 'Ravi',
        phone: '98765 43210',
        pairingCode: 'AYA-7F3K2M',
        status: PairingStatus.pending,
      );

      await service.save(state);
      final loaded = await service.load();
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Ravi');
      expect(loaded.pairingCode, 'AYA-7F3K2M');
      expect(loaded.status, PairingStatus.pending);
      expect(loaded.manuallyConfirmed, isFalse);

      await service.clear();
      expect(await service.load(), isNull);
    });

    test('corrupt stored JSON loads as null instead of throwing', () async {
      final kv = InMemoryKV();
      kv.store['emergency.contact.stateJson'] = '{not json';
      final service = EmergencyContactService(
        storage: kv,
        regionCode: () => 'IN',
      );
      expect(await service.load(), isNull);
    });

    test('device id is generated once and reused', () async {
      final kv = InMemoryKV();
      final service = EmergencyContactService(
        storage: kv,
        regionCode: () => 'IN',
      );
      final first = await service.getOrCreateDeviceId();
      final second = await service.getOrCreateDeviceId();
      expect(first, hasLength(32));
      expect(second, first);
    });
  });
}
