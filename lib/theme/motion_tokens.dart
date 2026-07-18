import 'package:flutter/widgets.dart';

/// Shared motion constants. Add new tokens here rather than hand-typing
/// durations/curves at call sites — see AUDIT.md category 7 (cohesion).
class MotionTokens {
  const MotionTokens._();

  /// Whether the OS "reduce motion" accessibility setting is enabled.
  /// Check this before playing decorative/positional motion; keep
  /// state-communicating feedback (color, opacity) regardless.
  static bool get reducedMotion => WidgetsBinding
      .instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  /// Small in-place selection feedback (grid card highlight, scale pop).
  static const Duration selectionDuration = Duration(milliseconds: 200);

  /// Entrance/exit of a swapped subtree (AnimatedSwitcher transitions).
  static const Duration entranceDuration = Duration(milliseconds: 300);

  /// Larger celebratory value transitions (streak count-up).
  static const Duration celebrationDuration = Duration(milliseconds: 600);

  /// Standard ease-out for UI entering/responding. Use for anything
  /// spatially moving into place or reacting to input.
  static const Curve easeOut = Curves.easeOut;

  /// Slightly stronger ease-out for larger/celebratory movement (matches
  /// the existing `Curves.easeOutCubic` convention in this codebase).
  static const Curve easeOutStrong = Curves.easeOutCubic;
}
