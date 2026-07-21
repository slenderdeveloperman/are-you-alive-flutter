import 'dart:math';
import 'dart:ui';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../models/emergency_contact_models.dart';

/// Minimal key-value contract so tests can swap in an in-memory fake and
/// the service never depends on the plugin directly.
abstract class SecureKV {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Production storage. iOS Keychain entries survive uninstall/reinstall,
/// which is the cheap half of the reinstall-orphaning mitigation (plan 009,
/// Phase A item 6). Android relies on best-effort Auto Backup instead.
class SecureStorageKV implements SecureKV {
  const SecureStorageKV();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class EmergencyContactService {
  EmergencyContactService({SecureKV? storage, String? Function()? regionCode})
    : _storage = storage ?? const SecureStorageKV(),
      _regionCode =
          regionCode ??
          (() => PlatformDispatcher.instance.locale.countryCode);

  final SecureKV _storage;
  final String? Function() _regionCode;

  static const String _stateKey = 'emergency.contact.stateJson';
  static const String _deviceIdKey = 'device.uuid';

  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details'
      '?id=com.areyoualive.are_you_alive_flutter';

  /// Crockford base32: no I, L, O, U — unambiguous when read aloud or
  /// retyped from a WhatsApp message.
  static const String _codeAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const int _codeLength = 6;

  Future<EmergencyContactState?> load() async {
    try {
      return EmergencyContactState.fromJson(await _storage.read(_stateKey));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(EmergencyContactState state) =>
      _storage.write(_stateKey, state.toJson());

  Future<void> clear() => _storage.delete(_stateKey);

  /// Opaque device identity for Phase B pairing rows. Generated once and
  /// kept in secure storage so it survives reinstall where the platform
  /// allows (iOS Keychain).
  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final id = List.generate(
      32,
      (_) => '0123456789abcdef'[random.nextInt(16)],
    ).join();
    await _storage.write(_deviceIdKey, id);
    return id;
  }

  String generatePairingCode() {
    final random = Random.secure();
    final chars = List.generate(
      _codeLength,
      (_) => _codeAlphabet[random.nextInt(_codeAlphabet.length)],
    ).join();
    return 'AYA-$chars';
  }

  String buildInviteMessage({required String userName, required String code}) {
    final safeName = userName.trim().isEmpty ? 'Someone' : userName.trim();
    final link = '$_playStoreUrl&referrer=$code';
    return '$safeName picked you as their emergency contact on '
        'Are You Alive? — if they ever go silent too long, you\'re the one '
        'who gets told.\n\n'
        'Install and enter code $code to accept:\n$link';
  }

  /// Best-effort E.164 digits (no '+') for a wa.me deep link, or null when
  /// the number can't be confidently parsed — callers must treat null as
  /// "use the share sheet", never as an error (plan 009, risk 2).
  String? normalizeToWhatsAppDigits(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // A leading '+' already declares the country — the device-region hint
    // must only apply to local-format numbers, or it would override an
    // explicitly international one.
    IsoCode? region;
    if (!trimmed.startsWith('+')) {
      final regionName = _regionCode()?.toUpperCase();
      if (regionName != null) {
        region = IsoCode.values.asNameMap()[regionName];
      }
    }

    try {
      final parsed = PhoneNumber.parse(trimmed, destinationCountry: region);
      if (!parsed.isValid()) return null;
      return '${parsed.countryCode}${parsed.nsn}';
    } catch (_) {
      return null;
    }
  }

  Uri buildWhatsAppUri({required String digits, required String message}) =>
      Uri.https('wa.me', '/$digits', <String, String>{'text': message});
}
