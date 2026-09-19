import 'package:flutter/material.dart';

import '../theme/bureau_tokens.dart';
import 'animated_button.dart';

class BottomActionPill extends StatelessWidget {
  const BottomActionPill({
    super.key,
    required this.onShareTap,
    required this.onBadgeTap,
    required this.onGuardianTap,
    required this.onBuilderTap,
  });

  final VoidCallback onShareTap;
  final VoidCallback onBadgeTap;
  final VoidCallback onGuardianTap;
  final VoidCallback onBuilderTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 390),
      decoration: BoxDecoration(
        color: BureauTokens.ink,
        border: Border.all(color: BureauTokens.ruleOnInk),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAction(icon: Icons.share_outlined, onTap: onShareTap, semanticLabel: 'Register extract', visibleLabel: 'EXTRACT'),
          _rule(),
          _buildAction(icon: Icons.military_tech_outlined, onTap: onBadgeTap, semanticLabel: 'Citations', visibleLabel: 'CITATIONS'),
          _rule(),
          _buildAction(icon: Icons.shield_outlined, onTap: onGuardianTap, semanticLabel: 'Designated witness', visibleLabel: 'WITNESS'),
          _rule(),
          _buildAction(icon: Icons.build_outlined, onTap: onBuilderTap, semanticLabel: 'Builder', visibleLabel: 'BUILD'),
        ],
      ),
    );
  }

  Widget _rule() => Container(width: 1, height: 48, color: BureauTokens.ruleOnInk);

  Widget _buildAction({
    required IconData icon,
    required VoidCallback onTap,
    required String semanticLabel,
    required String visibleLabel,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: AnimatedButton(
        onPressed: onTap,
        enableGlow: false,
        pressedScale: 0.97,
        child: SizedBox(
          width: 78,
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: BureauTokens.paper, size: 17),
              const SizedBox(height: 4),
              Text(
                visibleLabel,
                maxLines: 1,
                style: BureauTokens.filingLabel.copyWith(
                  color: BureauTokens.mutedOnInk,
                  fontSize: 8,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
