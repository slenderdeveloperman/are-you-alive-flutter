import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:are_you_alive_flutter/models/emergency_contact_models.dart';
import 'package:are_you_alive_flutter/screens/emergency_contact_screen.dart';
import 'package:are_you_alive_flutter/services/emergency_contact_service.dart';

import 'emergency_contact_service_test.dart' show InMemoryKV;

Widget _screen({
  required EmergencyContactService service,
  Future<Contact?> Function()? picker,
}) {
  return MaterialApp(
    home: EmergencyContactScreen(
      userName: 'Yash',
      service: service,
      contactPicker: picker ?? () async => null,
    ),
  );
}

EmergencyContactService _serviceWith(InMemoryKV kv) =>
    EmergencyContactService(storage: kv, regionCode: () => 'IN');

void main() {
  testWidgets('empty state shows chooser CTA', (tester) async {
    final service = _serviceWith(InMemoryKV());
    await tester.pumpWidget(_screen(service: service));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('emergency-empty-state')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('emergency-choose-button')),
      findsOneWidget,
    );
  });

  testWidgets('picking a contact moves to pending with a code', (tester) async {
    final service = _serviceWith(InMemoryKV());
    await tester.pumpWidget(
      _screen(
        service: service,
        picker: () async =>
            Contact(fullName: 'Ravi', selectedPhoneNumber: '98765 43210'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('emergency-choose-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('emergency-pending-state')),
      findsOneWidget,
    );
    expect(find.text('Waiting on Ravi'), findsOneWidget);

    final codeText = tester.widget<Text>(
      find.byKey(const ValueKey('emergency-pairing-code')),
    );
    expect(codeText.data, matches(RegExp(r'^AYA-[0-9A-HJKMNP-TV-Z]{6}$')));

    // Persisted, not just in widget state.
    final saved = await service.load();
    expect(saved!.status, PairingStatus.pending);
    expect(saved.phone, '98765 43210');
  });

  testWidgets('cancelling the picker stays on the empty state', (tester) async {
    final service = _serviceWith(InMemoryKV());
    await tester.pumpWidget(
      _screen(service: service, picker: () async => null),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('emergency-choose-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('emergency-empty-state')), findsOneWidget);
    expect(await service.load(), isNull);
  });

  testWidgets('manual confirm flips pending to confirmed with caveat label', (
    tester,
  ) async {
    final kv = InMemoryKV();
    final service = _serviceWith(kv);
    await service.save(
      const EmergencyContactState(
        name: 'Ravi',
        phone: '98765 43210',
        pairingCode: 'AYA-7F3K2M',
        status: PairingStatus.pending,
      ),
    );

    await tester.pumpWidget(_screen(service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('emergency-manual-confirm')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('emergency-confirmed-state')),
      findsOneWidget,
    );
    expect(find.text('Ravi has your back'), findsOneWidget);
    expect(find.text('confirmed by you — not yet verified'), findsOneWidget);

    final saved = await service.load();
    expect(saved!.status, PairingStatus.confirmed);
    expect(saved.manuallyConfirmed, isTrue);
  });

  testWidgets('change contact clears state back to empty', (tester) async {
    final service = _serviceWith(InMemoryKV());
    await service.save(
      const EmergencyContactState(
        name: 'Ravi',
        phone: '98765 43210',
        pairingCode: 'AYA-7F3K2M',
        status: PairingStatus.confirmed,
        manuallyConfirmed: true,
      ),
    );

    await tester.pumpWidget(_screen(service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('emergency-remove-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('emergency-empty-state')), findsOneWidget);
    expect(await service.load(), isNull);
  });
}
