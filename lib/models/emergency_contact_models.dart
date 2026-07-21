import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Pairing lifecycle for the emergency contact.
///
/// The "no contact chosen yet" state is represented by an absent
/// [EmergencyContactState], not an enum value.
enum PairingStatus { pending, confirmed }

@immutable
class EmergencyContactState {
  const EmergencyContactState({
    required this.name,
    required this.phone,
    required this.pairingCode,
    required this.status,
    this.manuallyConfirmed = false,
  });

  /// Display name as picked from the OS contact picker.
  final String name;

  /// Raw phone number exactly as the contact picker returned it. Only
  /// normalized at nudge time, never at rest.
  final String phone;

  /// Locally generated invite code, e.g. 'AYA-7F3K2M'.
  final String pairingCode;

  final PairingStatus status;

  /// True when the user tapped "they installed it" instead of the pairing
  /// being verified by the backend (Phase B). Kept so Phase D can tell a
  /// trusted claim from a verified one.
  final bool manuallyConfirmed;

  EmergencyContactState copyWith({
    PairingStatus? status,
    bool? manuallyConfirmed,
  }) {
    return EmergencyContactState(
      name: name,
      phone: phone,
      pairingCode: pairingCode,
      status: status ?? this.status,
      manuallyConfirmed: manuallyConfirmed ?? this.manuallyConfirmed,
    );
  }

  String toJson() => jsonEncode(<String, Object>{
    'name': name,
    'phone': phone,
    'pairingCode': pairingCode,
    'status': status.name,
    'manuallyConfirmed': manuallyConfirmed,
  });

  static EmergencyContactState? fromJson(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      final name = decoded['name'];
      final phone = decoded['phone'];
      final pairingCode = decoded['pairingCode'];
      final statusName = decoded['status'];
      if (name is! String || phone is! String || pairingCode is! String) {
        return null;
      }
      final status = PairingStatus.values.asNameMap()[statusName];
      if (status == null) return null;
      return EmergencyContactState(
        name: name,
        phone: phone,
        pairingCode: pairingCode,
        status: status,
        manuallyConfirmed: decoded['manuallyConfirmed'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}
