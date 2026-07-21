import 'package:flutter/material.dart';

import 'animated_button.dart';

class BottomActionPill extends StatelessWidget {
  const BottomActionPill({
    super.key,
    required this.onShareTap,
    required this.onBadgeTap,
    required this.onBuilderTap,
  });

  final VoidCallback onShareTap;
  final VoidCallback onBadgeTap;
  final VoidCallback onBuilderTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildIcon(
            icon: Icons.share_outlined,
            onTap: onShareTap,
            semanticLabel: 'Share',
          ),
          const SizedBox(width: 32),
          _buildIcon(
            icon: Icons.military_tech,
            onTap: onBadgeTap,
            semanticLabel: 'Badges',
          ),
          const SizedBox(width: 32),
          _buildIcon(
            icon: Icons.build,
            onTap: onBuilderTap,
            semanticLabel: 'Builder',
          ),
        ],
      ),
    );
  }

  Widget _buildIcon({
    required IconData icon,
    required VoidCallback onTap,
    required String semanticLabel,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: AnimatedButton(
        onPressed: onTap,
        enableGlow: false,
        pressedScale: 0.88,
        child: Padding(
          // 24px icon + 10px padding on each side = 44px touch target.
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
