import 'package:flutter_test/flutter_test.dart';

import 'package:are_you_alive_flutter/services/invite_claim_service.dart';

void main() {
  // detectReferrerCode() short-circuits to null on every platform this
  // test suite runs on (the VM test platform reports as none of the
  // Platform.is* checks are Android), so it never touches the plugin's
  // MethodChannel. This exercises exactly the non-Android branch that
  // real iOS installs hit.
  test('returns null off Android without touching the platform channel', () async {
    const service = InviteClaimService();
    expect(await service.detectReferrerCode(), isNull);
  });

  group('extractCode', () {
    test('pulls the code out of a referrer query string', () {
      expect(
        InviteClaimService.extractCode('utm_source=whatsapp&referrer=AYA-7F3K2M'),
        'AYA-7F3K2M',
      );
    });

    test('finds the code with no surrounding params', () {
      expect(InviteClaimService.extractCode('AYA-ABC123'), 'AYA-ABC123');
    });

    test('returns null for a referrer with no code, or null input', () {
      expect(InviteClaimService.extractCode('utm_source=google-play'), isNull);
      expect(InviteClaimService.extractCode(null), isNull);
    });

    test('rejects ambiguous letters (I, L, O, U) as a non-match', () {
      // Crockford base32 excludes I/L/O/U, so a code containing them isn't
      // a valid AYA code even if it happens to be 6 chars after the prefix.
      expect(InviteClaimService.extractCode('AYA-ILOU12'), isNull);
    });
  });
}
