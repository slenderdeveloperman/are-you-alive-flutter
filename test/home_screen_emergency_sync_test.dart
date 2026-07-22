import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:are_you_alive_flutter/models/emergency_contact_models.dart';
import 'package:are_you_alive_flutter/screens/home_screen.dart';
import 'package:are_you_alive_flutter/services/emergency_contact_service.dart';
import 'package:are_you_alive_flutter/services/pairing_service.dart';

import 'emergency_contact_service_test.dart' show FakePairingService, InMemoryKV;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('a claimed pending invite shows a confirmation snackbar on open', (
    tester,
  ) async {
    final service = EmergencyContactService(
      storage: InMemoryKV(),
      regionCode: () => 'IN',
    );
    await service.save(
      const EmergencyContactState(
        name: 'Ravi',
        phone: '98765 43210',
        pairingCode: 'AYA-7F3K2M',
        status: PairingStatus.pending,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          emergencyContactService: service,
          pairingService: FakePairingService(InviteStatus.claimed),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Ravi has your back now.'), findsOneWidget);
  });

  testWidgets('an expired invite shows the re-invite prompt', (tester) async {
    final service = EmergencyContactService(
      storage: InMemoryKV(),
      regionCode: () => 'IN',
    );
    await service.save(
      const EmergencyContactState(
        name: 'Ravi',
        phone: '98765 43210',
        pairingCode: 'AYA-7F3K2M',
        status: PairingStatus.pending,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          emergencyContactService: service,
          pairingService: FakePairingService(InviteStatus.notFound),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('Emergency contact invite expired — choose again.'),
      findsOneWidget,
    );
  });

  testWidgets('no emergency contact state produces no snackbar', (
    tester,
  ) async {
    final service = EmergencyContactService(
      storage: InMemoryKV(),
      regionCode: () => 'IN',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          emergencyContactService: service,
          pairingService: FakePairingService(InviteStatus.claimed),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SnackBar), findsNothing);
  });
}
