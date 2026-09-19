import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:are_you_alive_flutter/services/watchdog_service.dart';

void main() {
  test('syncCheckIn sends canonical watchdog timestamps and reports synced', () async {
    late http.Request rpcRequest;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/token/anonymous')) {
        return http.Response(
          jsonEncode(<String, Object>{
            'token': 'test-token',
            'expires_at': 4102444800,
          }),
          200,
        );
      }

      rpcRequest = request;
      return http.Response('true', 200);
    });

    final service = WatchdogService(client: client);
    final checkedInAt = DateTime.utc(2026, 9, 19, 12);

    final result = await service.syncCheckIn(
      subjectId: '0123456789abcdef0123456789abcdef',
      checkedInAt: checkedInAt,
    );

    expect(result, WatchdogSyncResult.synced);
    expect(rpcRequest.url.path, endsWith('/rpc/refresh_watchdog'));
    expect(rpcRequest.headers['authorization'], 'Bearer test-token');

    final body = jsonDecode(rpcRequest.body) as Map<String, dynamic>;
    expect(body['p_subject_id'], '0123456789abcdef0123456789abcdef');
    expect(body['p_checked_in_at'], checkedInAt.toIso8601String());
    expect(
      body['p_deadline_at'],
      checkedInAt.add(const Duration(hours: 39)).toIso8601String(),
    );
  });

  test('false RPC result means the record has no confirmed witness', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/token/anonymous')) {
        return http.Response(
          jsonEncode(<String, Object>{
            'token': 'test-token',
            'expires_at': 4102444800,
          }),
          200,
        );
      }
      return http.Response('false', 200);
    });

    final result = await WatchdogService(client: client).syncCheckIn(
      subjectId: '0123456789abcdef0123456789abcdef',
      checkedInAt: DateTime.utc(2026, 9, 19),
    );

    expect(result, WatchdogSyncResult.notPaired);
  });

  test('transport/backend failure degrades without breaking a filing', () async {
    final client = MockClient((request) async => http.Response('unavailable', 503));

    final result = await WatchdogService(client: client).syncCheckIn(
      subjectId: '0123456789abcdef0123456789abcdef',
      checkedInAt: DateTime.utc(2026, 9, 19),
    );

    expect(result, WatchdogSyncResult.unavailable);
  });
}
