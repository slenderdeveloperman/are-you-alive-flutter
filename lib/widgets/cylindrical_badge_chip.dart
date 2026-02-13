import 'package:flutter/material.dart';
import '../models/badge_models.dart';
import 'terminal_texture_painter.dart';

class CylindricalBadgeChip extends StatelessWidget {
  const CylindricalBadgeChip({
    super.key,
    required this.badge,
    this.compact = false,
    this.iconOnly = false,
  });

  final BadgeProgress badge;
  final bool compact;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(badge);

    // Icon-only mode: circular badge with just the icon
    if (iconOnly) {
      const size = 56.0;
      final radius = BorderRadius.circular(size / 2);

      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: palette.glow.withValues(alpha: 0.22),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [palette.top, palette.middle, palette.bottom],
              ),
              border: Border.all(color: palette.stroke.withValues(alpha: 0.8)),
              borderRadius: radius,
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: TerminalTexturePainter()),
                  ),
                ),
                Center(
                  child: Icon(
                    _iconForBadge(badge.definition.id),
                    size: 24,
                    color: palette.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Standard chip mode (compact or full)
    final height = compact ? 36.0 : 44.0;
    final radius = BorderRadius.circular(height / 2);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: palette.glow.withValues(alpha: 0.22),
            blurRadius: compact ? 8 : 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          constraints: BoxConstraints(minHeight: height),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [palette.top, palette.middle, palette.bottom],
            ),
            border: Border.all(color: palette.stroke.withValues(alpha: 0.8)),
            borderRadius: radius,
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: TerminalTexturePainter()),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 14,
                  vertical: compact ? 7 : 9,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconForBadge(badge.definition.id),
                      size: compact ? 14 : 16,
                      color: palette.text,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            badge.definition.title.toLowerCase(),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.text,
                              fontSize: compact ? 12 : 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                          if (!compact)
                            Text(
                              badge.earned
                                  ? 'unlocked'
                                  : 'progress ${badge.current}/${badge.target}',
                              style: TextStyle(
                                color: palette.text.withValues(alpha: 0.86),
                                fontSize: 10,
                                letterSpacing: 0.3,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForBadge(BadgeId id) {
    switch (id) {
      case BadgeId.pulseParanoid:
        return Icons.monitor_heart_outlined;
      case BadgeId.hypervigilant:
        return Icons.visibility_outlined;
      case BadgeId.cliffhanger:
        return Icons.terrain_outlined;
      case BadgeId.lastBreath:
        return Icons.air;
      case BadgeId.metronome:
        return Icons.av_timer;
      case BadgeId.safeKeeper:
        return Icons.shield_outlined;
      case BadgeId.ironRoutine:
        return Icons.fitness_center_outlined;
      case BadgeId.phoenix:
        return Icons.local_fire_department_outlined;
    }
  }

  _BadgePalette _palette(BadgeProgress badge) {
    if (badge.earned) {
      return const _BadgePalette(
        top: Color(0xFF24513F),
        middle: Color(0xFF19392D),
        bottom: Color(0xFF132A22),
        stroke: Color(0xFF8FD5B2),
        glow: Color(0xFF3FAE7A),
        text: Color(0xFFE1FFF0),
      );
    }

    if (badge.progress >= 0.7) {
      return const _BadgePalette(
        top: Color(0xFF5A4632),
        middle: Color(0xFF3E3122),
        bottom: Color(0xFF2D2318),
        stroke: Color(0xFFE9BE86),
        glow: Color(0xFFCE8D3F),
        text: Color(0xFFFFE5BF),
      );
    }

    return const _BadgePalette(
      top: Color(0xFF303839),
      middle: Color(0xFF242A2B),
      bottom: Color(0xFF1A1E1F),
      stroke: Color(0xFF98A7A9),
      glow: Color(0xFF5B6E70),
      text: Color(0xFFD8E2E3),
    );
  }
}

class _BadgePalette {
  const _BadgePalette({
    required this.top,
    required this.middle,
    required this.bottom,
    required this.stroke,
    required this.glow,
    required this.text,
  });

  final Color top;
  final Color middle;
  final Color bottom;
  final Color stroke;
  final Color glow;
  final Color text;
}
