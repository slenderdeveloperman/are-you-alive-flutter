import 'package:flutter/material.dart';

/// Visual primitives for AYA 0.3's F.C.C.D.B. filing-instrument language.
///
/// Keep this deliberately small. Screens should consume semantic roles from here
/// instead of introducing local brand colors. Typography remains on system generic
/// families until the 0.3 font assets are bundled.
class BureauTokens {
  const BureauTokens._();

  // Core surfaces — aligned with the existing FLD-AYA-01 share-card treatment.
  static const Color ink = Color(0xFF1A1A1A);
  static const Color paper = Color(0xFFECE4D4);
  static const Color paperBright = Color(0xFFF5F0E7);

  // Existing ESTD. INDICA lore-line accent. Use sparingly: stamps, period marks,
  // urgent filing state. It is not a default CTA fill.
  static const Color accent = Color(0xFFB84A2E);

  // Semantic rules derived from the ink/paper system.
  static const Color ruleOnPaper = Color(0x4D1A1A1A);
  static const Color ruleOnInk = Color(0x52FFFFFF);
  static const Color mutedOnPaper = Color(0xA61A1A1A);
  static const Color mutedOnInk = Color(0xB8FFFFFF);

  // State colors are intentionally restrained. Urgent/lapsed relies primarily on
  // inversion + labels; color remains supplemental.
  static const Color active = Color(0xFF4F6B52);
  static const Color warning = Color(0xFF8A642D);
  static const Color lapsed = accent;

  static const String monoFamily = 'monospace';
  static const String displayFamily = 'serif';

  static const TextStyle filingLabel = TextStyle(
    fontFamily: monoFamily,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.8,
    height: 1.2,
  );

  static const TextStyle filingValue = TextStyle(
    fontFamily: monoFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.35,
  );

  static const TextStyle displayTitle = TextStyle(
    fontFamily: displayFamily,
    fontSize: 28,
    fontWeight: FontWeight.w400,
    height: 1.05,
  );

  static const TextStyle countdown = TextStyle(
    fontFamily: monoFamily,
    fontSize: 44,
    fontWeight: FontWeight.w300,
    letterSpacing: -1.2,
    height: 1.0,
  );
}
