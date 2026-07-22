import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:are_you_alive_flutter/screens/welcome_screen.dart';
import 'package:are_you_alive_flutter/services/emergency_contact_service.dart';
import 'package:are_you_alive_flutter/services/invite_claim_service.dart';
import 'package:are_you_alive_flutter/services/pairing_service.dart';

import 'emergency_contact_service_test.dart' show InMemoryKV;

class FakeInviteClaimService implements InviteClaimService {
  FakeInviteClaimService(this.code);
  final String? code;

  @override
  Future<String?> detectReferrerCode() async => code;
}

class RecordingClaimPairingService extends PairingService {
  RecordingClaimPairingService(this.result);
  final ClaimResult? result;
  String? capturedCode;
  String? capturedClaimerId;
  String? capturedClaimerName;

  @override
  Future<ClaimResult?> claimInvite({
    required String code,
    required String claimerId,
    String? claimerName,
  }) async {
    capturedCode = code;
    capturedClaimerId = claimerId;
    capturedClaimerName = claimerName;
    return result;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget screen({
    String? detectedCode,
    PairingService? pairingService,
  }) {
    return MaterialApp(
      home: WelcomeScreen(
        onComplete: () {},
        emergencyContactService: EmergencyContactService(
          storage: InMemoryKV(),
          regionCode: () => 'IN',
        ),
        pairingService: pairingService ?? RecordingClaimPairingService(null),
        inviteClaimService: FakeInviteClaimService(detectedCode),
      ),
    );
  }

  testWidgets('code field is empty when no referrer is detected', (
    tester,
  ) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('welcome-invite-code-button')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('welcome-invite-code-field')),
    );
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('a detected referrer code auto-fills the field', (
    tester,
  ) async {
    await tester.pumpWidget(screen(detectedCode: 'AYA-7F3K2M'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('welcome-invite-code-button')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('welcome-invite-code-field')),
    );
    expect(field.controller!.text, 'AYA-7F3K2M');
  });

  testWidgets('accepting sends the typed code, device id, and typed name', (
    tester,
  ) async {
    final pairing = RecordingClaimPairingService(ClaimResult.claimed);
    await tester.pumpWidget(screen(pairingService: pairing));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Ravi');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('welcome-invite-code-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('welcome-invite-code-field')),
      'aya-abc123',
    );
    await tester.tap(find.byKey(const ValueKey('welcome-invite-code-accept')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(pairing.capturedCode, 'AYA-ABC123');
    expect(pairing.capturedClaimerId, hasLength(32));
    expect(pairing.capturedClaimerName, 'Ravi');
  });

  testWidgets('a successful claim shows confirmation and closes the sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen(pairingService: RecordingClaimPairingService(ClaimResult.claimed)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('welcome-invite-code-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('welcome-invite-code-field')),
      'AYA-ABC123',
    );
    await tester.tap(find.byKey(const ValueKey('welcome-invite-code-accept')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('welcome-invite-code-message')),
      findsOneWidget,
    );
    expect(find.textContaining('Accepted'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('welcome-invite-code-field')), findsNothing);
  });

  testWidgets('an already-claimed or not-found result stays on the sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen(
        pairingService: RecordingClaimPairingService(ClaimResult.notFound),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('welcome-invite-code-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('welcome-invite-code-field')),
      'AYA-ZZZZZZ',
    );
    await tester.tap(find.byKey(const ValueKey('welcome-invite-code-accept')));
    await tester.pump();

    expect(find.textContaining('doesn\'t match'), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-invite-code-field')), findsOneWidget);
  });

  testWidgets('a network failure (null) shows a connection message', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen(pairingService: RecordingClaimPairingService(null)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('welcome-invite-code-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('welcome-invite-code-field')),
      'AYA-ABC123',
    );
    await tester.tap(find.byKey(const ValueKey('welcome-invite-code-accept')));
    await tester.pump();

    expect(find.textContaining('Couldn\'t reach'), findsOneWidget);
  });
}
