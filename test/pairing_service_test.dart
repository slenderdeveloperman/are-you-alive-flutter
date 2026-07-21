import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:are_you_alive_flutter/services/pairing_service.dart';

/// Builds a MockClient that mints tokens and answers RPCs from [rpcResults]
/// (function name → JSON-encodable result). Tracks call counts.
class _Backend {
  _Backend({this.tokenStatus = 200});

  final int tokenStatus;
  final Map<String, Object?> rpcResults = <String, Object?>{};
  int tokenFetches = 0;
  int rpcCalls = 0;
  final List<Map<String, dynamic>> capturedBodies = <Map<String, dynamic>>[];

  late final MockClient client = MockClient((request) async {
    if (request.url.path.endsWith('/token/anonymous')) {
      tokenFetches += 1;
      if (tokenStatus != 200) return http.Response('', tokenStatus);
      return http.Response(
        jsonEncode(<String, Object>{
          'token': 'jwt-$tokenFetches',
          'expires_at':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
        }),
        200,
      );
    }

    final function = request.url.pathSegments.last;
    rpcCalls += 1;
    capturedBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
    return http.Response(jsonEncode(rpcResults[function]), 200);
  });
}

void main() {
  test('createInvite returns true and sends code + inviter id', () async {
    final backend = _Backend()..rpcResults['create_invite'] = true;
    final service = PairingService(client: backend.client);

    final result = await service.createInvite(
      code: 'AYA-7F3K2M',
      inviterId: 'a' * 32,
    );

    expect(result, isTrue);
    expect(backend.capturedBodies.single['p_code'], 'AYA-7F3K2M');
    expect(backend.capturedBodies.single['p_inviter_id'], 'a' * 32);
  });

  test('createInvite returns false on backend rejection', () async {
    final backend = _Backend()..rpcResults['create_invite'] = false;
    final service = PairingService(client: backend.client);
    expect(
      await service.createInvite(code: 'AYA-XXXXXX', inviterId: 'a' * 32),
      isFalse,
    );
  });

  test('status strings map to enum values', () async {
    final backend = _Backend();
    final service = PairingService(client: backend.client);

    backend.rpcResults['get_invite_status'] = 'pending';
    expect(await service.getInviteStatus('AYA-000000'), InviteStatus.pending);
    backend.rpcResults['get_invite_status'] = 'claimed';
    expect(await service.getInviteStatus('AYA-000000'), InviteStatus.claimed);
    backend.rpcResults['get_invite_status'] = 'not_found';
    expect(await service.getInviteStatus('AYA-000000'), InviteStatus.notFound);
  });

  test('claim results map to enum values', () async {
    final backend = _Backend();
    final service = PairingService(client: backend.client);

    backend.rpcResults['claim_invite'] = 'claimed';
    expect(
      await service.claimInvite(code: 'AYA-000000', claimerId: 'b' * 32),
      ClaimResult.claimed,
    );
    backend.rpcResults['claim_invite'] = 'already_claimed';
    expect(
      await service.claimInvite(code: 'AYA-000000', claimerId: 'b' * 32),
      ClaimResult.alreadyClaimed,
    );
    backend.rpcResults['claim_invite'] = 'not_found';
    expect(
      await service.claimInvite(code: 'AYA-000000', claimerId: 'b' * 32),
      ClaimResult.notFound,
    );
  });

  test('token is fetched once and cached across calls', () async {
    final backend = _Backend()..rpcResults['get_invite_status'] = 'pending';
    final service = PairingService(client: backend.client);

    await service.getInviteStatus('AYA-000000');
    await service.getInviteStatus('AYA-000000');
    await service.getInviteStatus('AYA-000000');

    expect(backend.tokenFetches, 1);
    expect(backend.rpcCalls, 3);
  });

  test('a 401 triggers one token refresh and a retry', () async {
    var first = true;
    late PairingService service;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/token/anonymous')) {
        return http.Response(
          jsonEncode(<String, Object>{
            'token': 'fresh',
            'expires_at':
                DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
          }),
          200,
        );
      }
      if (first) {
        first = false;
        return http.Response('', 401);
      }
      return http.Response(jsonEncode('pending'), 200);
    });
    service = PairingService(client: client);

    expect(await service.getInviteStatus('AYA-000000'), InviteStatus.pending);
  });

  test('network failures surface as null, never throw', () async {
    final throwing = MockClient((_) async => throw Exception('offline'));
    final service = PairingService(client: throwing);

    expect(
      await service.createInvite(code: 'AYA-000000', inviterId: 'a' * 32),
      isNull,
    );
    expect(await service.getInviteStatus('AYA-000000'), isNull);
    expect(
      await service.claimInvite(code: 'AYA-000000', claimerId: 'b' * 32),
      isNull,
    );
  });

  test('token endpoint failure surfaces as null', () async {
    final backend = _Backend(tokenStatus: 500);
    final service = PairingService(client: backend.client);
    expect(await service.getInviteStatus('AYA-000000'), isNull);
    expect(backend.rpcCalls, 0);
  });
}
