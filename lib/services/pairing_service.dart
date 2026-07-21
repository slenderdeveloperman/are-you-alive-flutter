import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';

/// Invite state as reported by the backend. `notFound` is authoritative
/// (the code does not exist) and distinct from a network failure, which
/// every method reports as `null` — callers must keep local state on null
/// and only reset on notFound (plan 009 Phase D).
enum InviteStatus { pending, claimed, notFound }

enum ClaimResult { claimed, alreadyClaimed, notFound }

class PairingService {
  PairingService({http.Client? client, DateTime Function()? now})
    : _client = client ?? http.Client(),
      _now = now ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _now;

  static const Duration _timeout = Duration(seconds: 8);

  String? _token;
  DateTime? _tokenExpiry;

  /// Registers (or re-registers) the caller's invite. Returns true on
  /// success, false when the backend rejected it (bad format or code
  /// collision — regenerate and retry), null when unreachable.
  Future<bool?> createInvite({
    required String code,
    required String inviterId,
  }) async {
    final result = await _rpc('create_invite', <String, String>{
      'p_code': code,
      'p_inviter_id': inviterId,
    });
    if (result == null) return null;
    return result == true;
  }

  /// Claims an invite on the contact's device (plan 009 Phase C).
  Future<ClaimResult?> claimInvite({
    required String code,
    required String claimerId,
    String? claimerName,
  }) async {
    final result = await _rpc('claim_invite', <String, String?>{
      'p_code': code,
      'p_claimer_id': claimerId,
      'p_claimer_name': claimerName,
    });
    switch (result) {
      case 'claimed':
        return ClaimResult.claimed;
      case 'already_claimed':
        return ClaimResult.alreadyClaimed;
      case 'not_found':
        return ClaimResult.notFound;
      default:
        return null;
    }
  }

  Future<InviteStatus?> getInviteStatus(String code) async {
    final result = await _rpc('get_invite_status', <String, String>{
      'p_code': code,
    });
    switch (result) {
      case 'pending':
        return InviteStatus.pending;
      case 'claimed':
        return InviteStatus.claimed;
      case 'not_found':
        return InviteStatus.notFound;
      default:
        return null;
    }
  }

  /// Calls a Data API RPC as the anonymous role. Returns the decoded JSON
  /// result, or null on any transport-level failure.
  Future<Object?> _rpc(String function, Map<String, Object?> args) async {
    try {
      var token = await _anonymousToken();
      if (token == null) return null;

      var response = await _post(function, args, token);

      // A 401 means the cached token aged out server-side — refresh once.
      if (response.statusCode == 401) {
        _token = null;
        token = await _anonymousToken();
        if (token == null) return null;
        response = await _post(function, args, token);
      }

      if (response.statusCode != 200) return null;
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  Future<http.Response> _post(
    String function,
    Map<String, Object?> args,
    String token,
  ) {
    return _client
        .post(
          Uri.parse('${BackendConfig.dataApiUrl}/rpc/$function'),
          headers: <String, String>{
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(args),
        )
        .timeout(_timeout);
  }

  /// Anonymous JWTs live ~1 hour; cache until shortly before expiry.
  Future<String?> _anonymousToken() async {
    final cached = _token;
    final expiry = _tokenExpiry;
    if (cached != null &&
        expiry != null &&
        _now().isBefore(expiry.subtract(const Duration(seconds: 60)))) {
      return cached;
    }

    try {
      final response = await _client
          .get(Uri.parse(BackendConfig.authTokenUrl))
          .timeout(_timeout);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final token = decoded['token'];
      final expiresAt = decoded['expires_at'];
      if (token is! String || expiresAt is! num) return null;

      _token = token;
      _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(
        expiresAt.toInt() * 1000,
      );
      return token;
    } catch (_) {
      return null;
    }
  }
}
