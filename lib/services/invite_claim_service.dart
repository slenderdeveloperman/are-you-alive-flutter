import 'dart:io';

import 'package:play_install_referrer/play_install_referrer.dart';

/// Claimer-side half of plan 009 Phase C: detect an invite code from the
/// Play install referrer (Android only), or accept one typed by hand.
///
/// Referrer detection is a convenience, never a requirement — it's lost
/// whenever the contact installs by searching the store instead of tapping
/// the invite link, so manual code entry stays the universal path (see
/// plan 009 risk 3).
class InviteClaimService {
  const InviteClaimService();

  static final RegExp _codePattern = RegExp(r'AYA-[0-9A-HJKMNP-TV-Z]{6}');

  /// Reads the Play Install Referrer and extracts an `AYA-XXXXXX` code, or
  /// null on iOS, on any platform/plugin failure, or if no code is present.
  Future<String?> detectReferrerCode() async {
    if (!Platform.isAndroid) return null;

    try {
      final details = await PlayInstallReferrer.installReferrer;
      return extractCode(details.installReferrer);
    } catch (_) {
      return null;
    }
  }

  /// Pulls the `AYA-XXXXXX` code out of a raw referrer string, e.g.
  /// `'utm_source=whatsapp&referrer=AYA-7F3K2M'`. Exposed separately so the
  /// extraction logic is testable without a real Play install.
  static String? extractCode(String? referrer) {
    if (referrer == null) return null;
    return _codePattern.firstMatch(referrer)?.group(0);
  }
}
